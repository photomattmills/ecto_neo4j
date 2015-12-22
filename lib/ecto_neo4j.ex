defmodule Ecto.Neo4j do
  alias Neo4j.Sips.Connection
  alias Neo4j.Sips, as: Neo4j
  use GenServer
  require IEx

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
    Ecto.Pools.Poolboy.start_link(Connection, opts)
  end
  #
  # def conn do
  #   Neo4j.Sips.conn
  # end

  def stop(pid, number) do
    Ecto.Adapters.Connection.shutdown(pid, number)
  end

  def execute_ddl(_arg0, _command, _arg2) do
    :ok
  end

  def prepare(arg0, query) do
    {:nocache, {arg0, query}}
  end

  def execute(repo, meta, query, params, preprocess, options) do
    # IO.inspect [repo, meta, query, params, preprocess, options]
    cypher = build_cypher(query)
    IO.inspect cypher
    {:ok, return} = Neo4j.query(Neo4j.conn, cypher)
    {Enum.count(return), return}
  end

  def extract_column expr do
    {{_,_,[head|columns]},_,_} = expr
    hd columns
  end


  def build_cypher({type, query}) do
    case type do
      :all ->
        columns = query.select.fields |> Enum.map(fn expr -> extract_column(expr) end)
        columns_string = columns |> Enum.map(fn column -> "m.#{column}" end)
        {from, _} = query.from
        "MATCH (m:#{from}) RETURN #{columns_string |> Enum.join(", ")}"
    end
  end

  def supports_ddl_transaction? do
    false
  end

  # def load(type, value), do: Ecto.Type.load(type, value, &load/2)
  def load(type, value) do
    {:ok, value}
  end

  def dump(:binary_id, value), do: dump(Ecto.UUID, value)

  # this is definitely wrong, will need work to figure our supported types
  def dump(_something, term), do: {:ok, term}

  def insert(repo, schema_meta, fields, autogenerate_id, returning, options) do
    # IO.puts "insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert insert "
    {_, table} = schema_meta.source
    cypher = "CREATE (n:#{table} {#{fields_parser(fields)}}) RETURN n"
    {:ok, [result] } = Neo4j.query(Neo4j.conn, cypher)
    new_result = result["n"]
      |> Enum.map(fn {key,value} -> {String.to_atom(key), value}  end)
      |> Enum.into(%{})
    {:ok, new_result}
  end

  def return_fields_parser fields do
    fields
    |> Enum.filter(fn {k,v} -> v && v != "" end)
    |> Enum.map(fn {k, v} -> "#{Atom.to_string(k)}" end)
    |> Enum.join ", "
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
