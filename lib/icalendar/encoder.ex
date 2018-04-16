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
  def encode_prop(key, {vals, params}, %{multi: delim}) when is_list(vals) do
    {val, params} = Enum.reduce(vals, {[], params}, fn val, {vals, params} ->
     case ICalendar.Value.encode(val) do
        {val, extra_params} ->
          {[val | vals], Map.merge(params, extra_params)}
        val ->
          {[val | vals], params}
      end
    end)
    [encode_kparam(key, params), ":", Enum.intersperse(val, delim), "\n"]
  end

  def encode_prop(key, {vals, params}, _spec) when is_list(vals) do
    Enum.map(vals, &encode_prop(key, {&1, params}))
  end

  def encode_prop(key, {val, params}, _spec) do
    # take any extra params the field encoding might have given
    {val, params} =  case ICalendar.Value.encode(val) do
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

end
