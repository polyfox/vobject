defmodule ICalendar do
  @moduledoc """
  Generating ICalendars
  """

  defstruct events: []
  defdelegate to_ics(events), to: ICalendar.Serialize
  defdelegate decode(string), to: ICalendar.Decoder
  defdelegate encode(string), to: ICalendar.Encoder

  @doc """
  To create a Phoenix/Plug controller and view that output ics format:
  Add to your config.exs:
  ```
  config :phoenix, :format_encoders,
    ics: ICalendar
  ```
  In your controller use:
  `
    calendar = %ICalendar{ events: events }
    render(conn, "index.ics", calendar: calendar)
  `
  The important part here is `.ics`. This triggers the `format_encoder`.

  In your view can put:
  ```
  def render("index.ics", %{calendar: calendar}) do
    calendar
  end
  ```
  """
  def encode_to_iodata(calendar, options \\ []) do
    {:ok, encode_to_iodata!(calendar, options)}
  end
  def encode_to_iodata!(calendar, _options \\ []) do
    to_ics(calendar)
  end

  @props %{
    action:           %{default: :text},
    attach:           %{default: :uri}, # uri or binary
    attendee:         %{default: :cal_address},
    calscale:         %{default: :text},
    categories:       %{default: :text, multi: ","},
    class:            %{default: :text},
    comment:          %{default: :text},
    completed:        %{default: :date_time},
    contact:          %{default: :text},
    created:          %{default: :date_time},
    description:      %{default: :text},
    dtend:            %{default: :date_time, allowed: [:date_time, :date]},
    dtstamp:          %{default: :date_time},
    dtstart:          %{default: :date_time, allowed: [:date_time, :date]},
    due:              %{default: :date_time, allowed: [:date_time, :date]},
    duration:         %{default: :duration},
    exdate:           %{default: :date_time, allowed: [:date_time, :date], multi: ","},
    exrule:           %{default: :recur}, # deprecated
    freebusy:         %{default: :period, multi: ","},
    geo:              %{default: :float, structured: ";"},
    last_modified:    %{default: :date_time},
    location:         %{default: :text},
    method:           %{default: :text},
    organizer:        %{default: :cal_address},
    percent_complete: %{default: :integer},
    priority:         %{default: :integer},
    prodid:           %{default: :text},
    rdate:            %{default: :date_time, allowed: [:date_time, :date, :period], multi: ","}, # TODO: detect
    recurrence_id:    %{default: :date_time, allowed: [:date_time, :date]},
    related_to:       %{default: :text},
    repeat:           %{default: :integer},
    request_status:   %{default: :text},
    resources:        %{default: :text, multi: ","},
    rrule:            %{default: :recur},
    sequence:         %{default: :integer},
    status:           %{default: :text},
    summary:          %{default: :text},
    transp:           %{default: :text},
    trigger:          %{default: :duration, allowed: [:duration, :date_time]},
    tzid:             %{default: :text},
    tzname:           %{default: :text},
    tzoffsetfrom:     %{default: :utc_offset},
    tzoffsetto:       %{default: :utc_offset},
    tzurl:            %{default: :uri},
    uid:              %{default: :text},
    url:              %{default: :uri},
    version:          %{default: :text},
  }

  @type spec :: %{optional(atom) => any}

  @spec __props__(atom) :: spec
  for {name, spec} <- @props do
    def __props__(unquote(name)) do
      unquote(Macro.escape(spec))
    end
  end

  def __props__(_), do: %{default: :unknown}
end

defimpl ICalendar.Serialize, for: ICalendar do
  def to_ics(calendar) do
  events = Enum.map( calendar.events, &ICalendar.Serialize.to_ics/1 )
  """
  BEGIN:VCALENDAR
  CALSCALE:GREGORIAN
  VERSION:2.0
  #{events}END:VCALENDAR
  """
  end
end
