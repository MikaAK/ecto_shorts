# Building a Complete Application with ecto_shorts

In this tutorial, we'll build a more complete application using ecto_shorts. We'll create a blog application with users, posts, and comments to demonstrate how ecto_shorts simplifies working with associations and complex queries.

## What You'll Learn

- How to set up multiple schemas with associations
- How to create context modules that handle related schemas
- How to use ecto_shorts with preloaded associations
- How to implement advanced filtering with CommonFilters
- How to build a JSON API that leverages ecto_shorts

## Prerequisites

- Completion of the [Getting Started with ecto_shorts](./getting-started.md) tutorial
- Basic understanding of Phoenix and Ecto concepts (schemas, changesets, contexts)
- Familiarity with RESTful API design principles
- Understanding of database relationships (one-to-many, many-to-many)

## Step 1: Create a new Phoenix project

If you haven't already, create a new Phoenix project:

```bash
mix phx.new ecto_shorts_blog --no-html --no-assets --no-dashboard --no-live --no-mailer
cd ecto_shorts_blog
```

Add ecto_shorts to your dependencies in `mix.exs`:

```elixir
{:ecto_shorts, "~> 2.3"}
```

Run `mix deps.get` to install the dependencies.

## Step 2: Create the database schemas

We'll create three schemas: User, Post, and Comment. Let's generate them:

```bash
mix phx.gen.schema User users name:string email:string bio:text
mix phx.gen.schema Post posts title:string content:text user_id:references:users
mix phx.gen.schema Comment comments content:text user_id:references:users post_id:references:posts
```

Now, let's modify each schema to work well with ecto_shorts:

### User Schema

Update `lib/ecto_shorts_blog/user.ex`:

```elixir
defmodule EctoShortsBlog.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :bio, :string

    has_many :posts, EctoShortsBlog.Post
    has_many :comments, EctoShortsBlog.Comment

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :bio])
    |> validate_required([:name, :email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email)
  end

  # For ecto_shorts Actions
  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
  
  # For ecto_shorts search filter
  def by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    
    import Ecto.Query
    from u in query,
      where: ilike(u.name, ^search_pattern) or ilike(u.email, ^search_pattern)
  end
end
```

### Post Schema

Update `lib/ecto_shorts_blog/post.ex`:

```elixir
defmodule EctoShortsBlog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :title, :string
    field :content, :string

    belongs_to :user, EctoShortsBlog.User
    has_many :comments, EctoShortsBlog.Comment

    timestamps()
  end

  def changeset(post, attrs) do
    post
    |> cast(attrs, [:title, :content, :user_id])
    |> validate_required([:title, :content, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  # For ecto_shorts Actions
  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
  
  # For ecto_shorts search filter
  def by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    
    import Ecto.Query
    from p in query,
      where: ilike(p.title, ^search_pattern) or ilike(p.content, ^search_pattern)
  end
end
```

### Comment Schema

Update `lib/ecto_shorts_blog/comment.ex`:

```elixir
defmodule EctoShortsBlog.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :content, :string

    belongs_to :user, EctoShortsBlog.User
    belongs_to :post, EctoShortsBlog.Post

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :user_id, :post_id])
    |> validate_required([:content, :user_id, :post_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
  end

  # For ecto_shorts Actions
  def create_changeset(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
```

## Step 3: Run migrations

```bash
mix ecto.create
mix ecto.migrate
```

## Step 4: Create context modules using ecto_shorts

Now let's create context modules for our application using ecto_shorts:

### Accounts Context

Create `lib/ecto_shorts_blog/accounts.ex`:

```elixir
defmodule EctoShortsBlog.Accounts do
  alias EctoShortsBlog.{Repo, User}
  alias EctoShorts.Actions

  @actions_opts [repo: Repo]

  def create_user(attrs) do
    Actions.create(User, attrs, @actions_opts)
  end

  def get_user(id) do
    Actions.get(User, id, @actions_opts)
  end

  def get_user_by_email(email) do
    Actions.get_by(User, %{email: email}, @actions_opts)
  end

  def list_users(filters \\ %{}) do
    Actions.all(User, filters, @actions_opts)
  end

  def update_user(id, attrs) do
    Actions.update(User, id, attrs, @actions_opts)
  end

  def delete_user(id) do
    Actions.delete(User, id, @actions_opts)
  end
end
```

### Blog Context

Create `lib/ecto_shorts_blog/blog.ex`. This context will handle both Posts and Comments, demonstrating how ecto_shorts makes it easy to work with related schemas:

