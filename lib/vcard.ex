defmodule VCard do
  @moduledoc """
  Generating vCards
  """

  defdelegate decode(string), to: VCard.Decoder
  defdelegate encode(object), to: VCard.Encoder

  @doc """
  To create a Phoenix/Plug controller and view that output ics format:
  Add to your config.exs:
  ```
  config :phoenix, :format_encoders,
    ics: VCard
  ```
  In your controller use:
  `
    calendar = %VCard{ events: events }
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
  defdelegate encode_to_iodata(object, options \\ []), to: VCard.Encoder

  # vals: text, uri, date, time, date_time, date_and_or_time, timestamp
  # (ical date_time), language-tag

  @props %{
    adr:          %{default: :text, structured: ";", multi: ","},
    anniversary:  %{default: :date_and_or_time},
    bday:         %{default: :date_and_or_time},
    caladruri:    %{default: :uri},
    caluri:       %{default: :uri},
    clientpidmap: %{default: :text, structured: ";"},
    email:        %{default: :text},
    fburl:        %{default: :uri},
    fn:           %{default: :text},
    gender:       %{default: :text, structured: ";"},
    geo:          %{default: :uri},
    impp:         %{default: :uri},
    key:          %{default: :uri},
    kind:         %{default: :text},
    lang:         %{default: :language_tag},
    logo:         %{default: :uri},
    member:       %{default: :uri},
    n:            %{default: :text, structured: ";", multi: ","},
    nickname:     %{default: :text, multi: ","},
    note:         %{default: :text},
    org:          %{default: :text, structured: ";"},
    photo:        %{default: :uri},
    related:      %{default: :uri},
    rev:          %{default: :timestamp},
    role:         %{default: :text},
    sound:        %{default: :uri},
    source:       %{default: :uri},
    tel:          %{default: :uri, allowed: [:uri, :text]},
    title:        %{default: :text},
    tz:           %{default: :text, allowed: [:text, :utc_offset, :uri]},
    xml:          %{default: :text}
  }

  @params %{
    type: %{
      value: :text,
      multi: ","
    },
    value: %{
      values: [:text, :uri, :date, :time, :date_time, :date_and_or_time,
               :timestamp, :boolean, :integer, :float, :utc_offset,
               :language_tag],
      allow_x_name: true,
      allow_iana_token: true
    }
    # LANGUAGE VALUE PREF ALTID PID TYPE MEDIATYPE CALSCALE SORT-AS GEO TZ
  }

  @type spec :: %{optional(atom) => any}

  @spec __props__(atom) :: spec
  for {name, spec} <- @props do
    def __props__(unquote(name)) do
      unquote(Macro.escape(Map.put(spec, :context, :vcard)))
    end
  end
  def __props__(_), do: %{default: :unknown}

  @spec __params__(atom) :: spec
  for {name, spec} <- @params do
    def __params__(unquote(name)) do
      unquote(Macro.escape(Map.put(spec, :context, :vcard)))
    end
  end
  def __params__(_), do: %{default: :unknown}
end
