defmodule ICalendar.Decoder do
  alias ICalendar.RFC6868
  import ICalendar, only: [__props__: 1]

  def decode(string) do
    val =
      string
      # unfold
      |> String.replace(~r/\r?\n[ \t]/, "")
      # split on newline or CRLF
      |> String.split(~r/\r?\n/)
      |> Enum.reduce([], &parse/2)

    {:ok, val}
  end

  @types %{
    "VEVENT" => :event,
    "VALARM" => :alarm,
    "VCALENDAR" => :calendar,
    "VTODO" => :todo,
    "VJOURNAL" => :journal,
    "VFREEBUSY" => :freebusy,
    "VTIMEZONE" => :timezone,
    "STANDARD" => :standard,
    "DAYLIGHT" => :daylight
  }

  defp to_key(string) when is_atom(string), do: string
  defp to_key(string) do
    string
    |> String.replace("-", "_")
    |> String.downcase
    |> String.to_atom
    # TODO limit to_atom to @properties + @parameters
  end

  # tokenize data into a syntax tree
  defp parse("", stack), do: stack

  # pop a new component onto the stack
  defp parse("BEGIN:" <> type, stack) do
    [%{__type__: @types[type]} | stack]
  end

  # TODO: make sure end matches begin type
  defp parse("END:" <> type, [obj, acc | stack]) do
    acc = list_put(acc, @types[type], obj)
    [acc | stack]
  end
  # outermost component
  defp parse("END:" <> type, [obj]), do: obj

  defp parse(line, [obj | stack]) do
    {key, prop} = parse_line(line)

    obj = list_put(obj, key, prop)
    [obj | stack]
  end

  defp list_put(map, key, item) do
    list = Map.get(map, key)
    # if the key exists, make it an array
    item = (if list, do: [item | List.wrap(list)], else: item)
    Map.put(map, key, item)
  end

  def parse_line(line) do
    {:ok, pos} = find_valpos(line)
    val = binary_part(line, pos + 1, byte_size(line) - (pos + 1))
    key = binary_part(line, 0, pos)

    [key, params] = retrieve_params(key)
    key = to_key(key)
    # parse the value, potentially using VALUE or any other param in the process
    spec = __props__(key)
    val = parse_val(val, spec, params)
    # HAXX: I wish we could skip this
    type = to_key(params[:value] || spec[:default])

    # drop value, we already used it while parsing
    {key, {val, Map.drop(params, [:value]), type}}
  end

  # because of how params work, the value delimiter ":" could be included inside
  # a double quoted parameter.
  defp find_valpos(line), do: find_valpos(line, %{pos: 0, inside_quote: false})

  # start of a quote
  defp find_valpos(<<?", rest::binary>>, %{inside_quote: false} = state) do
    find_valpos(rest, %{state | pos: state.pos + 1, inside_quote: true})
  end
  # end of a quote
  defp find_valpos(<<?", rest::binary>>, %{inside_quote: true} = state) do
    find_valpos(rest, %{state | pos: state.pos + 1, inside_quote: false})
  end
  # if we find the separator, and not inside quotes, take it
  defp find_valpos(<<?:, _rest::binary>>, %{inside_quote: inside} = state) when inside == false do
    {:ok, state.pos}
  end
  defp find_valpos(<<_::1-bytes, rest::binary>>, state) do
    find_valpos(rest, %{state | pos: state.pos + 1})
  end
  # error, didn't find separator
  defp find_valpos(<<>>, _state), do: {:error, :invalid_prop}

  # -------------------------

  # Use the typing data to parse a value
  def parse_val(val, %{multi: delim} = spec, params) do
    val
    |> String.split(delim)
    |> Enum.map(fn val -> parse_val(val, Map.drop(spec, [:multi]), params) end)
  end

  def parse_val(val, %{structured: delim} = spec, params) do
    val
    |> String.split(delim)
    |> Enum.map(fn val -> parse_val(val, Map.drop(spec, [:structured]), params) end)
    |> List.to_tuple()
  end

  def parse_val(val, spec, params) do
    type = to_key(params[:value]) || spec[:default]
    {:ok, val} = parse_type(val, type, params)
    val
  end

  # Per type parsing procedures

  def parse_type(val, :binary, %{encoding: "BASE64"}) do
    Base.decode64(val)
  end

  def parse_type("TRUE", :boolean, _params), do: {:ok, true}
  def parse_type("FALSE", :boolean, _params), do: {:ok, false}
  def parse_type(_, :boolean, _params), do: {:error, :invalid_boolean}

  # TODO
  def parse_type(val, :cal_address, _params), do: {:ok, val}

  def parse_type(val, :date, _params), do: to_date(val)

  def parse_type(val, :date_time, params), do: to_datetime(val, params)

  # negative duration
  def parse_type("-" <> val, :duration, params) do
    {:ok, val} = parse_type(val, :duration, params)
    {:ok, Timex.Duration.invert(val)}
  end

  # strip plus
  def parse_type("+" <> val, :duration, params) do
    parse_type(val, :duration, params)
  end

  def parse_type(val, :duration, _params) do
    val
    |> String.trim_trailing("T") # for some reason 1PDT is valid
    |> Timex.Parse.Duration.Parsers.ISO8601Parser.parse
  end

  def parse_type(val, :float, _params) do
    {f, ""} = Float.parse(val)
    {:ok, f}
  end

  def parse_type(val, :integer, _params) do
    {f, ""} = Integer.parse(val)
    {:ok, f}
  end

  def parse_type(val, :period, _params) do
    [from, to] = String.split(val, "/", parts: 2, trim: true)

    {:ok, from} = parse_type(from, :date_time, %{})
    # to can either be a duration or a date_time
    {:ok, to} = if String.starts_with?(to, "P") do
      parse_type(to, :duration, %{})
    else
      parse_type(to, :date_time, %{})
    end

    {:ok, %ICalendar.Period{from: from, until: to}}
  end

  def parse_type(val, :recur, _params) do
    ICalendar.RRULE.deserialize(val)
  end

  def parse_type(val, :text, _params), do: {:ok, unescape(val)}

  def parse_type(val, :time, params), do: to_time(val, params)

  def parse_type(val, :uri, _params), do: {:ok, val}

  # TODO (not sure what the best way to store this is)
  def parse_type(val, :utc_offset, _params), do: {:ok, val}

  # this could be x-vals
  def parse_type(val, :unknown, _), do: {:ok, val}

  @doc ~S"""
  This function extracts parameter data from a key in an iCalendar string.

      iex> ICalendar.Decoder.retrieve_params(
      ...>   "DTSTART;TZID=America/Chicago")
      ["DTSTART", %{tzid: "America/Chicago"}]

  It should be able to handle multiple parameters per key:

      iex> ICalendar.Decoder.retrieve_params(
      ...>   "KEY;LOREM=ipsum;DOLOR=sit")
      ["KEY", %{lorem: "ipsum", dolor: "sit"}]

  """
  def retrieve_params(key) do
    [key | params] = String.split(key, ";", trim: true)

    params =
      params
      |> Enum.reduce(%{}, fn(param, acc) ->
        [key, val] = String.split(param, "=", parts: 2)
        # trim only leading and trailing double quote
        Map.merge(acc, %{to_key(key) =>
          val
          |> String.trim(~s("))
          |> RFC6868.unescape()
        })
      end)

      [key, params]
  end

  @doc ~S"""
  This function is designed to parse iCal datetime strings into erlang dates.

  It should be able to handle dates from the past:

      iex> {:ok, date} = ICalendar.Decoder.to_datetime("19930407T153022Z")
      ...> Timex.to_erl(date)
      {{1993, 4, 7}, {15, 30, 22}}

  As well as the future:

      iex> {:ok, date} = ICalendar.Decoder.to_datetime("39930407T153022Z")
      ...> Timex.to_erl(date)
      {{3993, 4, 7}, {15, 30, 22}}

  And should return error for incorrect dates:

      iex> ICalendar.Decoder.to_datetime("1993/04/07")
      {:error, :invalid_format}

  It should handle timezones from  the Olson Database:

      iex> {:ok, date} = ICalendar.Decoder.to_datetime("19980119T020000",
      ...> %{tzid: "America/Chicago"})
      ...> [Timex.to_erl(date), date.time_zone]
      [{{1998, 1, 19}, {2, 0, 0}}, "America/Chicago"]
  """
  def to_datetime(date_string, %{tzid: timezone}) do
    {:ok, naive_date} =
      date_string
      |> String.trim_trailing("Z")
      |> to_datetime()

    {:ok, Timex.to_datetime(naive_date, timezone)}
  end

  def to_datetime(date_string, %{}) do
    # it's utc
    if String.ends_with?(date_string, "Z") do
      {:ok, naive_datetime} = to_datetime(date_string)
      DateTime.from_naive(naive_datetime, "Etc/UTC")
    else # its a relative date, parse as naive datetime
      date_string
      |> String.trim_trailing("Z")
      |> to_datetime()
    end
  end

  def to_datetime(string) do
    with <<year::4-bytes, month::2-bytes, day::2-bytes, ?T, rest::binary>> <- string,
         <<hour::2-bytes, min::2-bytes, sec::2-bytes, _rest::binary>> <- rest,
         {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {day, ""} <- Integer.parse(day),
         {hour, ""} <- Integer.parse(hour),
         {minute, ""} <- Integer.parse(min),
         {second, ""} <- Integer.parse(sec),
         {:ok, date} <- Date.new(year, month, day),
         {:ok, time} <- Time.new(hour, minute, second) do
         NaiveDateTime.new(date, time)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_format}
    end
  end

  def to_date(string) do
    with <<year::4-bytes, month::2-bytes, day::2-bytes>> <- string,
         {year, ""} <- Integer.parse(year),
         {month, ""} <- Integer.parse(month),
         {day, ""} <- Integer.parse(day) do
         Date.new(year, month, day)
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_format}
    end
  end

  def to_time(time_string, %{tzid: timezone}) do
    time_string =
      case String.last(time_string) do
        "Z" -> time_string
        _   -> time_string <> "Z"
      end

    Timex.parse(time_string <> timezone, "{h24}{m}{s}Z{Zname}")
  end

  def to_time(time_string, %{}) do
    to_time(time_string, %{tzid: "Etc/UTC"})
  end

  def to_time(time_string) do
    to_time(time_string, %{tzid: "Etc/UTC"})
  end

  @doc ~S"""

  This function should strip any sanitization that has been applied to content
  within an iCal string.

      iex> ICalendar.Decoder.unescape(~s(lorem\\, ipsum))
      "lorem, ipsum"
  """
  def unescape(string) do
    String.replace(string, ~s(\\), "")
  end
end
