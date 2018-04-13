defmodule ICalendar.Encoder do

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

  def encode(obj) do
    encode_component(obj)
    |> List.flatten
    |> Enum.join("\n")
  end

  def encode_component({type, props}) do
    key = @types[type]
    [
      "BEGIN:#{key}",
      Enum.map(props, fn
        {key, vals} when is_list(vals) -> Enum.map(vals, fn val -> encode_prop(key, val) end)
        {key, val} -> encode_prop(key, val)
      end),
      "END:#{key}"
    ]
  end

  defp encode_key(key) do
    key
    |> Atom.to_string()
    |> String.upcase()
    |> String.replace("_", "-")
  end

  def encode_prop(key, %{} = component) do
    encode_component({key, component})
  end

  # TODO: match whether it's a multi , or ; key, or per attr
  def encode_prop(key, {vals, params, type}) when is_list(vals) do
    Enum.map(vals, &encode_prop(key, {&1, params, type}))
  end

  def encode_prop(key, {val, params, type}) do
    case encode_val(val, type) do
      {val, extra_params} ->
        # take any extra params the field encoding might have given
        encode_kparam(key, Map.merge(params, extra_params)) <> ":" <> val
      val ->
        encode_kparam(key, params) <> ":" <> val
    end
  end

  def encode_kparam(key, params) when params == %{}, do: encode_key(key)
  def encode_kparam(key, params) do
    encode_key(key) <> ";" <> encode_params(params)
  end

  def encode_params(params) do
    params
    # TODO escape parameter vals (^)
    |> Enum.map(fn {key, val} -> encode_key(key) <> "=" <> val end)
    |> Enum.join(";")
  end

  # -----------

  def encode_val(vals, type) when is_list(vals) do
    vals
    |> Enum.map(&encode_val(&1, type))
    |> Enum.join(",") # TODO configurable per field
  end

  def encode_val(val, :binary) do
    # TODO for non base64?
    {Base.encode64!(val), %{encoding: "BASE64"}}
  end

  def encode_val(true, :boolean), do: "TRUE"
  def encode_val(false, :boolean), do: "FALSE"

  def encode_val(val, :cal_address), do: val

  def encode_val(val, :date) do
    Timex.format!(val, "{YYYY}{0M}{0D}")
  end

  def encode_val(%{time_zone: "Etc/UTC"} = val, :date_time) do
    Timex.format!(val, "{YYYY}{0M}{0D}T{h24}{m}{s}Z")
  end

  def encode_val(val, :date_time) do
    {
      Timex.format!(val, "{YYYY}{0M}{0D}T{h24}{m}{s}"),
      %{tzid: val.time_zone}
    }
  end

  def encode_val(val, :duration) do
    string = Timex.Format.Duration.Formatter.format(val)
    if (val.seconds < 0) || (val.megaseconds < 0) || (val.microseconds < 0) do
      "-" <> string
    else
      string
    end
  end

  def encode_val(val, :float) do
    to_string(val)
  end

  def encode_val(val, :integer) do
    to_string(val)
  end

  def encode_val(val, :period) do
    # TODO
    ""
  end

  def encode_val(val, :recur) do
    #TODO:
    ""
  end

  @escape ~r/\\|;|,|\n/
  def encode_val(val, :text) do
    Regex.replace(@escape, val, fn
      "\\" -> "\\\\"
      ";" ->  "\\;"
      "," -> "\\,"
      "\n" -> "\\n"
      v -> v
    end)
  end

  def encode_val(%{time_zone: "Etc/UTC"} = val, :time) do
    Timex.format!(val, "{h24}{m}{s}Z")
  end

  def encode_val(val, :time) do
    {
      Timex.format!(val, "{h24}{m}{s}"),
      %{tzid: val.time_zone}
    }
  end

  def encode_val(val, :utc_offset) do
    # TODO once encoding is decided
    val
  end

  def encode_val(val, :unknown), do: val
end