```elixir
defmodule EctoShortsBlog.Blog do
  alias EctoShortsBlog.{Repo, Post, Comment}
  alias EctoShorts.{Actions, CommonChanges}

  @actions_opts [repo: Repo]

  # Post functions
  
  # Create a new post
  # Returns {:ok, post} on success or {:error, changeset | %ErrorMessage{}} on failure
  def create_post(attrs) do
    Actions.create(Post, attrs, @actions_opts)
  end

  # Get a post by ID with optional preloaded associations
  # The preloads parameter allows you to specify which associations to load
  # Example: get_post(1, [:user, :comments])
  # Returns {:ok, post} if found or {:error, %ErrorMessage{code: :not_found}} if not found
  def get_post(id, preloads \\ []) do
    Actions.get(Post, id, [preload: preloads] ++ @actions_opts)
  end

  # List all posts with optional filters
  # Filters can include preloads: %{preload: [:user, :comments]}
  # Returns a list of posts (empty list if none found)
  def list_posts(filters \\ %{}) do
    Actions.all(Post, filters, @actions_opts)
  end

  # Update a post by ID
  # Returns {:ok, updated_post} on success or {:error, changeset | %ErrorMessage{}} on failure
  def update_post(id, attrs) do
    Actions.update(Post, id, attrs, @actions_opts)
  end

  # Delete a post by ID
  # Returns {:ok, deleted_post} on success or {:error, %ErrorMessage{}} on failure
  def delete_post(id) do
    Actions.delete(Post, id, @actions_opts)
  end

  # Get all posts for a specific user with optional additional filters
  # This demonstrates how to combine fixed criteria (user_id) with dynamic filters
  # Example: get_user_posts(1, %{order_by: {:desc, :inserted_at}, first: 5})
  def get_user_posts(user_id, filters \\ %{}) do
    filters = Map.put(filters, :user_id, user_id)
    Actions.all(Post, filters, @actions_opts)
  end

  # Comment functions
  
  # Create a new comment
  # Returns {:ok, comment} on success or {:error, changeset | %ErrorMessage{}} on failure
  def create_comment(attrs) do
    Actions.create(Comment, attrs, @actions_opts)
  end

  # Get a comment by ID
  # Returns {:ok, comment} if found or {:error, %ErrorMessage{code: :not_found}} if not found
  def get_comment(id) do
    Actions.get(Comment, id, @actions_opts)
  end

  # List all comments with optional filters
  # Example: list_comments(%{preload: [:user, :post], order_by: {:desc, :inserted_at}})
  # Returns a list of comments (empty list if none found)
  def list_comments(filters \\ %{}) do
    Actions.all(Comment, filters, @actions_opts)
  end

  # Update a comment by ID
  # Returns {:ok, updated_comment} on success or {:error, changeset | %ErrorMessage{}} on failure
  def update_comment(id, attrs) do
    Actions.update(Comment, id, attrs, @actions_opts)
  end

  # Delete a comment by ID
  # Returns {:ok, deleted_comment} on success or {:error, %ErrorMessage{}} on failure
  def delete_comment(id) do
    Actions.delete(Comment, id, @actions_opts)
  end

  # Get all comments for a specific post with optional additional filters
  # Example: get_post_comments(1, %{preload: :user})
  def get_post_comments(post_id, filters \\ %{}) do
    filters = Map.put(filters, :post_id, post_id)
    Actions.all(Comment, filters, @actions_opts)
  end
end
```

## Step 5: Create a simple API

Let's create a simple JSON API for our blog application. First, let's create some controllers:

### UserController

Create `lib/ecto_shorts_blog_web/controllers/user_controller.ex`:

```elixir
defmodule EctoShortsBlogWeb.UserController do
  use EctoShortsBlogWeb, :controller
  alias EctoShortsBlog.Accounts

  def index(conn, params) do
    users = Accounts.list_users(params)
    render(conn, :index, users: users)
  end

  def show(conn, %{"id" => id}) do
    case Accounts.get_user(id) do
      {:ok, user} -> render(conn, :show, user: user)
      {:error, %ErrorMessage{code: :not_found}} -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
    end
  end

  def create(conn, %{"user" => user_params}) do
    case Accounts.create_user(user_params) do
      {:ok, user} ->
        conn
        |> put_status(:created)
        |> render(:show, user: user)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "user" => user_params}) do
    case Accounts.update_user(id, user_params) do
      {:ok, user} -> render(conn, :show, user: user)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Accounts.delete_user(id) do
      {:ok, _} -> send_resp(conn, :no_content, "")
      {:error, %ErrorMessage{code: :not_found}} -> conn |> put_status(:not_found) |> json(%{error: "User not found"})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

### UserJSON

Create `lib/ecto_shorts_blog_web/controllers/user_json.ex`:

```elixir
defmodule EctoShortsBlogWeb.UserJSON do
  def index(%{users: users}) do
    %{data: for(user <- users, do: data(user))}
  end

  def show(%{user: user}) do
    %{data: data(user)}
  end

  defp data(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      bio: user.bio
    }
  end
