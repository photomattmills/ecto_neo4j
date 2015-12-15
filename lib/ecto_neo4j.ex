defmodule Ecto.Neo4j do
  alias Neo4j.Sips.Connection
  use GenServer

  def __before_compile__(_x) do

  end

  def storage_down(_something) do

  end

  def storage_up(_something) do
    :ok
  end

  def start_link(_repo, opts) do
    {:ok, _} = Application.ensure_all_started(:ecto_neo4j)
    # Connection.start_link(opts)
    # Connection.init([url: "htt://#{repo.config[:hostname]}:#{repo.config[:port]}"])
    # Neo4j.Sips.start(repo, opts)

    Ecto.Pools.Poolboy.start_link(Connection, opts)

  end

  def stop(pid, number) do
    Ecto.Adapters.Connection.shutdown(pid, number)
  end

  def execute_ddl(_arg0, _command, _arg2) do
    :ok
  end

  def prepare(_arg0, query) do
    {:nocache, query}
  end

  def execute(repo, query_meta, prepared, params, arg4, options) do
    {0, []}
  end

  def supports_ddl_transaction? do
    false
  end

  def dump(_something, _something_else) do
    {:ok, ""}
  end

  def insert(repo, schema_meta, fields, autogenerate_id, returning, options) do
    {:ok, []}
  end
end
