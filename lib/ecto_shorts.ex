defmodule EctoShorts do
  @moduledoc """
  Ecto Shorts is a library created to help shorten ecto
  interactions and remove most of the related code.

  EctoShorts is split into 3 main components:

    * `EctoShorts.Actions` - Actions are wrappers around
    `Ecto.Repo` function calls. With actions, we can create,
    find, update, and delete records. Actions handle the
    internal specifics of the Ecto API (e.g. `Ecto.Changeset`)
    functions, so you don't have to.

    * `EctoShorts.CommonChanges` - CommonChanges is suited for
    interactions with the `Ecto.Changeset` API and provides
    helper functions that make managing your schemas easier.

    * `EctoShorts.CommonFilters` - CommonFilters allows you to
    build Ecto queries with parameters. In other words, you
    can turn data into a query without having to write one.

  ## EctoShorts.Actions

  `EctoShorts.Actions` allows you to use the `Ecto.Repo` api
  without having the do any of the pre-requisite setup as it
  covers the entire lifecycle of the operation.

  For example, the following function:

  ```elixir
  Actions.all(EctoShorts.Support.Schemas.Post, %{
    title: %{ilike: "blog post"},
    body: "body",
    likes: %{gte: 0, lte: 50},
    preload: [:comments],
    last: 5
  })
  ```

  is equivalent to

  ```elixir
  query =
    from p in EctoShorts.Support.Schemas.Post,
      preload: [:comments],
      limit: 5,
      where: p.body == "body" and
      p.likes >= 0 and p.likes <= 50 and
      ilike(p.title, "%blog post%")

  EctoShorts.Support.Repo.all(query)
  ```

  which composes the `Ecto.Query` and `Ecto.Repo` api. This also
  extends to the  `Ecto.Changeset` api. The following function

  ```elixir
  Actions.create(EctoShorts.Support.Schemas.Post, %{
    title: "blog post",
    body: "body",
    likes: 10,
    comments: [%{id: 1}]
  })
  ```

  is equivalent to

  ```elixir
  EctoShorts.Support.Schemas.Post
  |> struct()
  |> EctoShorts.Support.Schemas.Post.changeset(%{
    title: "blog post",
    body: "body",
    likes: 10,
    comments: [%{id: 1}]
  })
  |> Ecto.Changeset.cast_assoc(:comments)
  |> EctoShorts.Support.Repo.insert()
  ```

  All actions can accept an optional argument of a keyword list
  that can be used to configure which Repo the action should use.

  ## Options

    * `:replica` - A module that uses Ecto.Repo. If you don't
    want to perform any reads against your primary, you can
    specify a replica to read from. This option takes
    precedence over the :repo option and will be used if set.

    * `:repo` - A module that uses Ecto.Repo. This is
    commonly your primary repository.

  ## EctoShorts.CommonFilters

  CommonFilters allows you build queries from data instead of
  writing your own queries. For example, where you would
  write the following query:

  ```elixir
  query =
    from c in EctoShorts.Support.Schemas.Post,
      where: c.id == 1

  EctoShorts.Support.Repo.one(query)
  ```

  you can write it as

  ```elixir
  EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Support.Schemas.Post, %{id: 1})
  ```

  This api also works with associations

  ```elixir
  EctoShorts.CommonFilters.convert_params_to_filter(EctoShorts.Support.Schemas.Post, %{id: 1, comments: %{id: 1}})
  ```

  See `EctoShorts.CommonFilters` for more info on information on
  the available filters.

  ## EctoShorts.CommonChanges

  `EctoShorts.CommonChanges` is responsible for updating
  relations on schemas. It allows you to update associations
  or create using changesets and handles choosing between
  `put_assoc` and `cast_assoc`.

  ```elixir
  defmodule Organization do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    schema "organizations" do
      field :name, :string

      has_many :users, User

      timestamps()
    end

    @available_fields [
      :name
    ]

    def changeset(model_or_changeset, attrs \\ %{}) do
      model_or_changeset
      |> cast(attrs, @available_fields)
      |> EctoShorts.CommonChanges.preload_change_assoc(:users)
    end
  end

  defmodule User do
    @moduledoc false
    use Ecto.Schema
    import Ecto.Changeset

    schema "users" do
      field :email, :string

      belongs_to :organization, Organization

      timestamps()
    end

    @available_fields [
      :email,
      :organization_id
    ]

    def changeset(model_or_changeset, attrs \\ %{}) do
      model_or_changeset
      |> cast(attrs, @available_fields)
      |> EctoShorts.CommonChanges.preload_change_assoc(:organization, required_when_missing: :organization_id)
    end
  end
  ```

  You can also update many to many relationship members using a list
  of ids. For example, let's say you wanted to make the user with the
  id 1 to be friends with users that have the ids 5, 6, and 7 you
  can achieve this with `EctoShorts.Actions.update/4`:

  ```
  Actions.update(User, 1, %{friends: [%{id: 5}, %{id: 6}, %{id: 7}]})
  ```

  ## Configuration

  You can configure both the Repo and Error module via

  ```
  config :ecto_shorts,
    repo: MyRepo,
    error_module: EctoShorts.Actions.Error
  ```

  ## Abstract tables / Polymorphic associations

  In [Ecto](https://hexdocs.pm/ecto/Ecto.Schema.html#belongs_to/3-polymorphic-associations), abstract schemas allow
  defining database schemas without tying them to an actual
  database table. This lets you describe data structures
  and relationships without persisting them directly to
  a database.

  To use an abstract schema with ecto you must specify the
  `source` and `schema` for the operation in a tuple, for example:

  ```elixir
  {"comments", Comment}
  ```

  The following apis support this syntax:

    * `EctoShorts.Actions`
    * `EctoShorts.CommonFilters`
  """
end
