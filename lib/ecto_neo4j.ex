defmodule Ecto.Neo4j do
  @moduledoc "Provides an Ecto integration to Neo4J."
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

  def execute(repo, meta, query, params, preprocess, options) do
    IEx.pry
    IO.inspect params
    cypher = build_cypher(query, params)
    {:ok, return} = Neo4j.query(Neo4j.conn, cypher)
    sorted_return = return |> Enum.map(fn column -> sort_column(column, query) end)
    {Enum.count(return), sorted_return}
  end

  def sort_column(col, query) do
    cols = result_columns(query)
    if hd(cols) do
      coercer = fn({name, type}) -> coerce(type, col[Atom.to_string(name)]) end
      cols |> Enum.map(coercer)
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


  def build_cypher({:all, query_obj}, _params) do
    formatter      = fn column -> "n.#{column} as #{column}" end
    columns_string = query_obj |> columns |> Enum.uniq |> Enum.map(formatter)
    {from, _}      = query_obj.from
    "MATCH (n:#{from}) RETURN #{columns_string |> Enum.join(", ")}"
  end

#  query_obj wheres look like this:
#  w = query_obj.wheres
#  [%Ecto.Query.QueryExpr{expr: {:or, [],
#    [{:==, [],
#      [{{:., [], [{:&, [], [0]}, :title]}, [ecto_type: :string], []}, "1"]},
#     {:==, [],
#      [{{:., [], [{:&, [], [0]}, :title]}, [ecto_type: :string], []}, "2"]}]},
#   file: "/Users/mmills/projects/ecto_neo4j/deps/ecto/integration_test/cases/repo.exs",
#   line: 431, params: nil}]


  def build_cypher({:update_all, query_obj}, params) do
    str_wheres = where_parse(query_obj.wheres)
    str_set = set_parse(query_obj, params)
    "MATCH n:#{query_obj.from} #{str_wheres} #{str_set}"
  end

  def build_cypher({:delete_all, query_obj}, params) do
    "MATCH n:#{query_obj.from} DETACH DELETE n"
  end

  def build_cypher({type, _query} _params) do
    IO.puts "***********************************************************************************************************"
    IO.puts "IMPLEMENT #{type} CYPHER BUILDER"
  end


  def where_parse(%Ecto.Query.QueryExpr{expr: {:or,_,criteria} }) do
    criteria |> Enum.map(fn c -> criterium_string(c) end) |> Enum.join(" OR ")
  end

  def where_parse(wheres) do
    all = wheres |> Enum.map(fn w -> where_parse(w) end) |> Enum.join(" AND ")
    "WHERE #{all}"
  end

  def where_parse([]) do
    IO.puts "********************************************  WHERES nil ***********************************************"
    ""
  end
  # {:==, [], [{{:., [], [{:&, [], [0]}, :title]}, [ecto_type: :string], []}, "2"]}
  def criterium_string({:==, [], [{{:., [], [{:&, [], [0]}, column_name]}, [ecto_type: :string], []}, match]}) do
    "#{column_name} = #{match}"
  end

  def set_parse(%Ecto.Query{updates: updates}, params) do
    update_items = updates
     |> Enum.map(fn update -> update_string(update, params) end)
     "SET #{update_items |> Enum.join(", ")}"
  end

  def update_string(update, params) do
    
  end

  def columns(query) do
    query.select.fields |> Enum.map(fn expr -> extract_column(expr) end)
  end

  def supports_ddl_transaction? do
    false
  end

  def load(Ecto.DateTime, value) do
    {:ok, date} = value |> DateFormat.parse("%Y-%m-%d %H:%M:%S", :strftime)
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
    |> Enum.map(fn {k, _v} -> Atom.to_string(k) end)
    |> Enum.join(", ")
  end

  def fields_parser [item: %Ecto.Changeset{changes: fields}] do
    fields_parser fields
  end

  def fields_parser fields do
    fields
    |> Enum.filter(fn {_k,v} -> v && v != "" end)
    |> Enum.map(fn {k, v} -> "#{Atom.to_string(k)} : '#{encode_value(v)}'" end)
    |> Enum.join(", ")
  end

  def encode_value(v = %Ecto.DateTime{}), do: v

  def encode_value(v) when is_map(v) do
    Poison.encode!(v)
  end

  def encode_value(v), do: "#{v}"

  def config, do: Application.get_env(:neo4j_sips, Neo4j)

  @doc false
  def config(key), do: Dict.get(config, key)

  @doc false
  def config(key, default), do: Dict.get(config, key, default)
end
