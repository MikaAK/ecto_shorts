defmodule EctoShorts.DynamicBuilders.Postgres.ContractTest do
  @moduledoc """
  Postgres's satisfaction of the shared `EctoShorts.FilterContract`.

  Walks the adapter-agnostic case list and asserts the Postgres adapter produces a
  valid `Ecto.Query` for each. A future NoSQL adapter gets its own contract file that
  walks the same list and asserts against its own output shape.
  """
  use ExUnit.Case, async: true
  @moduletag adapter: :postgres

  alias EctoShorts.CommonFilters
  alias EctoShorts.FilterContract
  alias EctoShorts.Schema.Post

  for %{name: name, params: params} <- FilterContract.cases() do
    @params params
    test "postgres satisfies contract: #{name}" do
      assert %Ecto.Query{} = CommonFilters.convert_params_to_filter(Post, @params, [])
    end
  end
end
