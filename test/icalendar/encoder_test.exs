defmodule ICalendar.EncoderTest do
  use ExUnit.Case
  alias ICalendar.Encoder
  alias ICalendar.Event
  doctest ICalendar.Encoder

  test "encode_params" do
    params = %{
      cn: "Bernard Desruisseaux",
      cutype: "INDIVIDUAL",
      partstat: "NEEDS-ACTION",
      role: "REQ-PARTICIPANT",
      rsvp: "TRUE"
    }

    res = Encoder.encode_params(params)

    correct = ~s(CN=Bernard Desruisseaux;CUTYPE=INDIVIDUAL;PARTSTAT=NEEDS-ACTION;ROLE=REQ-PARTICIPANT;RSVP=TRUE)
    assert res == correct
  end

  test "serialize" do
    stream = File.read!("test/fixtures/event.ics")
    {:ok, res} = ICalendar.Decoder.decode(stream)

    res = Encoder.encode(res)
    IO.inspect res
  end
end
