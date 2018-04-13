defmodule ICalendar.Encoder do

  def encode({type, props}) do
    props
    |> Enum.map(fn
      {key, vals} when is_list(vals) -> Enum.map(vals, fn val -> encode_prop(key, val) end)
      {key, val} -> encode_prop(key, val)
    end)
    |> List.flatten
  end

  defp encode_key(key) do
    key
    |> Atom.to_string()
    |> String.upcase()
  end


  def encode_prop(key, {val, params, type}) do
    Enum.join([
      encode_kparam(key, params),
      encode_val(val, type)
    ], ":")
  end

  def encode_kparam(key, %{}), do: encode_key(key)
  def encode_kparam(key, params) do
    encode_key(key) <> ";" <> encode_params(params)
  end

  def encode_params(params) when params == %{}, do: nil
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
    # TODO
  end

  def encode_val(true, :boolean), do: "TRUE"
  def encode_val(false, :boolean), do: "FALSE"

  def encode_val(val, :cal_address), do: val

  def encode_val(val, :date) do
    Timex.format!(val, "{YYYY}{0M}{0D}")
  end

  def encode_val(val, :date_time) do
    # TODO
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
  end

  def encode_val(val, :recur) do
    #TODO:
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

  def encode_val(val, :time) do
    # TODO timezones
  end

  def encode_val(val, :utc_offset) do
    # TODO once encoding is decided
    val
  end

  # TODO: replace nil with unknown
  def encode_val(val, nil) do
    val
  end
end
