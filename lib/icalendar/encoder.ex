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

  def encode_kparam(key, %{}), do: key
  def encode_kparam(key, params) do
    key <> ";" <> encode_params(params)
  end

  def encode_params(params) when params == %{}, do: nil
  def encode_params(params) do
    params
    # TODO escape val
    |> Enum.map(fn {key, val} -> encode_key(key) <> "=" <> val end)
    |> Enum.join(";")
  end

  def encode_val(val, type) do
    inspect(val)
  end

end
