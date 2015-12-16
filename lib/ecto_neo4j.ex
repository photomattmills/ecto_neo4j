defmodule Ecto.Neo4j do
  alias Neo4j.Sips.Connection
  alias Neo4j.Sips, as: Neo4j
  use GenServer

  @config Application.get_env(:neo4j_sips, Neo4j)
  @pool_name :neo4j_sips_pool

  def connect(opts) do
    Connection.start_link(opts)
  end

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
    # Neo4j.Sips.start(repo, opts)
    #
    Ecto.Pools.Poolboy.start_link(Connection, opts)

  end

  def conn do
    Neo4j.Sips.conn
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

  def execute(_repo, _query_meta, _prepared, _params, _arg4, _options) do
    {0, []}
  end

  def supports_ddl_transaction? do
    false
  end

  def dump(:binary_id, value), do: dump(Ecto.UUID, value)

  # this is definitely wrong, will need work to figure our supported types
  def dump(_something, term), do: {:ok, term}

  def insert(repo, schema_meta, fields, autogenerate_id, returning, options) do
    cypher = "CREATE (n:#{schema_meta.model} {#{fields_parser(fields)}})"
    Neo4j.query(Neo4j.conn, cypher)
    {:ok, []}
  end

  def fields_parser fields do
    fields
    |> Enum.filter(fn {k,v} -> v && v != "" end)
    |> Enum.map(fn {k, v} -> "#{Atom.to_string(k)} : '#{v}'" end)
    |> Enum.join ", "
  end

  def config, do: Application.get_env(:neo4j_sips, Neo4j)

  @doc false
  def config(key), do: Dict.get(config, key)

  @doc false
  def config(key, default), do: Dict.get(config, key, default)
end
