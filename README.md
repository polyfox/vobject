# VObject

Parse and manipulate iCalendar ([RFC5545](https://tools.ietf.org/html/rfc5545)) and vCard objects (RFC6350). Parameter escaping follows ([RFC6868](https://tools.ietf.org/html/rfc6868)).

Implementation is feature complete and standards-conformant.

## Usage


```elixir
string = ~s"""
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

{:ok, event} = ICalendar.decode(string)

# event
%{
  __type__: :event,
  description: {"some HTML in here", %{}, :text},
  dtend: {#DateTime<2017-04-19 10:25:00Z>, %{}, :date_time},
  dtstart: {#DateTime<2017-04-19 09:15:00Z>, %{}, :date_time},
  location: {"here", %{}, :text},
  rdate: {[
     %Timex.Interval{
       from: ~N[1996-04-03 02:00:00],
       left_open: false,
       right_open: true,
       step: [days: 1],
       until: ~N[1996-04-03 04:00:00]
     },
     %Timex.Interval{
       from: ~N[1996-04-04 01:00:00],
       left_open: false,
       right_open: true,
       step: [days: 1],
       until: ~N[1996-04-04 04:00:00]
     }
   ], %{}, :period},
  status: {"CONFIRMED", %{}, :text},
  summary: {"test reminder2", %{}, :text},
  uid: {"00U5E000001JfN7UAK", %{}, :text}
}

ICalendar.encode(event)
```

## Is it fast?

Yes

```
# Benchmarking with test/fixtures/blank_description.ics
Benchmarking decode...
Benchmarking encode...

Name             ips        average  deviation         median         99th %
encode        8.40 K      119.03 μs    ±17.19%         111 μs         196 μs
decode        1.67 K      598.95 μs    ±18.65%         574 μs        1072 μs

Comparison:
encode        8.40 K
decode        1.67 K - 5.03x slower
```

# TODO

- RFC 7986 - New Properties for iCalendar

- RFC 7265 - jCal
- RFC 6321 - xCal

- RFC 6350 - vCard (4.0) (todo: vCard 3)
  - RFC 6351 - xCard
  - RFC 7095 - jCard
