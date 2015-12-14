# Ecto Neo4j

This is a wrapper for using Ecto with a Neo4j database. Currently highly experimental, and likely to see drastic changes over the next couple months. Plans include a full Cypher query generator and all the good abstraction and familiar data modeling tools of Ecto, where compatible.

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

## TODO
  * `start_link/2` needs to actually start workers with poolboy (or similar)
  * Make tests pass (using wrapper? maybe)
  * Cypher Query Builder
    * each function in Cypher (find, where, etc.) has a corresponding method (limited to start)
    * methods take a struct of previous query elements

## Contributing

Comments, questions, and pull requests welcome. This project follows a code of conduct (fully at [code_of_conduct.md](code_of_conduct.md)) and by contributing, you agree to abide by that code.
