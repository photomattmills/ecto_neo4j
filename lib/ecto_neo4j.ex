defmodule Ecto.Neo4j do
  def __before_compile__(_x) do

  end

  def storage_down(_something) do

  end

  def storage_up(_something) do
    :ok
  end

  def start_link(repo, opts) do
    {:ok, _} = Application.ensure_all_started(:ecto_neo4j)

    repo.start_link(opts)
    # Neo4j.Sips.start(:Asdf, :asdf)
  end
end
