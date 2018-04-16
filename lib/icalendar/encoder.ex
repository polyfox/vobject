defmodule ICalendar.Encoder do
  alias ICalendar.RFC6868
  alias ICalendar.Util
  import ICalendar, only: [__props__: 1]

  @types %{
    event: "VEVENT",
    alarm: "VALARM",
    calendar: "VCALENDAR",
    todo: "VTODO",
    journal: "VJOURNAL",
    freebusy: "VFREEBUSY",
    timezone: "VTIMEZONE",
    standard: "STANDARD",
    daylight: "DAYLIGHT",
  }

  @doc "Encode into iCal format."
  def encode(obj) do
    obj
    |> encode_component
    |> IO.iodata_to_binary
  end

  def encode_to_iodata(obj, _opts \\ []) do
    encode_component(obj)
  end

  @doc "Encode a component."
  @spec encode_component(component :: map) :: iodata
  def encode_component(%{__type__: key} = component) do
    key = @types[key]
    [
      "BEGIN:#{key}",
      "\n",
      # TODO: map drop is slow, use some form of a skip, probably reduce
      Enum.map(Map.drop(component, [:__type__]), fn
        {key, vals} when is_list(vals) -> Enum.map(vals, fn val -> encode_prop(key, val) end)
        {key, val} -> encode_prop(key, val)
      end),
      "END:#{key}",
      "\n",
    ]
  end

  defp encode_key(key) do
    key
    |> Atom.to_string()
    |> String.upcase()
    |> String.replace("_", "-")
  end

  @doc "Encode a property."
  def encode_prop(_key, %{} = component) do
    encode_component(component)
  end

  def encode_prop(key, data) when is_tuple(data) do
    # shim: load the spec data
    # TODO: make this neater
    spec = __props__(key)
    encode_prop(key, data, spec)
  end

  # HAXX: we skip the per line encode here, but this isn't too elegant
  def encode_prop(key, {vals, params, type}, %{multi: delim}) when is_list(vals) do
    {val, params} = Enum.reduce(vals, {[], params}, fn val, {vals, params} ->
      case encode_val(val, type) do
        {val, extra_params} ->
          {[val | vals], Map.merge(params, extra_params)}
        val ->
          {[val | vals], params}
      end
    end)
    [encode_kparam(key, params), ":", Enum.intersperse(val, delim), "\n"]
  end

  def encode_prop(key, {vals, params, type}, _spec) when is_list(vals) do
    Enum.map(vals, &encode_prop(key, {&1, params, type}))
  end

  def encode_prop(key, {val, params, type}, _spec) do
    # take any extra params the field encoding might have given
    {val, params} =  case encode_val(val, type) do
      {val, extra_params} ->
        {val, Map.merge(params, extra_params)}
      val ->
        {val, params}
    end
    [encode_kparam(key, params), ":", val, "\n"]
  end

  @doc "Encode a key together with parameters."
  def encode_kparam(key, params) when params == %{}, do: encode_key(key)
  def encode_kparam(key, params) do
    [encode_key(key), ";", encode_params(params)]
  end

  @doc "Encode parameters."
  @spec encode_params(params :: map) :: String.t
  def encode_params(params) do
    params
    |> Enum.map(fn {key, val} -> encode_key(key) <> "=" <> RFC6868.escape(val) end)
    |> Enum.join(";")
  end

  # -----------

  # TODO: move helper
  defp zero_pad(val, count) when val >= 0 do
    num = Integer.to_string(val)
    :binary.copy("0", count - byte_size(num)) <> num
  end

  @doc "Encode a value."
  def encode_val(vals, type) when is_tuple(vals) do
    vals
    |> Tuple.to_list()
    |> Enum.map(&encode_val(&1, type))
    |> Enum.join(";") # TODO configurable per field
  end

  def encode_val(val, :binary) do
    # TODO for non base64?
    {Base.encode64(val), %{encoding: "BASE64"}}
  end

  def encode_val(true, :boolean), do: "TRUE"
  def encode_val(false, :boolean), do: "FALSE"

  def encode_val(val, :cal_address), do: val

  def encode_val(val, :date) do
    zero_pad(val.year, 4) <> zero_pad(val.month, 2) <> zero_pad(val.day, 2)
  end

  # TODO: just match on the next case for when not == Etc/UTC
  def encode_val(%{time_zone: "Etc/UTC"} = val, :date_time) do
    date = encode_val(val, :date)
    time = encode_val(val, :time)
    date <> "T" <> time
  end

  def encode_val(%{time_zone: _time_zone} = val, :date_time) do
    date = encode_val(val, :date)
    {time, params} = encode_val(val, :time)
    {
      date <> "T" <> time,
      params
    }
  end

  def encode_val(val, :date_time) do
    date = encode_val(val, :date)
    time = encode_val(val, :time)
    date <> "T" <> time
  end

  def encode_val(val, :duration) do
    string = Timex.Format.Duration.Formatter.format(val)
    if (val.seconds < 0) || (val.megaseconds < 0) || (val.microseconds < 0) do
      "-" <> string
    else
      string
    end
  end

  def encode_val(val, :float), do: to_string(val)

  def encode_val(val, :integer), do: to_string(val)

  def encode_val(val, :period) do
    from = encode_val(val.from, :date_time)
    until = case val.until do
      %Timex.Duration{} = val ->
        encode_val(val, :duration)
      val ->
        encode_val(val, :date_time)
    end

    from <> "/" <> until
  end

  def encode_val(val, :recur) do
    val
    |> Map.from_struct
    |> Map.keys
    |> Util.RRULE.order_conventionally
    |> Enum.map(&(Util.RRULE.serialize(val, &1)))
    |> Enum.reject(&(&1 == nil))
    |> Enum.join(";")
  end

  @escape ~r/\\|;|,|\n/
  def encode_val(val, :text) do
    # TODO: optimize: only run the regex if string contains those chars
    Regex.replace(@escape, val, fn
      "\\" -> "\\\\"
      ";" ->  "\\;"
      "," -> "\\,"
      "\n" -> "\\n"
      v -> v
    end)
  end

  def encode_val(%{time_zone: "Etc/UTC"} = val, :time) do
    zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2) <> "Z"
  end

  def encode_val(%{time_zone: time_zone} = val, :time) do
    {
      zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2),
      %{tzid: time_zone}
    }
  end

  def encode_val(val, :time) do
    zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2)
  end

  def encode_val(val, :uri), do: val

  # TODO once encoding is decided
  def encode_val(val, :utc_offset), do: val

  def encode_val(val, :unknown), do: val
end
