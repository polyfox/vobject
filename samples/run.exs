stream = File.read!("test/fixtures/blank_description.ics")
{:ok, decoded} = ICalendar.Decoder.decode(stream)
ICalendar.Encoder.encode(decoded)
IO.inspect decoded

#:eflame.apply(ICalendar.Decoder, :decode, [stream])
#

Benchee.run(%{
  "decode"    => fn -> ICalendar.Decoder.decode(stream) end,
  "encode"    => fn -> ICalendar.Encoder.encode(decoded) end,
}, time: 10, memory_time: 2)
stream = "BEGIN:VCALENDAR\nPRODID:-//Google Inc//Google Calendar 70.9054//EN\nVERSION:2.0\nCALSCALE:GREGORIAN\nX-WR-CALNAME:calmozilla1@gmail.com\nX-WR-TIMEZONE:America/Los_Angeles\nBEGIN:VTIMEZONE\nTZID:America/Los_Angeles\nX-LIC-LOCATION:America/Los_Angeles\nBEGIN:DAYLIGHT\nTZOFFSETFROM:-0800\nTZOFFSETTO:-0700\nTZNAME:PDT\nDTSTART:19700308T020000\nRRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU\nEND:DAYLIGHT\nBEGIN:STANDARD\nTZOFFSETFROM:-0700\nTZOFFSETTO:-0800\nTZNAME:PST\nDTSTART:19701101T020000\nRRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU\nEND:STANDARD\nEND:VTIMEZONE\nBEGIN:VEVENT\nDTSTART;TZID=America/Los_Angeles:20120630T060000\nDTEND;TZID=America/Los_Angeles:20120630T070000\nDTSTAMP:20120724T212411Z\nUID:dn4vrfmfn5p05roahsopg57h48@google.com\nCREATED:20120724T212411Z\nDESCRIPTION:\nLAST-MODIFIED:20120724T212411Z\nLOCATION:\nSEQUENCE:0\nSTATUS:CONFIRMED\nSUMMARY:Really long event name thing\nTRANSP:OPAQUE\nBEGIN:VALARM\nACTION:EMAIL\nDESCRIPTION:This is an event reminder\nSUMMARY:Alarm notification\nATTENDEE:mailto:calmozilla1@gmail.com\nTRIGGER:-P0DT0H30M0S\nEND:VALARM\nBEGIN:VALARM\nACTION:DISPLAY\nDESCRIPTION:This is an event reminder\nTRIGGER:-P0DT0H30M0S\nEND:VALARM\nEND:VEVENT\nEND:VCALENDAR\n"
