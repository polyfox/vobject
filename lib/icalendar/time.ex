defmodule ICalendar.Time do
  @moduledoc """
  Represents an iCalendar time.
  """
  @type t :: %__MODULE__{
    hour: Calendar.hour,
    minute: Calendar.minute,
    second: Calendar.second,
    time_zone: Calendar.time_zone()
  }

  defstruct [:hour, :minute, :second, :time_zone]

  def new(hour, minute, second, time_zone \\ nil) do
    {:ok, %__MODULE__{hour: hour, minute: minute, second: second, time_zone: time_zone}}
  end

  def from_time(%Elixir.Time{hour: hour, minute: minute, second: second}) do
    __MODULE__.new(hour, minute, second)
  end

  def to_time(%__MODULE__{hour: hour, minute: minute, second: second, time_zone: nil}) do
    Elixir.Time.new(hour, minute, second)
  end
end
