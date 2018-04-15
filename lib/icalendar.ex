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

  # cal_address and uri should be quoted
  # altrep delegated_from, delegated_to, dir, member, sent-by
  @params %{
    altrep: %{},
    cn: %{},
    cutype: %{values: ["INDIVIDUAL", "GROUP", "RESOURCE", "ROOM", "UNKNOWN"], allow_x_name: true, allow_iana: true},
    delegated_from: %{multi: ",", value: :cal_address},
    delegated_to: %{multi: ",", value: :cal_address},
    dir: %{},
    encoding: %{values: ["8BIT", "BASE64"]},
    fmttype: %{},
    fbtype: %{
      values: ["FREE", "BUSY", "BUSY-UNAVAILABLE", "BUSY-TENTATIVE"],
      allow_x_name: true,
      allow_iana: true
    },
    language: %{},
    member: %{multi: ",", value: :cal_address},
    # TODO These values are actually different per-component
    partstat: %{values: ["NEEDS-ACTION", "ACCEPTED", "DECLINED", "TENTATIVE",
                         "DELEGATED", "COMPLETED", "IN-PROCESS"],
      allow_x_name: true,
      allow_iana: true
    },
    range: %{values: ["THISANDFUTURE"]},
    related: %{values: ["START", "END"]},
    reltype: %{
      values: ["PARENT", "CHILD", "SIBLING"],
      allow_x_name: true,
      allow_iana_token: true
    },
    role: %{
      values: ["REQ-PARTICIPANT", "CHAIR", "OPT-PARTICIPANT", "NON-PARTICIPANT"],
      allow_x_name: true,
      allow_iana_token: true
    },
    rsvp: %{value: :boolean},
    sent_by: %{value: :cal_address},
    tzid: %{matches: ~r/^\//},
    value: %{
      values: [:binary, :boolean, :cal_address, :date, :date_time,
               :duration, :float, :integer, :period, :recur, :text,
               :time, :uri, :utc_offset],
      allow_x_name: true,
      allow_iana_token: true
    }
  }

  @type spec :: %{optional(atom) => any}

  @spec __props__(atom) :: spec
  for {name, spec} <- @props do
    def __props__(unquote(name)) do
      unquote(Macro.escape(spec))
    end
  end
  def __props__(_), do: %{default: :unknown}

  @spec __params__(atom) :: spec
  for {name, spec} <- @params do
    def __params__(unquote(name)) do
      unquote(Macro.escape(spec))
    end
  end
  def __params__(_), do: %{default: :unknown}
end
