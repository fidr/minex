defmodule Minex.MixProject do
  use Mix.Project

  def project do
    [
      app: :minex,
      version: "0.1.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      package: package(),
      description: description(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:erlexec, "~> 1.10"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def description do
    """
    Simple deployment tool for Elixir
    """
  end

  defp package do
    [
      name: :minex,
      files: ["lib", "priv", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Robin Fidder"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/fidr/minex"}
    ]
  end

  defp docs do
    [
      name: "Minex",
      source_url: "https://github.com/fidr/minex",
      homepage_url: "https://github.com/fidr/minex",
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
