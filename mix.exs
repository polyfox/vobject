defmodule VObject.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :vobject,
      version: @version,
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),

      name: "vobject",
      source_url: "https://github.com/polyfox/vobject",
      description: "Parse and manipulate iCalendar (RFC5545) and vCard objects (RFC6350)",
      package: [
        maintainers: ["Blaž Hrastnik"],
        licenses: ["MIT"],
        links: %{ "GitHub" => "https://github.com/polyfox/vobject" },
      ],
    ]
  end

  def application do
    [extra_applications: [:runtime_tools]]
  end

  defp deps do
    [
      # Code style linter
      {:dogma, ">= 0.0.0", only: ~w(dev test)a},
      # Automatic test runner
      {:mix_test_watch, ">= 0.0.0", only: :dev},

      # Markdown processor
      {:earmark, "~> 1.0", only: [:dev, :test]},
      # Documentation generator
      {:ex_doc, "~> 0.18", only: [:dev, :test]},

      {:benchee, "~> 0.11", only: :dev},
      {:benchee_html, "~> 0.4", only: :dev},

      {:dbg, github: "fishcakez/dbg", only: :dev},

      # For full timezone support
      {:timex, "~> 3.0"}
    ]
  end
end
