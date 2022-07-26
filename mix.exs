defmodule Tm1638.MixProject do
  use Mix.Project

  @source_url "https://github.com/dkuku/tm_1638"

  def project do
    [
      app: :tm1638,
      version: "0.1.0",
      elixir: "~> 1.14-dev",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "tm1638",
      package: package(),
      description: description(),
      source_url: @source_url,
      docs: [
        extras: ["README.md"]
      ]
    ]
  end

      def package do
        %{
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}}
      end
  def description do
    "use tm1638 with nerves"
  end

  def application do
    [
      extra_applications: [:logger, :eex]
    ]
  end

  defp deps do
    [
      {:circuits_gpio, "~> 1.0"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end
end
