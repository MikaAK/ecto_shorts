# Getting Started with ecto_shorts

This tutorial will guide you through setting up and using ecto_shorts in a new Elixir project. By the end, you'll understand how to use the basic features of ecto_shorts to simplify your Ecto code.

## Prerequisites

Before starting this tutorial, make sure you have:

- Elixir and Erlang installed
- Basic knowledge of Elixir syntax
- Familiarity with Ecto concepts
- A working PostgreSQL installation

## Step 1: Create a new Phoenix project

Let's start by creating a new Phoenix project:

```bash
mix phx.new ecto_shorts_demo --no-html --no-assets --no-dashboard --no-live --no-mailer
cd ecto_shorts_demo
```

## Step 2: Add ecto_shorts to your dependencies

Open your `mix.exs` file and add ecto_shorts to your dependencies:

```elixir
defp deps do
  [
    {:phoenix, "~> 1.7.0"},
    {:phoenix_ecto, "~> 4.4"},
    {:ecto_sql, "~> 3.10"},
    {:postgrex, ">= 0.0.0"},
    {:jason, "~> 1.2"},
    {:plug_cowboy, "~> 2.5"},
    
    # Add ecto_shorts
    {:ecto_shorts, "~> 2.3"}
  ]
end
```

Then install the dependencies:

```bash
mix deps.get
```

## Step 3: Configure your database

Make sure your database configuration in `config/dev.exs` is set up correctly:

```elixir
config :ecto_shorts_demo, EctoShortsDemo.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ecto_shorts_demo_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

## Step 4: Create a schema

Let's create a simple User schema:

```bash
mix phx.gen.schema User users name:string email:string age:integer
```

Now, let's modify the generated schema to work better with ecto_shorts. Open `lib/ecto_shorts_demo/user.ex` and update it:

```elixir
defmodule EctoShortsDemo.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :age, :integer

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> validate_number(:age, greater_than_or_equal_to: 18)
  end

  # Add this function for ecto_shorts Actions to use
  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
```

## Step 5: Run migrations

```bash
mix ecto.create
mix ecto.migrate
```

## Step 6: Create a context module using ecto_shorts

Now let's create a context module that uses ecto_shorts to simplify our database operations.

Create a new file at `lib/ecto_shorts_demo/accounts.ex`:

```elixir
defmodule EctoShortsDemo.Accounts do
  alias EctoShortsDemo.{Repo, User}
  alias EctoShorts.Actions

  # Set the default repo for Actions to use
  @actions_opts [repo: Repo]

  # Create a new user
  def create_user(attrs) do
    Actions.create(User, attrs, @actions_opts)
  end

  # Get a user by ID
  def get_user(id) do
    Actions.get(User, id, @actions_opts)
  end

  # Get a user by email
  def get_user_by_email(email) do
    Actions.get_by(User, %{email: email}, @actions_opts)
  end

  # List all users
  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @actions_opts)
  end

  # Update a user
  def update_user(id, attrs) do
    Actions.update(User, id, attrs, @actions_opts)
  end

  # Delete a user
  def delete_user(id) do
    Actions.delete(User, id, @actions_opts)
  end
end
```

## Step 7: Try it out in IEx

Let's try using our new module in the Elixir interactive shell:

```bash
iex -S mix
```

```elixir
# Create a user
{:ok, user} = EctoShortsDemo.Accounts.create_user(%{name: "John Doe", email: "john@example.com", age: 30})

# Get a user by ID
EctoShortsDemo.Accounts.get_user(user.id)

# Get a user by email
EctoShortsDemo.Accounts.get_user_by_email("john@example.com")

# List users with filters
EctoShortsDemo.Accounts.list_users(%{age: %{gte: 25}})

# Update a user
EctoShortsDemo.Accounts.update_user(user.id, %{name: "John Smith"})

# Delete a user
EctoShortsDemo.Accounts.delete_user(user.id)
```

## Step 8: Using CommonFilters

One of the most powerful features of ecto_shorts is CommonFilters, which allows you to convert parameter maps into Ecto queries:

```elixir
# List users with age between 20 and 40
EctoShortsDemo.Accounts.list_users(%{
  age: %{gte: 20, lte: 40}
})

# Search for users with a name containing "John"
EctoShortsDemo.Accounts.list_users(%{
  name: %{ilike: "John"}
})

# Get the first 5 users ordered by ID
EctoShortsDemo.Accounts.list_users(%{
  first: 5
})
```

## Conclusion

You've now set up a basic Phoenix application with ecto_shorts and learned how to use its core features to simplify your database operations. This is just the beginning - ecto_shorts offers many more features to help you write cleaner, more maintainable code.

In the next tutorial, we'll build a more complete application with associations between multiple schemas and see how ecto_shorts makes managing these relationships easier.
