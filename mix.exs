defmodule Ecto.Neo4j.Mixfile do
  use Mix.Project

  def project do
    [app: :ecto_neo4j,
     version: "0.0.1",
     elixir: "~> 1.1.0-dev",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :ecto, :neo4j_sips, :tzdata]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options

  defp deps do
    [
      {:neo4j_sips, "~> 0.1.12"},
      {:ecto, "~> 1.0"},
      {:timex, "~> 1.0.0"},
      {:dialyze, "~> 0.2.0", only: :dev},
      {:excoveralls, "~> 0.3.11", only: :test},
      {:inch_ex, only: :docs},
      {:earmark, "~> 0.1", only: :docs},
      {:ex_doc, "~> 0.8", only: :docs}
    ]
  end

  defp package do
    [# These are the default files included in the package
     files: ["lib", "priv", "mix.exs", "README*", "readme*", "LICENSE*", "license*"],
     maintainers: ["Matt Mills"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/mattmills/ecto_neo4j",
              "Docs" => "https://github.com/mattmills/ecto_neo4j/README.md"}]
  end
end
