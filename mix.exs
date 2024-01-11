defmodule Expression.MixProject do
  use Mix.Project

  @version "2.29.0"

  def project do
    [
      app: :expression,
      aliases: aliases(),
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      dialyzer: dialyzer()
    ]
  end

  defp package() do
    [
      licenses: ["AGPL-3.0"],
      links: %{"GitHub" => "https://github.com/turnhub/expression"}
    ]
  end

  defp description() do
    "A Excel like expression parser, compatible with FLOIP Expression language."
  end

  defp dialyzer() do
    [
      plt_core_path: ".plts",
      plt_file: {:no_warn, ".plts/dialyzer.plt"},
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:benchee, "~> 1.0", only: :dev},
      {:credo, "~> 1.5", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.28.2", only: :dev, runtime: false},
      {:ex_phone_number, "~> 0.4.1"},
      {:jason, "~> 1.0"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:nimble_parsec, "~> 1.1"},
      {:number, "~> 1.0"},
      {:timex, "~> 3.7"},
      {:version_tasks, "~> 0.12.0", only: [:dev], runtime: false}
    ]
  end

  defp aliases do
    [
      "release.major": ["version.up major", "version.tag"],
      "release.minor": ["version.up minor", "version.tag"],
      "release.patch": ["version.up patch", "version.tag"]
    ]
  end
end
