# How to Implement Custom Filters

This guide shows you how to extend ecto_shorts' filtering capabilities by implementing custom filters for your specific needs.

## Understanding Custom Filters

While ecto_shorts provides many built-in filters through the `CommonFilters` module, you may need to implement custom filtering logic for your application's specific requirements. This guide will show you how to do that.

## Custom Search Filters

### Implementing `by_search/2`

The simplest way to add custom filtering is to implement the `by_search/2` function in your schema module. This function is called by ecto_shorts when you use the `search` filter parameter.

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "users" do
    field :name, :string
    field :email, :string
    field :bio, :string
    timestamps()
  end

  # Custom search implementation
  def by_search(query, search_term) do
    search_pattern = "%#{search_term}%"
    
    from u in query,
      where: ilike(u.name, ^search_pattern) or 
             ilike(u.email, ^search_pattern) or 
             ilike(u.bio, ^search_pattern)
  end
end
```

With this implementation, you can now use the `search` filter:

```elixir
# Search for users with "john" in their name, email, or bio
EctoShorts.Actions.all(User, %{search: "john"})
```

### Advanced Search with Multiple Fields

You can implement more complex search logic:

```elixir
def by_search(query, search_params) when is_map(search_params) do
  Enum.reduce(search_params, query, fn
    {:name, value}, query ->
      from q in query, where: ilike(q.name, ^"%#{value}%")
      
    {:email, value}, query ->
      from q in query, where: ilike(q.email, ^"%#{value}%")
      
    {:created_after, date}, query ->
      from q in query, where: q.inserted_at >= ^date
      
    _, query -> query
  end)
end

def by_search(query, search_term) when is_binary(search_term) do
  search_pattern = "%#{search_term}%"
  
  from q in query,
    where: ilike(q.name, ^search_pattern) or ilike(q.email, ^search_pattern)
end
```

This allows for more structured search parameters:

```elixir
# Search with specific field criteria
EctoShorts.Actions.all(User, %{
  search: %{
    name: "john",
    created_after: ~D[2023-01-01]
  }
})
```

## Custom Filter Functions

### Creating Schema-Specific Filter Functions

You can add custom filter functions to your schema modules:

```elixir
defmodule MyApp.Post do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "posts" do
    field :title, :string
    field :content, :string
    field :status, :string
    field :published_at, :utc_datetime
    belongs_to :user, MyApp.User
    timestamps()
  end

  # Custom filter for published posts
  def published(query) do
    from p in query,
      where: p.status == "published" and not is_nil(p.published_at)
  end

  # Custom filter for posts by popularity
  def by_popularity(query, min_likes) do
    from p in query,
      left_join: l in assoc(p, :likes),
      group_by: p.id,
      having: count(l.id) >= ^min_likes
  end
end
```

Then you can use these in your context modules:

```elixir
defmodule MyApp.Blog do
  import Ecto.Query
  alias MyApp.{Repo, Post}
  alias EctoShorts.Actions

  def list_popular_published_posts(min_likes \\ 10) do
    Post
    |> Post.published()
    |> Post.by_popularity(min_likes)
    |> Repo.all()
  end
  
  # Or combine with ecto_shorts filters
  def list_filtered_popular_posts(filters, min_likes \\ 10) do
    query = Post.by_popularity(Post, min_likes)
    Actions.all(query, filters, repo: Repo)
  end
end
```

### Extending CommonFilters

You can create your own module that extends `CommonFilters` with custom functionality:

```elixir
defmodule MyApp.CustomFilters do
  import Ecto.Query
  alias EctoShorts.CommonFilters

  # Function to convert custom filters to query
  def convert_params_to_filter(queryable, params, opts \\ []) do
    # First apply our custom filters
    queryable = apply_custom_filters(queryable, params)
    
    # Then delegate to CommonFilters for standard filters
    # (removing our custom filter keys)
    standard_params = Map.drop(params, [:published_only, :min_likes, :trending])
    CommonFilters.convert_params_to_filter(queryable, standard_params, opts)
  end
  
  defp apply_custom_filters(queryable, params) do
    queryable
    |> apply_published_filter(params)
    |> apply_likes_filter(params)
    |> apply_trending_filter(params)
  end
  
  defp apply_published_filter(queryable, %{published_only: true}) do
    from q in queryable,
      where: q.status == "published" and not is_nil(q.published_at)
  end
  defp apply_published_filter(queryable, _), do: queryable
  
  defp apply_likes_filter(queryable, %{min_likes: min_likes}) when is_integer(min_likes) do
    from p in queryable,
      left_join: l in assoc(p, :likes),
      group_by: p.id,
      having: count(l.id) >= ^min_likes
  end
  defp apply_likes_filter(queryable, _), do: queryable
  
  defp apply_trending_filter(queryable, %{trending: true}) do
    one_week_ago = DateTime.utc_now() |> DateTime.add(-7 * 24 * 60 * 60, :second)
    
    from p in queryable,
      where: p.inserted_at >= ^one_week_ago,
      order_by: [desc: p.view_count]
  end
  defp apply_trending_filter(queryable, _), do: queryable
end
```

Then use your custom filters in your context module:

```elixir
defmodule MyApp.Blog do
  alias MyApp.{Repo, Post, CustomFilters}

  def list_posts(filters \\ %{}) do
    Post
    |> CustomFilters.convert_params_to_filter(filters)
    |> Repo.all()
  end
end
```

Now you can use both standard and custom filters:

```elixir
# Get published posts with "elixir" in the title and at least 5 likes
MyApp.Blog.list_posts(%{
  published_only: true,
  min_likes: 5,
  title: %{ilike: "elixir"}
})
```

## Creating a Custom Actions Module

You can create your own version of the `Actions` module that uses your custom filters:

```elixir
defmodule MyApp.CustomActions do
  alias MyApp.{Repo, CustomFilters}
  
  def all(queryable, filters \\ %{}, opts \\ []) do
    opts = Keyword.put_new(opts, :repo, Repo)
    repo = Keyword.get(opts, :repo)
    
    queryable
    |> CustomFilters.convert_params_to_filter(filters, opts)
    |> repo.all()
  end
  
  # Implement other actions (get, get_by, etc.) similarly
end
```

## Integrating with Phoenix Controllers

Custom filters work well with Phoenix controllers for handling query parameters:

```elixir
defmodule MyAppWeb.PostController do
  use MyAppWeb, :controller
  alias MyApp.Blog

  def index(conn, params) do
    # Convert string keys to atoms for our custom filters
    filters = atomize_keys(params)
    
    # Apply filters including custom ones
    posts = Blog.list_posts(filters)
    
    render(conn, :index, posts: posts)
  end
  
  # Helper to convert string keys to atoms (be careful with user input!)
  defp atomize_keys(params) do
    params
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(k), v} end)
    |> Map.new()
  end
end
```

## Best Practices

1. **Keep it simple**: Start with simple custom filters and add complexity only as needed.

2. **Reuse code**: Extract common filtering patterns into reusable functions.

3. **Document your filters**: Make sure to document your custom filters so other developers know how to use them.

4. **Test thoroughly**: Write tests for your custom filters to ensure they work as expected.

5. **Be careful with user input**: When converting user input to filter parameters, validate the input to prevent security issues.

6. **Consider performance**: Complex filters can impact query performance, so monitor and optimize as necessary.

## Conclusion

Custom filters allow you to extend ecto_shorts' capabilities to meet your specific requirements. By implementing custom search functions, creating schema-specific filters, or extending the `CommonFilters` module, you can build a powerful and flexible querying system for your application.

For more information on the built-in filters, see the Filter Options Reference section in the documentation.
