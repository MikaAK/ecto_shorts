# How to Configure EctoShorts

This guide explains how to configure EctoShorts for your specific needs, including setting up repositories, read replicas, error handling, and other options.

## Basic Configuration

### Setting Up Your Repository

EctoShorts works with your existing Ecto repositories. You can configure a default repository in your application configuration:

```elixir
# In config/config.exs (or the appropriate environment config file)
config :ecto_shorts,
  repo: MyApp.Repo,
  error_module: MyApp.CustomErrorModule # Optional custom error handler
```

You can also specify a different repository for individual operations:

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

To avoid repeating the same options in every call, you can set up a context module with default options:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}

  # Define default options once
  @actions_opts [repo: Repo]

  def get_user(id, opts \\ []) do
    # Merge default options with function-specific options
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

EctoShorts supports read replicas for distributing database load. You can configure a default replica in your application configuration:

```elixir
# In config/config.exs
config :ecto_shorts,
  repo: MyApp.Repo,
  replica: MyApp.ReplicaRepo
```

Or specify a replica for individual operations:

```elixir
# In your application
alias EctoShorts.Actions
alias MyApp.{Repo, ReplicaRepo, User}

# Use the replica for reads
{:ok, user} = Actions.get(User, 1, replica: ReplicaRepo)
users = Actions.all(User, %{}, replica: ReplicaRepo)
```

You can also set up default options that include the replica in your context modules:

```elixir
defmodule MyApp.Accounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, ReplicaRepo, User}

  # Different options for write and read operations
  @write_opts [repo: Repo]
  @read_opts [repo: Repo, replica: ReplicaRepo]

  def create_user(params, opts \\ []) do
    opts = Keyword.merge(@write_opts, opts)
    Actions.create(User, params, opts)
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

When both `:repo` and `:replica` options are provided, EctoShorts will use the replica for read operations.

### Configuring Changeset Functions

EctoShorts allows you to specify custom changeset functions for create and update operations using the `:changeset` option:

```elixir
# Use a custom changeset function for create
{:ok, user} = Actions.create(User, attrs, changeset: &User.sign_up_changeset/2)

# Or use the function name as an atom (deprecated, but still supported)
{:ok, user} = Actions.create(User, attrs, changeset_fun: :sign_up_changeset)

# Use a custom changeset function for update
{:ok, user} = Actions.update(User, id, attrs, changeset: &User.profile_update_changeset/2)
```

In your schema, you would define these specialized changeset functions:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :password, :string, virtual: true
    field :password_hash, :string
    field :bio, :string

    timestamps()
  end

  # Default changeset
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email])
    |> validate_required([:name])
  end

  # Specialized changeset for user registration
  def sign_up_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :password])
    |> validate_required([:name, :email, :password])
    |> validate_format(:email, ~r/@/)
    |> validate_length(:password, min: 8)
    |> put_password_hash()
  end

  # Specialized changeset for profile updates
  def profile_update_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :bio])
    |> validate_required([:name])
  end

  defp put_password_hash(changeset) do
    case changeset do
      %{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end
end
```

You can also pass a one-arity function that receives and returns a changeset:

```elixir
# Using an anonymous function to modify the changeset
{:ok, user} = Actions.create(User, attrs, changeset: fn changeset ->
  changeset
  |> validate_length(:password, min: 12)
  |> validate_format(:email, ~r/@company\.com$/)
end)
```

### Configuring Default Preloads

EctoShorts provides two ways to specify preloads:

1. As an option in the function call
2. As part of the filter parameters

Here's how to set up default preloads for your context functions:

```elixir
defmodule MyApp.Blog do
  alias EctoShorts.Actions
  alias MyApp.{Repo, Post}

  @actions_opts [repo: Repo]

  # Method 1: Using the preload option
  def get_post(id, preloads \\ [:user, :comments]) do
    Actions.get(Post, id, [preload: preloads] ++ @actions_opts)
  end

  # Method 2: Including preloads in the filter parameters
  def list_posts(filters \\ %{}, preloads \\ [:user]) do
    filters = Map.put(filters, :preload, preloads)
    Actions.all(Post, filters, @actions_opts)
  end
  
  # Allow overriding preloads with function parameters
  def get_post_with_options(id, preloads \\ [], opts \\ []) do
    opts = Keyword.merge(@actions_opts, opts)
    opts = Keyword.put(opts, :preload, preloads)
    Actions.get(Post, id, opts)
  end
end
```