end
```

### PostController

Create `lib/ecto_shorts_blog_web/controllers/post_controller.ex`:

```elixir
defmodule EctoShortsBlogWeb.PostController do
  use EctoShortsBlogWeb, :controller
  alias EctoShortsBlog.Blog

  def index(conn, params) do
    posts = Blog.list_posts(params)
    render(conn, :index, posts: posts)
  end

  def show(conn, %{"id" => id}) do
    case Blog.get_post(id, [:user]) do
      {:ok, post} -> render(conn, :show, post: post)
      {:error, %ErrorMessage{code: :not_found}} -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
    end
  end

  def create(conn, %{"post" => post_params}) do
    case Blog.create_post(post_params) do
      {:ok, post} ->
        conn
        |> put_status(:created)
        |> render(:show, post: post)

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def update(conn, %{"id" => id, "post" => post_params}) do
    case Blog.update_post(id, post_params) do
      {:ok, post} -> render(conn, :show, post: post)
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def delete(conn, %{"id" => id}) do
    case Blog.delete_post(id) do
      {:ok, _} -> send_resp(conn, :no_content, "")
      {:error, %ErrorMessage{code: :not_found}} -> conn |> put_status(:not_found) |> json(%{error: "Post not found"})
    end
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
```

### PostJSON

Create `lib/ecto_shorts_blog_web/controllers/post_json.ex`:

```elixir
defmodule EctoShortsBlogWeb.PostJSON do
  def index(%{posts: posts}) do
    %{data: for(post <- posts, do: data(post))}
  end

  def show(%{post: post}) do
    %{data: data(post)}
  end

  defp data(post) do
    %{
      id: post.id,
      title: post.title,
      content: post.content,
      user_id: post.user_id,
      user: user_data(post)
    }
  end

  defp user_data(%{user: user}) when not is_nil(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email
    }
  end
  defp user_data(_), do: nil
end
```

## Step 6: Set up the routes

Update `lib/ecto_shorts_blog_web/router.ex`:

```elixir
defmodule EctoShortsBlogWeb.Router do
  use EctoShortsBlogWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", EctoShortsBlogWeb do
    pipe_through :api

    resources "/users", UserController, except: [:new, :edit]
    resources "/posts", PostController, except: [:new, :edit]
    
    get "/users/:user_id/posts", PostController, :user_posts
  end
end
```

## Step 7: Add the user_posts function to PostController

Update the PostController to add the user_posts function:

```elixir
def user_posts(conn, %{"user_id" => user_id} = params) do
  filters = Map.drop(params, ["user_id"])
  posts = Blog.get_user_posts(user_id, filters)
  render(conn, :index, posts: posts)
