defmodule Excellent.MixProject do
  use Mix.Project

  def project do
    [
      app: :excellent,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false}
    ]
  end
end
