defmodule Expression.MixProject do
  use Mix.Project

  def project do
    [
      app: :expression,
      version: "0.2.1",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      dialyzer: dialyzer()
    ]
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
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
      {:nimble_parsec, "~> 1.1"},
      {:decimal, "~> 2.0"},
      {:timex, "~> 3.6"},
      {:number, "~> 1.0"},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.5", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false}
    ]
  end
end
