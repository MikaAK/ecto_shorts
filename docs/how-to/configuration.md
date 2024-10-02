# How to Configure ecto_shorts

This guide shows you how to configure ecto_shorts for your specific needs, including setting up repositories, replicas, and other options.

## Basic Configuration

### Setting Up Your Repo

ecto_shorts works with your existing Ecto repositories. By default, it will use the repo configured in your application. You can specify a different repo for each operation:

```elixir
# In your application
alias EctoShorts.Actions
alias MyApp.{Repo, User}

# Use the default repo
{:ok, user} = Actions.get(User, 1)

# Specify a custom repo
{:ok, user} = Actions.get(User, 1, repo: MyApp.CustomRepo)
```

### Setting Default Options

To avoid repeating the same options in every call, you can set up a module with default options:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}

  @actions_opts [repo: Repo]

  def get_user(id, opts \\ []) do
    opts = Keyword.merge(@actions_opts, opts)
    Actions.get(User, id, opts)
  end

  def list_users(filters \\ %{}, opts \\ []) do
    opts = Keyword.merge(@actions_opts, opts)
    Actions.all(User, filters, opts)
  end
end
```

## Advanced Configuration

### Using Read Replicas

If you have a read replica set up, you can configure ecto_shorts to use it for read operations:

```elixir
# In your application
alias EctoShorts.Actions
alias MyApp.{Repo, ReplicaRepo, User}

# Use the primary repo for writes
{:ok, user} = Actions.create(User, %{name: "John"}, repo: Repo)

# Use the replica for reads
{:ok, user} = Actions.get(User, 1, replica: ReplicaRepo)
users = Actions.all(User, %{}, replica: ReplicaRepo)
```

You can also set up default options that include the replica:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, ReplicaRepo, User}

  @write_opts [repo: Repo]
  @read_opts [repo: Repo, replica: ReplicaRepo]

  def create_user(attrs, opts \\ []) do
    opts = Keyword.merge(@write_opts, opts)
    Actions.create(User, attrs, opts)
  end

  def get_user(id, opts \\ []) do
    opts = Keyword.merge(@read_opts, opts)
    Actions.get(User, id, opts)
  end

  def list_users(filters \\ %{}, opts \\ []) do
    opts = Keyword.merge(@read_opts, opts)
    Actions.all(User, filters, opts)
  end
end
```

### Configuring Changeset Functions

You can configure which changeset function to use for create and update operations:

```elixir
# Use a custom changeset function for create
{:ok, user} = Actions.create(User, attrs, changeset_fun: :sign_up_changeset)

# Use a custom changeset function for update
{:ok, user} = Actions.update(User, id, attrs, changeset_fun: :profile_update_changeset)
```

In your schema, you would define these functions:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name, :email])
  end

  def sign_up_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password])
    |> validate_required([:name, :email, :password])
    |> validate_length(:password, min: 8)
    |> hash_password()
  end

  def profile_update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :bio])
    |> validate_required([:name])
  end

  defp hash_password(changeset) do
    case changeset do
      %{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end
```

### Configuring Default Preloads

You can set up default preloads for your context functions:

```elixir
defmodule MyApp.Blog do
  alias EctoShorts.Actions
  alias MyApp.{Repo, Post}

  @actions_opts [repo: Repo]

  def get_post(id, preloads \\ [:user, :comments]) do
    Actions.get(Post, id, [preload: preloads] ++ @actions_opts)
  end

  def list_posts(filters \\ %{}, preloads \\ [:user]) do
    filters = Map.put(filters, :preload, preloads)
    Actions.all(Post, filters, @actions_opts)
  end
end
```

## Configuration for Specific Use Cases

### Multi-Tenant Applications

For multi-tenant applications, you can configure ecto_shorts to use different repos or schemas based on the tenant:

```elixir
defmodule MyApp.MultiTenant do
  alias EctoShorts.Actions

  def get_tenant_repo(tenant_id) do
    # Logic to get the appropriate repo for the tenant
    String.to_existing_atom("Elixir.MyApp.Repo.Tenant#{tenant_id}")
  end

  def get_for_tenant(schema, id, tenant_id, opts \\ []) do
    repo = get_tenant_repo(tenant_id)
    opts = Keyword.put(opts, :repo, repo)
    Actions.get(schema, id, opts)
  end

  def list_for_tenant(schema, filters \\ %{}, tenant_id, opts \\ []) do
    repo = get_tenant_repo(tenant_id)
    opts = Keyword.put(opts, :repo, repo)
    Actions.all(schema, filters, opts)
  end
end
```

### Read-Heavy Applications

For read-heavy applications, you can configure ecto_shorts to use caching:

```elixir
defmodule MyApp.CachedAccounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User, Cache}

  @actions_opts [repo: Repo]

  def get_user(id, opts \\ []) do
    cache_key = "user:#{id}"
    
    case Cache.get(cache_key) do
      nil ->
        opts = Keyword.merge(@actions_opts, opts)
        case Actions.get(User, id, opts) do
          {:ok, user} ->
            Cache.put(cache_key, user, ttl: 3600)
            {:ok, user}
          error -> error
        end
      user -> {:ok, user}
    end
  end
end
```

### Write-Heavy Applications

For write-heavy applications, you can configure ecto_shorts to use bulk operations:

```elixir
defmodule MyApp.BulkOperations do
  alias MyApp.Repo
  alias EctoShorts.CommonChanges

  def bulk_create(schema, attrs_list) do
    Repo.transaction(fn ->
      Enum.map(attrs_list, fn attrs ->
        schema.__struct__
        |> schema.changeset(attrs)
        |> Repo.insert!()
      end)
    end)
  end

  def bulk_update(schema, ids, attrs) do
    Repo.transaction(fn ->
      Enum.map(ids, fn id ->
        schema
        |> Repo.get!(id)
        |> schema.changeset(attrs)
        |> Repo.update!()
      end)
    end)
  end
end
```

## Best Practices

1. **Centralize configuration**: Create context modules that encapsulate your ecto_shorts configuration.

2. **Use environment-specific configuration**: Configure different repos or options based on the environment (dev, test, prod).

3. **Document your configuration**: Make sure to document your configuration choices for other developers.

4. **Test your configuration**: Write tests to ensure your configuration works as expected.

5. **Monitor performance**: Keep an eye on the performance of your database operations and adjust your configuration as needed.

## Conclusion

ecto_shorts is highly configurable and can be adapted to a wide range of use cases. By setting up appropriate defaults, using read replicas, and customizing changeset functions, you can optimize ecto_shorts for your specific needs.

For more information on available options, see the module documentation for the various ecto_shorts modules.
