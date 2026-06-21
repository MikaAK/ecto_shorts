defmodule EctoShorts.FilterContract do
  @moduledoc """
  The adapter-agnostic filter behaviours every `EctoShorts.DynamicBuilder`
  implementation must satisfy.

  This module is just data: a list of filter inputs each adapter has to support.
  Each adapter owns a `contract_test.exs` that walks this list and asserts against
  its own output shape (an `Ecto.Query` for Postgres; a query document for a future
  NoSQL adapter). The case list is shared; the assertion is per-adapter.

  Add a row here when a behaviour must hold across all adapters. Keep dialect-only
  behaviour (Postgres arrays/JSONB, NoSQL-only operators) out of this list — those
  live in the adapter's own dialect test files.
  """

  @type filter_case :: %{name: String.t(), params: map()}

  @doc "The contract cases. Each is a `%{name, params}` pair."
  @spec cases() :: [filter_case()]
  def cases do
    [
      %{name: "equals scalar", params: %{id: %{==: 1}}},
      %{name: "not equals scalar", params: %{id: %{!=: 1}}},
      %{name: "greater than", params: %{views: %{gt: 18}}},
      %{name: "greater than or equal", params: %{views: %{gte: 18}}},
      %{name: "less than", params: %{views: %{lt: 18}}},
      %{name: "less than or equal", params: %{views: %{lte: 18}}},
      %{name: "in list", params: %{id: %{in: [1, 2, 3]}}},
      %{name: "not in list", params: %{id: %{nin: [1, 2, 3]}}},
      %{name: "is nil", params: %{published_at: nil}}
    ]
  end
end
