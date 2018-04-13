defmodule ICalendar.Decoder do
  def decode(string) do
    val =
      string
      # unfold
      |> String.replace(~r/\r?\n[ \t]/, "")
      # split on newline or CRLF
      |> String.split(~r/\r?\n/)
      |> Enum.reduce([], &stree/2)
      |> parse

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

  @props %{
    action:           %{default: :text},
    attach:           %{default: :uri}, # uri or binary
    attendee:         %{default: :cal_address},
    calscale:         %{default: :text},
    categories:       %{default: :text, multi: ","},
    class:            %{default: :text},
    comment:          %{default: :text},
    completed:        %{default: :date_time},
    contact:          %{default: :text},
    created:          %{default: :date_time},
    description:      %{default: :text},
    dtend:            %{default: :date_time, allowed: [:date_time, :date]},
    dtstamp:          %{default: :date_time},
    dtstart:          %{default: :date_time, allowed: [:date_time, :date]},
    due:              %{default: :date_time, allowed: [:date_time, :date]},
    duration:         %{default: :duration},
    exdate:           %{default: :date_time, allowed: [:date_time, :date], multi: ","},
    exrule:           %{default: :recur}, # deprecated
    freebusy:         %{default: :period, multi: ","},
    geo:              %{default: :float, structured: ";"},
    last_modified:    %{default: :date_time},
    location:         %{default: :text},
    method:           %{default: :text},
    organizer:        %{default: :cal_address},
    percent_complete: %{default: :integer},
    priority:         %{default: :integer},
    prodid:           %{default: :text},
    rdate:            %{default: :date_time, allowed: [:date_time, :date, :period], multi: ","}, # TODO: detect
    recurrence_id:    %{default: :date_time, allowed: [:date_time, :date]},
    related_to:       %{default: :text},
    repeat:           %{default: :integer},
    request_status:   %{default: :text},
    resources:        %{default: :text, multi: ","},
    rrule:            %{default: :recur},
    sequence:         %{default: :integer},
    status:           %{default: :text},
    summary:          %{default: :text},
    transp:           %{default: :text},
    trigger:          %{default: :duration, allowed: [:duration, :date_time]},
    tzid:             %{default: :text},
    tzname:           %{default: :text},
    tzoffsetfrom:     %{default: :utc_offset},
    tzoffsetto:       %{default: :utc_offset},
    tzurl:            %{default: :uri},
    uid:              %{default: :text},
    url:              %{default: :uri},
    version:          %{default: :text},
  }

  @parameters [
    "ALTREP",
    "CN",
    "CUTYPE",
    "DELEGATED-FROM",
    "DELEGATED-TO",
    "DIR",
    "ENCODING",
    "FMTTYPE",
    "FBTYPE",
    "LANGUAGE",
    "MEMBER",
    "PARTSTAT",
    "RANGE",
    "RELATED",
    "RELTYPE",
    "ROLE",
    "RSVP",
    "SENT-BY",
    "TZID",
    "VALUE"
  ]

  defp to_key(string) when is_atom(string), do: string
  defp to_key(string) do
    # TODO limit to_atom to @properties + @parameters
    string
    |> String.replace("-", "_")
    |> String.downcase
    |> String.to_atom
  end

  # tokenize data into a syntax tree
  defp stree("", stack), do: stack

  # pop a new collection onto the stack
  defp stree("BEGIN:" <> type, stack) do
    [[@types[type]] | stack]
  end

  defp stree("END:" <> type, [item, col | stack]) do
    # TODO: make sure end matches begin type
    [[Enum.reverse(item) | col] | stack]
  end
  # this is annoying
  defp stree("END:" <> type, [col]) do
    # TODO: make sure end matches begin type
    Enum.reverse(col)
  end

  defp stree(line, [col | stack]) do
    case String.split(line, ":", parts: 2) do
      [key, val] ->
        [key, params] = retrieve_params(key)
        [[{to_key(String.upcase(key)), val, params} | col] | stack]
    end
  end

  # Transform the stree structure into concrete types
  defp parse(key, acc \\ %{})

  # end of parsing!
  defp parse([], acc), do: acc

  # matches the outer-most value
  defp parse([key | attrs], _acc) when is_atom(key) do
    {key, parse(attrs)}
  end

  # matches a collection
  defp parse([obj | rest], acc) when is_list(obj) do
    {key, attrs} = parse(obj)
    parse(rest, Map.put(acc, key, attrs))
  end

  # matches a property
  defp parse([{key, val, params} | attrs], acc) do
    val = parse_spec(val, @props[key], params)
    # I wish we could skip this
    type = to_key(params[:value] || get_in(@props, [key, :default]) || :unknown)
    # drop value, we already used it while parsing
    val = {val, Map.drop(params, [:value]), type}

    l = Map.get(acc, key)
    if l do
      # TODO: have a list of properties that can be multiple
      parse(attrs, Map.put(acc, key, List.flatten([val | List.wrap(l)])))
    else
      parse(attrs, Map.put(acc, key, val))
    end
  end

  # --------

  # Use the typing data to parse a value
  def parse_spec(val, %{multi: delim} = spec, params) do
    val
    |> String.split(delim)
    |> Enum.map(fn val -> parse_spec(val, Map.drop(spec, [:multi]), params) end)
  end

  def parse_spec(val, %{structured: delim} = spec, params) do
    val
    |> String.split(delim)
    |> Enum.map(fn val -> parse_spec(val, Map.drop(spec, [:structured]), params) end)
    |> List.to_tuple()
  end

  def parse_spec(val, spec, params) do
    type = to_key(params[:value] || (spec || %{})[:default] || :unknown)
    parse_val(val, type, params)
  end

  # Per type parsing procedures

  def parse_val(val, :binary, %{encoding: "BASE64"}) do
    Base.decode64!(val)
  end

  def parse_val("TRUE", :boolean, _params), do: true
  def parse_val("FALSE", :boolean, _params), do: false

  def parse_val(val, :cal_address, params) do
    # TODO
    val
  end

  def parse_val(val, :date, params) do
    {:ok, date} = Timex.parse(val, "{YYYY}{0M}{0D}")
    date
  end

  def parse_val(val, :date_time, params) do
    {:ok, date} = to_date(val, params)
    date
  end

  # negative duration
  def parse_val("-" <> val, :duration, params) do
    val
    |> parse_val(:duration, params)
    |> Timex.Duration.invert()
  end

  # strip plus
  def parse_val("+" <> val, :duration, params) do
    parse_val(val, :duration, params)
  end

  def parse_val(val, :duration, _params) do
    {:ok, val} =
      val
      |> String.trim_trailing("T") # for some reason 1PDT is valid
      |> Timex.Parse.Duration.Parsers.ISO8601Parser.parse

    val
  end

  def parse_val(val, :float, _params) do
    {f, ""} = Float.parse(val)
    f
  end

  def parse_val(val, :integer, _params) do
    {f, ""} = Integer.parse(val)
    f
  end

  def parse_val(val, :period, _params) do
    [from, to] = String.split(val, "/", parts: 2, trim: true)

    from = parse_val(from, :date_time, %{})
    # to can either be a duration or a date_time
    to = if String.starts_with?(to, "P") do
      {:ok, val} = Timex.Parse.Duration.Parsers.ISO8601Parser.parse(to)
      val |> Map.drop([:__struct__]) |> Map.to_list
    else
      parse_val(to, :date_time, %{})
    end

    Timex.Interval.new(from: from, until: to)
  end

  def parse_val(val, :recur, _params) do
    {:ok, rrule} = ICalendar.RRULE.deserialize(val)
    rrule
  end

  def parse_val(val, :text, _params), do: unescape(val)

  def parse_val(val, :time, params) do
    {:ok, time} = to_time(val, params)
    time
  end

  def parse_val(val, :uri, _params), do: val

  def parse_val(val, :utc_offset, _params) do
    # TODO (not sure what the best way to store this is)
    val
  end

  # this could be x-vals
  def parse_val(val, :unknown, _), do: val


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
        [key, val] = String.split(param, "=", parts: 2, trim: true)
        # trim only leading and trailing double quote
        Map.merge(acc, %{to_key(key) => String.trim(val, ~s("))})
      end)

      [key, params]
  end

  @doc ~S"""
  This function is designed to parse iCal datetime strings into erlang dates.

  It should be able to handle dates from the past:

      iex> {:ok, date} = ICalendar.Decoder.to_date("19930407T153022Z")
      ...> Timex.to_erl(date)
      {{1993, 4, 7}, {15, 30, 22}}

  As well as the future:

      iex> {:ok, date} = ICalendar.Decoder.to_date("39930407T153022Z")
      ...> Timex.to_erl(date)
      {{3993, 4, 7}, {15, 30, 22}}

  And should return error for incorrect dates:

      iex> ICalendar.Decoder.to_date("1993/04/07")
      {:error, "Expected `2 digit month` at line 1, column 5."}

  It should handle timezones from  the Olson Database:

      iex> {:ok, date} = ICalendar.Decoder.to_date("19980119T020000",
      ...> %{tzid: "America/Chicago"})
      ...> [Timex.to_erl(date), date.time_zone]
      [{{1998, 1, 19}, {2, 0, 0}}, "America/Chicago"]
  """
  def to_date(date_string, %{tzid: timezone}) do
    date_string =
      case String.last(date_string) do
        "Z" -> date_string
        _   -> date_string <> "Z"
      end

    Timex.parse(date_string <> timezone, "{YYYY}{0M}{0D}T{h24}{m}{s}Z{Zname}")
    # This is slow
    #
    # Timex.Parse.DateTime.Parser.parse/3                                  7      51.783       0.036
    # Timex.Parse.DateTime.Parser.parse!/3                               7      51.783       0.036  <--
    # Timex.Parse.DateTime.Tokenizers.Default.tokenize/1               7      29.750       0.063
    # Timex.Parse.DateTime.Parser.do_parse/3                           7      21.997       0.148
    #
    # since it's a rigid format, use binary matching
  end

  def to_date(date_string, %{}) do
    to_date(date_string, %{tzid: "Etc/UTC"})
  end

  def to_date(date_string) do
    to_date(date_string, %{tzid: "Etc/UTC"})
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
    to_time(time_string, %{"TZID" => "Etc/UTC"})
  end

  def to_time(time_string) do
    to_time(time_string, %{"TZID" => "Etc/UTC"})
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
