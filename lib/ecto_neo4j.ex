defmodule Ecto.Neo4j do
  alias Neo4j.Sips.Connection
  alias Neo4j.Sips, as: Neo4j
  use Timex
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
    Neo4j.query(Neo4j.conn, "MATCH (n) DELETE n")
    :ok
  end

  def embed_id(_) do
    Ecto.UUID.generate
  end

  def storage_up(_something) do
    :ok
  end

  def start_link(_repo, opts) do
    {:ok, _} = Application.ensure_all_started(:ecto_neo4j)
    Ecto.Pools.Poolboy.start_link(Connection, opts)
  end

  def stop(pid, number) do
    Ecto.Adapters.Connection.shutdown(pid, number)
  end

  def execute_ddl(_arg0, _command, _arg2) do
    :ok
  end

  def prepare(arg0, query) do
    {:nocache, {arg0, query}}
  end

  def execute(_repo, _meta, query, _params, _preprocess, _options) do
    cypher = build_cypher(query)
    {:ok, return} = Neo4j.query(Neo4j.conn, cypher)
    sorted_return = return |> Enum.map(fn column -> sort_column(column, query) end)
    {Enum.count(return), sorted_return}
  end

  def sort_column(col, query) do
    columns = result_columns(query)
    if hd(columns) do
      columns |> Enum.map(fn {name, type} -> coerce(type, col[Atom.to_string(name)]) end)
    else
      [nil]
    end
  end

  def coerce(type, value) do
    {:ok, return_val} = load(type, value)
    return_val
  end

  def extract_column(expr) when is_tuple(expr) do
    {{_,_,[_head|columns]},_type,_} = expr
    hd(columns)
  end
  def extract_column(expr), do: expr

  def result_columns({_type, query}) do
    query.select.fields |> Enum.map(fn expr -> extract_column_with_type(expr) end)
  end

  def extract_column_with_type(expr) when expr != nil do
    {{_,_,[_head|columns]},type,_} = expr
    {hd(columns), type[:ecto_type]}
  end
  def extract_column_with_type(expr), do: expr

  def build_cypher(query) do
    {type, query_obj} = query
    case type do
      :all ->
        columns_string = columns(query) |> Enum.uniq |> Enum.map(fn column -> "m.#{column} as #{column}" end)
        {from, _} = query_obj.from
        "MATCH (m:#{from}) RETURN #{columns_string |> Enum.join(", ")}"
    end
  end

  def columns({_type, query}) do
    query.select.fields |> Enum.map(fn expr -> extract_column(expr) end)
  end

  def supports_ddl_transaction? do
    false
  end

  def load(Ecto.DateTime, value) do
    {:ok, date} = value
    |> DateFormat.parse("%Y-%m-%d %H:%M:%S", :strftime)
    date |> DateConvert.to_erlang_datetime
    |> Ecto.DateTime.cast
  end

  def load(:boolean, "true"), do: {:ok, true}
  def load(:boolean, "false"), do: {:ok, false}

  def load(:integer, value), do: {:ok, String.to_integer(value)}
  def load(:id, value), do: {:ok, String.to_integer(value)}
  def load(:float, value), do: {:ok, String.to_float(value)}
  def load(_type, value) do
    {:ok, value}
  end

  def dump(:binary_id, value), do: dump(Ecto.UUID, value)

  # this is definitely wrong, will need work to figure our supported types
  def dump(_something, term), do: {:ok, term}

  def insert(_repo, schema_meta, fields, _autogenerate_id, _returning, _options) do
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
    |> Enum.filter(fn {_k,v} -> v && v != "" end)
    |> Enum.map(fn {k, _v} -> "#{Atom.to_string(k)}" end)
    |> Enum.join ", "
  end

  def fields_parser [item: %Ecto.Changeset{changes: fields}] do
    fields_parser fields
  end

  def fields_parser fields do
    fields
    |> Enum.filter(fn {_k,v} -> v && v != "" end)
    |> Enum.map(fn {k, v} -> "#{Atom.to_string(k)} : '#{v}'" end)
    |> Enum.join(", ")
  end

  def config, do: Application.get_env(:neo4j_sips, Neo4j)

  @doc false
  def config(key), do: Dict.get(config, key)

  @doc false
  def config(key, default), do: Dict.get(config, key, default)
end
