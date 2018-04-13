stream = File.read!("test/fixtures/blank_description.ics")
{:ok, decoded} = ICalendar.Decoder.decode(stream)

Benchee.run(%{
  "decode"    => fn -> 
    ICalendar.Decoder.decode(stream)
  end,
  "encode"    => fn -> 
    ICalendar.Encoder.encode(decoded)
  end,
}, time: 10)
