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
    cypher = build_cypher(query, params)
    IO.puts "***********************************************************"
    IO.inspect cypher
    {:ok, return} = Neo4j.query(Neo4j.conn, cypher)
    {return_count(return), sorted_return(return, query)}
  end

  def return_count([%{"count" => n}]), do: n

  def return_count(return) do
    Enum.count(return)
  end

  def sorted_return(_col, {_, %Ecto.Query{select: nil}}), do: [nil]

  def sorted_return([], _), do: []

  def sorted_return(return, query) do
    r = return |> Enum.map(fn column -> sort_column(column, query) end)
    [r]
  end

  def sort_column(%{"n" => node}, query) do
    sort_column(node, query)
  end

  def sort_column(node, query ={ _type, %Ecto.Query{sources: {{node_type_name, source}}}}) do
    cols = result_columns(query)
    IO.puts "************************************** cols"
    IO.inspect cols
    coercer = fn({name, type}) -> {name, coerce(type, node[Atom.to_string(name)])} end
    coerced = cols |> Enum.map(coercer)
    struct(source, coerced) |> Map.merge(%{__meta__: %Ecto.Schema.Metadata{state: :loaded, source: {nil, node_type_name}}})
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

  # when select isn't empty, but doesn't specify result columns, we want all of them by default. Don't look at me,
  # I didn't specify this default
  def result_columns({_type, query = %Ecto.Query{select: %Ecto.Query.SelectExpr{fields: [{:&, [], [0]}]}, sources: {{_node_type_name, source}}} }) do
    source.__schema__(:types)
  end

  def result_columns({_type, query}) do
    query.select.fields |> Enum.map(fn expr -> extract_column_with_type(expr) end)
  end

  def extract_column_with_type([{{:., [], [{:&, [], [0]}, column_name]}, [ecto_type: type], []}]) do
    {column_name, type}
  end

  def extract_column_with_type(expr) when expr != nil do
    {{_,_,[_head|columns]},type,_} = expr
    {hd(columns), type[:ecto_type]}
  end

  def extract_column_with_type(expr), do: expr

  def build_cypher({:all, query_obj}, params) do
    str_wheres = wheres_parse(query_obj.wheres, params)
    "MATCH (n:#{from_string(query_obj.from)}) #{str_wheres} RETURN n"
  end

  def build_cypher({:update_all, query_obj}, params) do
    str_wheres = where_parse(query_obj.wheres)
    str_set = set_parse(query_obj, params)
    "MATCH (n:#{from_string(query_obj.from)}) #{str_wheres} #{str_set} RETURN count(*) as count"
  end

  def build_cypher({:delete_all, query_obj}, params) do
    "MATCH (n:#{from_string(query_obj.from)}) DELETE n"
  end

  def delete(repo, %{source: {_, node_type}}, filters, autogenerate_id, options) do
    filter = filters
      |> Enum.map(fn {k,v} -> "#{k}: '#{v}'" end)
      |> Enum.join(", ")
    cypher = "MATCH (n:#{node_type} {#{filter}}) DELETE n"
    Neo4j.query(Neo4j.conn, cypher)
  end

  def from_string({x, _}) do
    x
  end

  def from_string(x), do: x

  def build_cypher({type, _query}, _params) do
    IO.puts "***********************************************************************************************************"
    IO.puts "IMPLEMENT #{type} CYPHER BUILDER"
  end

  # where parsing for update queries
  def wheres_parse(wheres) do
    all = wheres
      |> Enum.map(fn w -> where_parse(w) end)
      |> Enum.join(" AND ")
    "WHERE #{all}"
  end

  def wheres_parse([]) do
    ""
  end

  # where parsing for :all queries
  def wheres_parse([], params) do
    ""
  end

  def wheres_parse(wheres, params) do
    all = wheres
      |> Enum.map(fn w -> where_parse(w, params) end)
      |> Enum.join(" AND ")
    "WHERE #{all}"
  end

  # Ecto.Neo4j.wh(%Ecto.Query.QueryExpr{expr: {:==, [], [ { {:., [], [{:&, [], [0]}, :uuids]},       [ecto_type: {:array, Ecto.UUID}], []}, {:^, [], [0]}]}, params: nil}, [[]])
  def where_parse(%Ecto.Query.QueryExpr{expr: {:==, [], [{{:., [], [{:&, [], [0]}, column_name]}, [ecto_type: {:array, Ecto.UUID}], []}, {:^, [], [0]}]}}, [params]) do
    formatted_params = params |> Enum.map(fn term -> "'#{term}'" end) |> Enum.join(",")
    "n.#{column_name} IN [#{formatted_params}]"
  end

  def where_parse(%Ecto.Query.QueryExpr{expr: {:==, [], [{{:., [], [{:&, [], [0]}, :id]}, [ecto_type: :binary_id], []}, {:^, [], [params_index]}]}}, params) do
    "n.uuid = '#{params}'"
  end
  # %Ecto.Query.QueryExpr{expr: {:in, [], [{{:., [], [{:&, [], [0]}, :post_id]}, [ecto_type: :binary_id], []}, {:^, [], [0, 1]}]}
  def where_parse(%Ecto.Query.QueryExpr{expr: {:in, [], [{{:., [], [{:&, [], [0]}, column_name]}, [ecto_type: :binary_id], []}, {:^, [], [params_index]}]}}, params) do
    "n.#{column_name} = '#{params}'"
  end

  def where_parse(%Ecto.Query.QueryExpr{expr: {:in, [], [{{_, _, [_, column_name]}, [ecto_type: :binary_id], []}, {:^, [], _}]}}, params) do
    # n.property IN [{value1}, {value2}]
    formatted_params = params |> Enum.map(fn term -> "'#{term}'" end) |> Enum.join(",")
    "n.#{column_name} IN [#{formatted_params}]"
  end

  def where_parse(%Ecto.Query.QueryExpr{expr: {:or,_,criteria} }) do
    criteria |> Enum.map(fn c -> criterium_string(c) end) |> Enum.join(" OR ")
  end

  # {:==, [], [{{:., [], [{:&, [], [0]}, :title]}, [ecto_type: :string], []}, "2"]}
  def criterium_string({:==, [], [{{:., [], [{:&, [], [0]}, column_name]}, [ecto_type: :string], []}, match]}) do
    "n.#{column_name} = '#{match}'"
  end

  def set_parse(%Ecto.Query{updates: updates}, params) do
    update_items = updates
     |> Enum.map(fn update -> update_strings(update, params) end)
     "SET #{update_items |> Enum.join(", ")}"
  end

  def update_strings(%Ecto.Query.QueryExpr{expr: [set: fields]}, params) do
    fields |> Enum.map(fn({k,v}) -> update_string(List.to_tuple(params), k, v) end)
  end

  def update_string(params, field_name, index) do
    item_index = List.last(elem(index,2))
    "n.#{field_name} = '#{elem(params, item_index)}'"
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


  def load(_, nil), do: {:ok, nil}
  def load(:boolean, "true"), do: {:ok, true}
  def load(:boolean, "false"), do: {:ok, false}

  def load(:integer, value), do: {:ok, String.to_integer(value)}
  def load(:id, value), do: {:ok, String.to_integer(value)}
  def load(:float, value), do: {:ok, String.to_float(value)}
  def load({:array, Ecto.UUID}, value) do
    {:ok, [value]}
  end

  def load(type, value) do
    IO.puts "**************************** Default load, may be inaccurate ******************************  "
    IO.inspect type
    IO.inspect value
    {:ok, value}
  end

  def dump(:binary_id, value), do: dump(Ecto.UUID, value)

  # this is definitely wrong, will need work to figure our supported types
  def dump(_something, term), do: {:ok, term}

  def insert(_repo, schema_meta = %{source: {_, table}}, fields, _autogenerate_id, _returning, _options) do
    fields_auto_id = [{id_col(schema_meta), fields[:uuid]}] ++ fields
    cypher = "CREATE (n:#{table} {#{fields_parser(fields_auto_id)}}) RETURN #{return_fields(fields_auto_id)}"
    {:ok, [result] } = Neo4j.query(Neo4j.conn, cypher)
    {:ok, remap_insert_return(result)}
  end

  def remap_insert_return(result) do
    result
      |> Enum.map(fn {key,value} -> {String.to_atom(key), value}  end)
      |> Enum.into(%{})
  end

  def id_col(meta) do
    {id_column, _type} = meta.model.__schema__(:autogenerate_id)
    id_column
  end

  def return_fields fields do
    fields
    |> Enum.filter(fn {_k,v} -> v && v != "" end)
    |> Enum.map(fn {k, _v} -> "n.#{k} as #{k}" end)
    |> Enum.join(", ")
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