Preloads can be specified as a list of associations, a nested map for deeper preloads, or a keyword list with options:
```

## Configuration for Specific Use Cases

### Multi-Tenant Applications

EctoShorts can be configured for multi-tenant applications in several ways:

#### Approach 1: Separate Repos per Tenant

```elixir
defmodule MyApp.MultiTenant do
  alias EctoShorts.Actions

  def get_tenant_repo(tenant_id) do
    # Logic to get the appropriate repo for the tenant
    # This could use a registry or dynamic module naming
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

#### Approach 2: Using Postgres Schemas with the prefix option

```elixir
defmodule MyApp.MultiTenant do
  alias EctoShorts.Actions
  alias MyApp.Repo

  @actions_opts [repo: Repo]
  
  def get_tenant_prefix(tenant_id) do
    "tenant_#{tenant_id}"
  end

  def get_for_tenant(schema, id, tenant_id, opts \\ []) do
    prefix = get_tenant_prefix(tenant_id)
    opts = Keyword.merge(@actions_opts, [prefix: prefix] ++ opts)
    Actions.get(schema, id, opts)
  end

  def list_for_tenant(schema, filters \\ %{}, tenant_id, opts \\ []) do
    prefix = get_tenant_prefix(tenant_id)
    opts = Keyword.merge(@actions_opts, [prefix: prefix] ++ opts)
    Actions.all(schema, filters, opts)
  end
end
```

#### Approach 3: Using a tenant_id field in your schemas

```elixir
defmodule MyApp.MultiTenant do
  alias EctoShorts.Actions
  alias MyApp.Repo

  @actions_opts [repo: Repo]
  
  def get_for_tenant(schema, id, tenant_id, opts \\ []) do
    filters = %{id: id, tenant_id: tenant_id}
    Actions.find(schema, filters, Keyword.merge(@actions_opts, opts))
  end

  def list_for_tenant(schema, filters \\ %{}, tenant_id, opts \\ []) do
    filters = Map.put(filters, :tenant_id, tenant_id)
    Actions.all(schema, filters, Keyword.merge(@actions_opts, opts))
  end
end
```
```

### Read-Heavy Applications

For read-heavy applications, you can combine EctoShorts with caching strategies:

#### Using an In-Memory Cache

```elixir
defmodule MyApp.CachedAccounts do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User, Cache}

  @actions_opts [repo: Repo]
  @cache_ttl 3600 # Cache TTL in seconds

  def get_user(id, opts \\ []) do
    cache_key = "user:#{id}"
    
    case Cache.get(cache_key) do
      nil ->
        # Cache miss - fetch from database
        opts = Keyword.merge(@actions_opts, opts)
        case Actions.get(User, id, opts) do
          {:ok, user} ->
            # Store in cache for future requests
            Cache.put(cache_key, user, ttl: @cache_ttl)
            {:ok, user}
          error -> error
        end
      user -> {:ok, user} # Cache hit
    end
  end
  
  # Invalidate cache when data changes
  def update_user(id, attrs, opts \\ []) do
    opts = Keyword.merge(@actions_opts, opts)
    case Actions.update(User, id, attrs, opts) do
      {:ok, user} = result ->
        Cache.delete("user:#{id}")
        result
      error -> error
    end
  end
end
```

#### Using Read Replicas for Read-Heavy Operations

Combine read replicas with your caching strategy for high-load applications:

```elixir
defmodule MyApp.ScalableRepo do
  alias EctoShorts.Actions
  alias MyApp.{Repo, ReplicaRepo, Cache, User}

  @write_opts [repo: Repo]
  @read_opts [repo: Repo, replica: ReplicaRepo]
  @cache_ttl 3600
  
  # Read operations use replica and caching
  def get_user(id, opts \\ []) do
    cache_key = "user:#{id}"
    
    case Cache.get(cache_key) do
      nil ->
        opts = Keyword.merge(@read_opts, opts)
        case Actions.get(User, id, opts) do
          {:ok, user} = result ->
            Cache.put(cache_key, user, ttl: @cache_ttl)
            result
          error -> error
        end
      user -> {:ok, user}
    end
  end
  
  # Write operations use primary and invalidate cache
  def update_user(id, attrs, opts \\ []) do
    opts = Keyword.merge(@write_opts, opts)
    case Actions.update(User, id, attrs, opts) do
      {:ok, user} = result ->
        Cache.delete("user:#{id}")
        result
      error -> error
    end
  end
