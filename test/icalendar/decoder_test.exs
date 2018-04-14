defmodule ICalendar.ParserTest do
  use ExUnit.Case
  alias ICalendar.Decoder
  alias ICalendar.Event
  doctest ICalendar.Decoder

  test "basic" do
    stream = File.read!("test/fixtures/event.ics")
    res = Decoder.decode(stream)

    IO.inspect res
  end

  test "nested" do
    str = ~s"""
    BEGIN:VCALENDAR
    PRODID:-//Google Inc//Google Calendar 70.9054//EN
    VERSION:2.0
    CALSCALE:GREGORIAN
    METHOD:REQUEST
    BEGIN:VEVENT
    DTSTART:20170419T091500Z
    DTEND:20170419T102500Z
    DTSTAMP:20170418T091329Z
    UID:00U5E000001JfN7UAK
    ORGANIZER;CN="Cyrus Daboo":mailto:cyrus@example.com
    ATTENDEE;CN="Cyrus Daboo";CUTYPE=INDIVIDUAL;PARTSTAT=ACCEPTED:
     mailto:cyrus@example.com
    ATTENDEE;CN="Wilfredo Sanchez Vega";CUTYPE=INDIVIDUAL;PARTSTAT
     =NEEDS-ACTION;ROLE=REQ-PARTICIPANT;RSVP=TRUE:mailto:wilfredo@
     example.com
    ATTENDEE;CN="Bernard Desruisseaux";CUTYPE=INDIVIDUAL;PARTSTAT=
     NEEDS-ACTION;ROLE=REQ-PARTICIPANT;RSVP=TRUE:mailto:bernard@ex
     ample.net
    ATTENDEE;CN="Mike Douglass";CUTYPE=INDIVIDUAL;PARTSTAT=NEEDS-A
     CTION;RSVP=TRUE:mailto:mike@example.org
    DESCRIPTION:some HTML in here
    LOCATION:here
    SEQUENCE:3
    STATUS:CONFIRMED
    SUMMARY:test reminder2
    TRANSP:OPAQUE
    BEGIN:VALARM
    ACTION:DISPLAY
    DESCRIPTION:testing reminders n stuff
    TRIGGER;VALUE=DATE-TIME:20170418T110500Z
    END:VALARM
    END:VEVENT
    END:VCALENDAR
    """

    res = Decoder.decode(str)

    IO.inspect res

  end

  test "duration" do

    str = ~s"""
    BEGIN:VCALENDAR
    PRODID:-//Google Inc//Google Calendar 70.9054//EN
    VERSION:2.0
    CALSCALE:GREGORIAN
    METHOD:REQUEST
    BEGIN:VEVENT
    DTSTART:20170419T091500Z
    DTEND:20170419T102500Z
    UID:00U5E000001JfN7UAK
    DESCRIPTION:some HTML in here
    LOCATION:here
    SEQUENCE:3
    STATUS:CONFIRMED
    SUMMARY:test reminder2
    TRANSP:OPAQUE
    BEGIN:VALARM
    ACTION:DISPLAY
    DESCRIPTION:testing reminders n stuff
    TRIGGER:PT3H12M25.001S
    END:VALARM
    END:VEVENT
    END:VCALENDAR
    """

    res = Decoder.decode(str)

    IO.inspect res

  end

  test "period" do
    # test period

    str = ~s"""
    BEGIN:VEVENT
    DTSTART:20170419T091500Z
    DTEND:20170419T102500Z
    UID:00U5E000001JfN7UAK
    DESCRIPTION:some HTML in here
    LOCATION:here
    STATUS:CONFIRMED
    SUMMARY:test reminder2
    RDATE;VALUE=PERIOD:19960403T020000Z/19960403T040000Z,
     19960404T010000Z/PT3H
    END:VEVENT
    """

    res = Decoder.decode(str)

    IO.inspect res

  end

  test "failing negative duration" do
    attr = "-PT10M"
    res = Decoder.parse_val(attr, :duration, %{})
  end

  test "failing duration 1PDT" do
    str = "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:-//PYVOBJECT//NONSGML Version 1//EN\nBEGIN:VEVENT\nUID:put-6@example.com\nDTSTART;VALUE=DATE:20190427\nDURATION:P1DT\nDTSTAMP:20051222T205953Z\nX-TEST;CN=George Herman ^'Babe^' Ruth:test\nX-TEXT;P=Hello^World:test\nSUMMARY:event 6\nEND:VEVENT\nEND:VCALENDAR\n"
    res = Decoder.decode(str)
    IO.inspect res
  end


end
