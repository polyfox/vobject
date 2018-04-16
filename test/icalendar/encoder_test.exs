defmodule ICalendar.EncoderTest do
  use ExUnit.Case
  alias ICalendar.{Encoder, Value}
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
    #stream = File.read!("test/fixtures/event.ics")
    #{:ok, res} = ICalendar.Decoder.decode(stream)

    #IO.inspect res
    #res = Encoder.encode(res)
    #IO.puts res

    stream = File.read!("test/fixtures/blank_description.ics")
    {:ok, res} = ICalendar.Decoder.decode(stream)


    IO.inspect res
    res = Encoder.encode_to_iodata(res)
    #res = Encoder.encode(res)
    IO.puts res
  end

  test "properly encode text" do
    assert Value.encode("test;me,putting\\quotes\nnow") == ~S(test\;me\,putting\\quotes\nnow)
  end

  test "properly encode period" do
    {:ok, from, _} = DateTime.from_iso8601("1996-04-03 02:00:00Z")
    {:ok, to, _} = DateTime.from_iso8601("1996-04-03 04:00:00Z")
    period = %ICalendar.Period{from: from, until: to}
    assert Value.encode(period) == "19960403T020000Z/19960403T040000Z"

    {:ok, from, _} = DateTime.from_iso8601("1996-04-03 02:00:00Z")
    {:ok, to} = Timex.Parse.Duration.Parsers.ISO8601Parser.parse("P1D")
    period = %ICalendar.Period{from: from, until: to}
    assert Value.encode(period) == "19960403T020000Z/P1D"
  end

  test "properly encode time" do
    {:ok, time} = ICalendar.Time.new(17, 30, 15, "America/Los_Angeles")
    assert Value.encode(time) == {"173015", %{tzid: "America/Los_Angeles"}}

    time = ~T[13:00:07]
    assert Value.encode(time) == "130007"

    time = ~T[13:00:07]
    {:ok, time} = ICalendar.Time.from_time(time)
    assert Value.encode(time) == "130007"
  end

  test "properly encode an inline multi value" do
    expected = ["CATEGORIES", ":", ["cat3", ",", "cat2", ",", "cat1"], "\n"]
    res = Encoder.encode_prop(:categories, {["cat1", "cat2", "cat3"], %{}, :text}, %{multi: ","})

    assert res == expected

    expected = [
      ["CATEGORIES", ":", "cat1", "\n"],
      ["CATEGORIES", ":", "cat2", "\n"],
      ["CATEGORIES", ":", "cat3", "\n"]
    ]
    res = Encoder.encode_prop(:categories, {["cat1", "cat2", "cat3"], %{}, :text}, %{})
    assert res == expected
  end
end