end
```
```

### Write-Heavy Applications

For write-heavy applications, EctoShorts provides built-in functions for bulk operations:

```elixir
defmodule MyApp.BulkOperations do
  alias EctoShorts.Actions
  alias MyApp.{Repo, User}
  
  @actions_opts [repo: Repo]
  
  # Create multiple records in a single transaction
  def bulk_create_users(attrs_list, opts \\ []) do
    opts = Keyword.merge(@actions_opts, opts)
    Actions.create_many(User, attrs_list, opts)
  end
  
  # Find or create multiple records
  def find_or_create_users(attrs_list, opts \\ []) do
    opts = Keyword.merge(@actions_opts, opts)
    Actions.find_or_create_many(User, attrs_list, opts)
  end
  
  # Custom bulk operations with transactions
  def bulk_update_with_custom_logic(schema, ids, attrs) do
    Repo.transaction(fn ->
      Enum.map(ids, fn id ->
        schema
        |> Repo.get!(id)
        |> schema.changeset(attrs)
        |> Repo.update!()
      end)
    end)
  end
  
  # Batch processing for very large datasets
  def process_in_batches(schema, filter, batch_size \\ 500, opts \\ [], fun) do
    opts = Keyword.merge(@actions_opts, opts)
    
    stream_fun = fn ->  
      schema
      |> EctoShorts.CommonFilters.convert_params_to_filter(filter)
      |> Repo.stream(max_rows: batch_size)
      |> Stream.chunk_every(batch_size)
      |> Stream.each(fun)
      |> Stream.run()
    end
    
    Repo.transaction(stream_fun, timeout: :infinity)
  end
end
```

For high-volume write operations, consider:

1. Using `Ecto.Multi` for transaction-based operations
2. Implementing batch processing for large datasets
3. Using background job processors like Oban for non-critical writes
4. Setting appropriate timeouts for long-running operations
```

## Best Practices

### Organization

1. **Centralize configuration**: Create context modules that encapsulate your EctoShorts configuration to avoid repetition and ensure consistency.

   ```elixir
   defmodule MyApp.Repo.Config do
     def default_options do
       [repo: MyApp.Repo]
     end
     
     def read_options do
       Keyword.merge(default_options(), replica: MyApp.ReplicaRepo)
     end
   end
   ```

2. **Use environment-specific configuration**: Configure different repos or options based on the environment.

   ```elixir
   # config/dev.exs
   config :ecto_shorts,
     repo: MyApp.Repo
     
   # config/prod.exs
   config :ecto_shorts,
     repo: MyApp.Repo,
     replica: MyApp.ReplicaRepo
   ```

### Performance

3. **Use read replicas for read-heavy operations**: Distribute database load by configuring read replicas for read-only operations.

4. **Implement caching strategies**: For frequently accessed data, implement appropriate caching with invalidation.

5. **Use batch operations**: For bulk operations, use the built-in batch functions or implement custom batching with transactions.

### Development Practices

6. **Document your configuration**: Make sure to document your configuration choices for other developers.

7. **Test your configuration**: Write tests to ensure your configuration works as expected.

   ```elixir
   # In your test files
   test "uses the correct repo for reads" do
     # Setup test data
     assert {:ok, result} = YourContext.get_record(id)
     # Verify correct repo was used
   end
   ```

8. **Monitor performance**: Keep an eye on the performance of your database operations and adjust your configuration as needed.

## Error Handling

EctoShorts provides a consistent error handling mechanism that you can customize:

```elixir
# Configure a custom error module
config :ecto_shorts,
  error_module: MyApp.CustomErrorHandler

# Implement the error handler
defmodule MyApp.CustomErrorHandler do
  @behaviour EctoShorts.Actions.Error
  
  @impl true
  def create_error(:not_found, message, details) do
    # Custom error handling for not found errors
    %{status: 404, message: message, details: details}
  end
  
  def create_error(code, message, details) do
    # Default error handling
    %{code: code, message: message, details: details}
  end
end
```

## Conclusion

EctoShorts is highly configurable and can be adapted to a wide range of use cases. By setting up appropriate defaults, using read replicas, and customizing error handling and changeset functions, you can optimize EctoShorts for your specific needs.

For more information on available options, see the [module documentation](https://hexdocs.pm/ecto_shorts/EctoShorts.html) for the various EctoShorts modules.