end
```

## Step 8: Try it out

Start the Phoenix server:

```bash
mix phx.server
```

Now you can use tools like curl, Postman, or Insomnia to interact with your API:

1. Create a user:
```
POST /api/users
{
  "user": {
    "name": "John Doe",
    "email": "john@example.com",
    "bio": "I love blogging"
  }
}
```

2. Create a post:
```
POST /api/posts
{
  "post": {
    "title": "My First Post",
    "content": "This is the content of my first post",
    "user_id": 1
  }
}
```

3. Get all posts with filters:
```
GET /api/posts?title=%First%&preload[]=user
```

4. Get posts for a specific user:
```
GET /api/users/1/posts
```

## Step 9: Advanced ecto_shorts features

Let's explore some more advanced features of ecto_shorts that make it powerful for real-world applications:

### Creating Records with Nested Associations

One common requirement is creating a record along with its associated records in a single operation. Let's add a function to the Blog context to create a post with comments in a single transaction:

```elixir
# Create a post with comments in a single transaction
# Example usage:
#   create_post_with_comments(%{
#     "title" => "My Post",
#     "content" => "Post content",
#     "user_id" => 1,
#     "comments" => [
#       %{"content" => "First comment", "user_id" => 2},
#       %{"content" => "Second comment", "user_id" => 3}
#     ]
#   })
def create_post_with_comments(attrs) do
  # Use Ecto.Multi for transaction safety
  Repo.transaction(fn ->
    # First create the post
    case Actions.create(Post, attrs, @actions_opts) do
      {:ok, post} ->
        # Extract comments from attributes (default to empty list if not present)
        comments_attrs = Map.get(attrs, "comments", [])
        
        # Create each comment, associating it with the new post
        Enum.each(comments_attrs, fn comment_attrs ->
          # Add the post_id to each comment
          comment_attrs = Map.put(comment_attrs, "post_id", post.id)
          case Actions.create(Comment, comment_attrs, @actions_opts) do
            {:ok, _comment} -> :ok
            {:error, changeset} -> Repo.rollback(changeset) # Roll back on any error
          end
        end)
        
        # Return the post with preloaded comments
        {:ok, Actions.get(Post, post.id, [preload: [:comments]] ++ @actions_opts)}
        
      {:error, changeset} ->
        Repo.rollback(changeset)
    end
  end)
end
```

### Using Custom Search with CommonFilters

The `search` filter in CommonFilters allows you to implement custom search logic in your schemas. Let's add a function to the Blog context that leverages the `by_search/2` function we defined in our Post schema:

```elixir
# Search posts using the custom search implementation in the Post schema
# This uses the by_search/2 function we defined in the Post schema
# Example: search_posts("elixir", %{order_by: {:desc, :inserted_at}, first: 10})
def search_posts(search_term, filters \\ %{}) do
  # Add the search term to the filters map
  filters = Map.put(filters, :search, search_term)
  
  # The search filter will use Post.by_search/2 under the hood
  Actions.all(Post, filters, @actions_opts)
end
```

### Combining Multiple Filters for Complex Queries

Let's add a function that demonstrates how to combine multiple filters for more complex queries:

```elixir
# Find recent posts by a specific user containing a search term
def find_recent_user_posts_containing(user_id, search_term, limit \\ 10) do
  # Build a complex filter combining multiple conditions
  filters = %{
    user_id: user_id,                    # Posts by this user
    search: search_term,                  # Containing the search term
    order_by: {:desc, :inserted_at},      # Most recent first
    first: limit,                         # Limit results
    preload: [:user, :comments]           # Preload associations
  }
  
  Actions.all(Post, filters, @actions_opts)
end
```

## Conclusion

Congratulations! In this tutorial, you've built a complete blog application using ecto_shorts. You've learned how to:

1. **Set up multiple schemas with associations** - Creating User, Post, and Comment schemas with proper relationships
2. **Create context modules using ecto_shorts Actions** - Building Accounts and Blog contexts with clean, consistent APIs
3. **Build a JSON API using Phoenix controllers** - Implementing RESTful endpoints that leverage ecto_shorts
4. **Use ecto_shorts filters for querying data** - Using CommonFilters to create complex queries with simple parameter maps
5. **Handle associations and complex queries** - Working with preloaded associations and implementing advanced filtering
6. **Implement transactions with nested data** - Creating records with their associated records in a single operation

### Benefits of Using ecto_shorts

By using ecto_shorts in this application, you've gained several advantages:

- **Reduced boilerplate code** - The standard CRUD operations are handled with minimal code
- **Consistent return values** - All operations return `{:ok, result}` or `{:error, reason}` tuples with standardized `%ErrorMessage{}` structs
- **Declarative filtering** - Complex queries are expressed as simple parameter maps
- **Simplified association handling** - Preloading and working with associations is straightforward
- **Better maintainability** - Your code is more consistent and easier to understand

### Next Steps

Now that you've built a complete application with ecto_shorts, you might want to explore:

- **[Actions Reference](../reference/actions.md)** - Detailed documentation of all available Actions functions
- **[CommonFilters Reference](../reference/common_filters.md)** - Complete list of filtering options
- **[Best Practices](../explanation/best-practices.md)** - Tips for using ecto_shorts effectively
- **[Comparison with Plain Ecto](../explanation/comparison.md)** - How ecto_shorts compares to using Ecto directly

You can also extend this application with additional features like authentication, authorization, or more complex relationships between schemas. ecto_shorts will continue to help simplify your database operations as your application grows.
