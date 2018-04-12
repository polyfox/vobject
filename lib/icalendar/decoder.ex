defmodule ICalendar.Decoder do
  def decode(string) do
    val =
      string
      |> String.replace(~r/\r?\n[ \t]/, "")
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

  @properties [
    "ACTION",
    "ATTACH",
    "ATTENDEE",
    "CALSCALE",
    "CATEGORIES",
    "CLASS",
    "COMMENT",
    "COMPLETED",
    "CONTACT",
    "CREATED",
    "DESCRIPTION",
    "DTEND",
    "DTSTAMP",
    "DTSTART",
    "DUE",
    "DURATION",
    "EXDATE",
    "EXRULE",
    "FREEBUSY",
    "GEO",
    "LAST-MODIFIED",
    "LOCATION",
    "METHOD",
    "ORGANIZER",
    "PERCENT-COMPLETE",
    "PRIORITY",
    "PRODID",
    "RDATE",
    "RECURRENCE-ID",
    "RELATED-TO",
    "REPEAT",
    "REQUEST-STATUS",
    "RESOURCES",
    "RRULE",
    "SEQUENCE",
    "STATUS",
    "SUMMARY",
    "TRANSP",
    "TRIGGER",
    "TZID",
    "TZNAME",
    "TZOFFSETFROM",
    "TZOFFSETTO",
    "TZURL",
    "UID",
    "URL",
    "VERSION",
  ]

  @prop_types %{
    action:           :text,
    attach:           :text, # uri or binary
    attendee:         :cal_address,
    calscale:         :text,
    categories:       :text,
    class:            :text,
    comment:          :text,
    completed:        :date_time,
    contact:          :text,
    created:          :date_time,
    description:      :text,
    dtend:            :date_time, # check VALUE for :date
    dtstamp:          :date_time,
    dtstart:          :date_time,
    due:              :date_time,
    duration:         :duration,
    exdate:           :date_time,
    exrule:           :recur, # deprecated
    freebusy:         :period,
    geo:              :float,
    last_modified:    :date_time,
    location:         :text,
    method:           :text,
    organizer:        :cal_address,
    percent_complete: :integer,
    priority:         :integer,
    prodid:           :text,
    rdate:            :date_time, # :date or :period
    recurrence_id:    :date_time,
    related_to:       :text,
    repeat:           :integer,
    request_status:   :text,
    resources:        :text,
    rrule:            :recur,
    sequence:         :integer,
    status:           :text,
    summary:          :text,
    transp:           :text,
    trigger:          :duration, # can be date_time
    tzid:             :text,
    tzname:           :text,
    tzoffsetfrom:     :utc_offset,
    tzoffsetto:       :utc_offset,
    tzurl:            :uri,
    uid:              :text,
    url:              :uri,
    version:          :text,
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
    case String.split(line, ":", parts: 2, trim: true) do
      [key, val] ->
        [key, params] = retrieve_params(key)
        [[{String.upcase(key), val, params} | col] | stack]
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
    key = to_key(key)
    val = parse_vals(val, @prop_types[key], params)

    l = Map.get(acc, key)
    if l do
      # TODO: have a list of properties that can be multiple
      parse(attrs, Map.put(acc, key, [val | List.wrap(l)]))
    else
      parse(attrs, Map.put(acc, key, val))
    end
  end

  # --------

  defp parse_vals(val, type, params) do
    case String.split(val, ~r/(?<!\\)[;,]/) do
      [val] -> parse_val(val, type, params)
      vals -> Enum.map(vals, fn val -> parse_val(val, type, params) end)
    end
  end

  # if the type was changed, parse it correctly
  defp parse_val(val, _type, %{value: type} = params) do
    parse_val(val, to_key(type), Map.drop(params, [:value]))
  end

  defp parse_val(val, :binary, %{encoding: "BASE64"}) do
    Base.decode64!(val)
  end

  defp parse_val("TRUE", :boolean, _params), do: true
  defp parse_val("FALSE", :boolean, _params), do: false

  defp parse_val(val, :cal_address, params) do
    %ICalendar.Address{uri: val}
    |> Map.merge(params)
  end

  defp parse_val(val, :date, params) do
    {:ok, date} = Timex.parse(val, "{YYYY}{0M}{0D}")
    date
  end

  defp parse_val(val, :date_time, params) do
    {:ok, date} = to_date(val, params)
    date
  end

  defp parse_val(val, :duration, _params) do
    {:ok, val} =
      val
      |> String.trim_trailing("T") # for some reason 1PDT is valid
      |> Timex.Parse.Duration.Parsers.ISO8601Parser.parse

    val
  end

  defp parse_val(val, :float, _params) do
    {f, ""} = Float.parse(val)
    f
  end

  defp parse_val(val, :integer, _params) do
    {f, ""} = Integer.parse(val)
    f
  end

  defp parse_val(val, :period, _params) do
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

  defp parse_val(val, :recur, _params) do
    {:ok, rrule} = ICalendar.RRULE.deserialize(val)
    rrule
  end

  defp parse_val(val, :text, _params), do: unescape(val)

  defp parse_val(val, :time, params) do
    {:ok, time} = to_time(val, params)
    time
  end

  defp parse_val(val, :uri, _params), do: val

  defp parse_val(val, :utc_offset, _params) do
    # TODO (not sure what the best way to store this is)
    val
  end

  # this could be x-vals
  defp parse_val(val, nil, _), do: val

  defp parse_val(val, type, _) do
    IO.puts "unknown type! #{inspect type}"
    val
  end


  @doc ~S"""
  This function extracts parameter data from a key in an iCalendar string.

      iex> ICalendar.Decoder.retrieve_params(
      ...>   "DTSTART;TZID=America/Chicago")
      ["DTSTART", %{"TZID" => "America/Chicago"}]

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
  def to_date(date_string, %{"TZID" => timezone}) do
    date_string =
      case String.last(date_string) do
        "Z" -> date_string
        _   -> date_string <> "Z"
      end

    Timex.parse(date_string <> timezone, "{YYYY}{0M}{0D}T{h24}{m}{s}Z{Zname}")
  end

  def to_date(date_string, %{}) do
    to_date(date_string, %{"TZID" => "Etc/UTC"})
  end

  def to_date(date_string) do
    to_date(date_string, %{"TZID" => "Etc/UTC"})
  end


  def to_time(time_string, %{"TZID" => timezone}) do
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
