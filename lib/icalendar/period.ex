defmodule ICalendar.Period do
  @moduledoc """
  Represents an iCalendar time period. from is a datetime, and end until is a
  datetime or duration value. Can be converted to a Timex.Interval for
  calculation.

  The reason we don't decode directly to a Timex.Interval is that Timex always
  normalizes the until value into a DateTime, so we lose the original duration.
  """
  @type t :: %__MODULE__{
    from: NaiveDateTime.t | DateTime.t,
    until: NaiveDateTime.t | DateTime.t | Timex.Duration.t
  }

  defstruct from: nil, until: nil

  @doc """
  Converts a period to a Timex.Interval.

  ## Examples

  Absolute range

    iex> {:ok, from, _} = DateTime.from_iso8601("1996-04-03 02:00:00Z")
    iex> {:ok, to, _} = DateTime.from_iso8601("1996-04-03 04:00:00Z")
    iex> ICalendar.Period.to_interval(%ICalendar.Period{from: from, until: to})
    %Timex.Interval{from: ~N[1996-04-03 02:00:00], left_open: false, right_open: true, step: [days: 1], until: ~N[1996-04-03 04:00:00]}

  Start datetime plus duration

    iex> {:ok, from, _} = DateTime.from_iso8601("1996-04-03 02:00:00Z")
    iex> {:ok, to} = Timex.Parse.Duration.Parsers.ISO8601Parser.parse("P1D")
    iex> ICalendar.Period.to_interval(%ICalendar.Period{from: from, until: to})
    %Timex.Interval{from: ~N[1996-04-03 02:00:00], left_open: false, right_open: true, step: [days: 1], until: ~N[1996-04-04 02:00:00]}
  """
  def to_interval(%__MODULE__{from: from, until: %Timex.Duration{} = until}) do
    # Convert until to something Interval can accept if it's a Timex.Duration
    until = until |> Map.drop([:__struct__]) |> Map.to_list
    Timex.Interval.new(from: from, until: until)
  end

  def to_interval(%__MODULE__{from: from, until: until}) do
    Timex.Interval.new(from: from, until: until)
  end
end
