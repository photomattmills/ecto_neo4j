# Ecto Neo4j

This is a wrapper for using Ecto with a Neo4j database.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add ecto_neo4j to your list of dependencies in `mix.exs`:

        def deps do
          [{:ecto_neo4j, "~> 0.0.1"}]
        end

  2. Ensure ecto_neo4j is started before your application:

        def application do
          [applications: [:ecto_neo4j]]
        end
