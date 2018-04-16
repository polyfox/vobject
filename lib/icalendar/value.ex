defprotocol ICalendar.Value do
  @fallback_to_any true
  @spec encode(value :: term, params :: map) :: iodata
  def encode(value, params \\ %{})
end

alias ICalendar.Value

defimpl Value, for: Tuple do
  def encode(vals, _opts) do
    vals
    |> Tuple.to_list()
    |> Enum.map(&Value.encode/1)
    |> Enum.join(";") # TODO configurable per field
  end
end

defimpl Value, for: ICalendar.Binary do
  def encode(val, _opts) do
    Binary.encode64(val.val)
  end
end

defimpl Value, for: Atom do
  def encode(nil, _),   do: ""
  def encode(true, _),  do: "TRUE"
  def encode(false, _), do: "FALSE"

  def encode(atom, _options) do
    Atom.to_string(atom)
  end
end

defimpl Value, for: ICalendar.Address do
  def encode(val, opts) do
    val.val
  end
end

defimpl Value, for: Date do
  import ICalendar.Util, only: [zero_pad: 2]
  def encode(val, _) do
    zero_pad(val.year, 4) <> zero_pad(val.month, 2) <> zero_pad(val.day, 2)
  end
end

defimpl Value, for: DateTime do
  def encode(%{time_zone: "Etc/UTC"} = val, _options) do
    date = Value.encode(DateTime.to_date(val))
    time = Value.encode(DateTime.to_time(val))
    date <> "T" <> time
  end

  def encode(%{time_zone: time_zone} = val, _options) do
    date = Value.encode(DateTime.to_date(val))
    time = Value.encode(DateTime.to_time(val))
    {
      date <> "T" <> time,
      %{tzid: time_zone}
    }
  end
end

defimpl Value, for: NaiveDateTime do
  def encode(val, _options) do
    date = Value.encode(NaiveDateTime.to_date(val))
    time = Value.encode(NaiveDateTime.to_time(val))
    date <> "T" <> time
  end
end

defimpl Value, for: Timex.Duration do
  def encode(val, _options) do
    string = Timex.Format.Duration.Formatter.format(val)
    if (val.seconds < 0) || (val.megaseconds < 0) || (val.microseconds < 0) do
      "-" <> string
    else
      string
    end
  end
end

defimpl Value, for: Float do
  def encode(val, _opts), do: to_string(val)
end

defimpl Value, for: Integer do
  def encode(val, _opts), do: to_string(val)
end

defimpl Value, for: ICalendar.Period do
  def encode(val, _opts) do
    from = Value.encode(val.from)
    until = Value.encode(val.until)
    from <> "/" <> until
  end
end

defimpl Value, for: ICalendar.RRULE do
  alias ICalendar.Util
  def encode(val, _opts) do
    val
    |> Map.from_struct
    |> Map.keys
    |> Util.RRULE.order_conventionally
    |> Enum.map(&(Util.RRULE.serialize(val, &1)))
    |> Enum.reject(&(&1 == nil))
    |> Enum.join(";")
  end
end

defimpl Value, for: BitString do
  @escape ~r/\\|;|,|\n/
  def encode(val, _opts) do
    # TODO: optimize: only run the regex if string contains those chars
    Regex.replace(@escape, val, fn
      "\\" -> "\\\\"
      ";" ->  "\\;"
      "," -> "\\,"
      "\n" -> "\\n"
      v -> v
    end)
  end
end

defimpl Value, for: ICalendar.Time do
  import ICalendar.Util, only: [zero_pad: 2]
  def encode(%{time_zone: "Etc/UTC"} = val, _opts) do
    zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2) <> "Z"
  end

  def encode(%{time_zone: time_zone} = val, _opts) when not is_nil(time_zone) do
    {
      zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2),
      %{tzid: time_zone}
    }
  end

  def encode(val, _opts) do
    zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2)
  end
end

defimpl Value, for: Time do
  import ICalendar.Util, only: [zero_pad: 2]
  def encode(val, _opts) do
    zero_pad(val.hour, 2) <> zero_pad(val.minute, 2) <> zero_pad(val.second, 2)
  end
end

defimpl Value, for: URI do
  def encode(val, _opts) do
    URI.to_string(val)
  end
end

defimpl Value, for: ICalendar.UTCOffset do
  def encode(val, opts) do
    val.val
  end
end
