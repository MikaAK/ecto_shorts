defmodule EctoShorts do
  @moduledoc """
  EctoShorts is a data-driven query and CRUD API for Elixir applications built on Ecto.
  Instead of writing query boilerplate, you pass plain maps of parameters and get back
  Ecto queries or fully-loaded records — filtering, pagination, ordering, associations,
  bulk operations, and changeset helpers are all driven by the same map-based interface.

  ## Installation

  Add `ecto_shorts` to your dependencies in `mix.exs`:

      def deps do
        [
          {:ecto_shorts, "~> 3.0"}
        ]
      end

  ## Configuration

  At minimum, tell EctoShorts which Ecto repo to use:

      # config/config.exs
      config :ecto_shorts,
        repo: MyApp.Repo,
        replica: MyApp.Repo

  `replica` defaults to `repo` when omitted.  Set it to a read-replica repo to
  route all read operations there automatically.

  ## First Example

  Fetch all users aged 18 or older:

      iex> EctoShorts.Actions.all(User, %{age: %{gte: 18}})
      [%User{id: 1, age: 22, ...}, %User{id: 4, age: 34, ...}]

  The return value is a plain list of structs — the same as calling
  `MyApp.Repo.all(query)` after building the query by hand.

  ## Where to go next

  - [Getting Started](getting-started.md) — step-by-step tutorial from install to first query
  - `EctoShorts.Actions` — the primary read/write API (`all`, `create`, `update`, `delete`, and more)
  - `EctoShorts.CommonFilters` — the filter-parameter language and query builder
  - `EctoShorts.CommonChanges` — changeset helpers for associations and common field transforms
  - `EctoShorts.CommonParams` — parameter helpers for bulk insert and upsert operations
  """
end
