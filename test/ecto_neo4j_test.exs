defmodule Ecto.Neo4jTest do
  use ExUnit.Case

  use Ecto.Integration.Case

  alias Ecto.Integration.TestRepo
  alias Ecto.Integration.Post
  alias Ecto.Integration.Tag
  alias Ecto.Integration.Order
  alias Ecto.Integration.Item
  
  doctest Ecto.Neo4j

  test "the truth" do
    assert 1 + 1 == 2
  end

  test "delete" do

  end

  # autogenerate_id()
  # constraints()
  # fields()
  # filters()
  # model_meta()
  # prepared()
  # preprocess()
  # query_meta()
  # returning()
  # t()
  # __before_compile__(arg0)
  # The callback invoked in case the adapter needs to inject code
  # delete(repo, model_meta, filters, autogenerate_id, options)
  # Deletes a sigle model with the given filters
  # dump(arg0, term)
  # Called for every known Ecto type when dumping data to the adapter
  # embed_id(arg0)
  # Called every time an id is needed for an embedded model
  # execute(repo, query_meta, prepared, params, |, options)
  # Executes a previously prepared query
  # insert(repo, model_meta, fields, autogenerate_id, returning, options)
  # Inserts a single new model in the data store
  # load(arg0, term)
  # Called for every known Ecto type when loading data from the adapter
  # prepare(|, query)
  # Commands invoked to prepare a query for all, update_all and delete_all
  # start_link(repo, options)
  # Starts any connection pooling or supervision and return {:ok, pid}
  # stop(pid, timeout)
  # Shuts down the repository represented by the given pid
  # update(repo, model_meta, fields, filters, autogenerate_id, returning, options)
  # Updates a single model with the given filters

end
