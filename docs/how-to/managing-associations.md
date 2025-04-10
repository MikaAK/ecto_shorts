# How to Manage Associations with CommonChanges

This guide shows you how to use the `CommonChanges` module in ecto_shorts to simplify working with associations between schemas.

## Understanding CommonChanges

The `CommonChanges` module provides functions to handle associations in Ecto changesets, making it easier to create, update, and manage relationships between schemas.

## Basic Association Management

### Put or Cast Associations

The core function in `CommonChanges` is `put_or_cast_assoc/3`, which intelligently determines whether to use `put_assoc` or `cast_assoc` based on the data provided:

```elixir
alias EctoShorts.CommonChanges

# Starting with a changeset
changeset = User.changeset(%User{}, user_params)

# Handle the posts association
changeset = CommonChanges.put_or_cast_assoc(changeset, :posts, opts \\ [])
```

This function examines the data in the changeset and:
- Uses `put_assoc` when the association data is already a struct or list of structs
- Uses `cast_assoc` when the association data is a map or list of maps that needs to be cast

### Working with belongs_to Associations

When working with a `belongs_to` association, you can use `put_or_cast_assoc` to handle the relationship:

```elixir
# Create a post with an associated user
post_params = %{
  "title" => "My Post",
  "content" => "Post content",
  "user" => %{id: 1}  # Reference to existing user
}

post_changeset = Post.changeset(%Post{}, post_params)
post_changeset = CommonChanges.put_or_cast_assoc(post_changeset, :user)
```

### Working with has_many Associations

For `has_many` associations, the function works similarly:

```elixir
# Create a user with associated posts
user_params = %{
  "name" => "John Doe",
  "email" => "john@example.com",
  "posts" => [
    %{"title" => "Post 1", "content" => "Content 1"},
    %{"title" => "Post 2", "content" => "Content 2"}
  ]
}

user_changeset = User.changeset(%User{}, user_params)
user_changeset = CommonChanges.put_or_cast_assoc(user_changeset, :posts)
```

## Advanced Association Management

### Many-to-Many Associations

One of the most powerful features of `CommonChanges` is its ability to handle many-to-many relationships intelligently. When you pass a list of IDs or a list of maps with IDs, it will update the association to match exactly what you provide:

```elixir
# User has many_to_many relationship with roles
user_params = %{
  "name" => "John Doe",
  "email" => "john@example.com",
  "roles" => [1, 2, 3]  # List of role IDs
}

# Or alternatively
user_params = %{
  "name" => "John Doe",
  "email" => "john@example.com",
  "roles" => [%{id: 1}, %{id: 2}, %{id: 3}]  # List of maps with IDs
}

user_changeset = User.changeset(%User{}, user_params)
user_changeset = CommonChanges.put_or_cast_assoc(user_changeset, :roles)
```

This will:
1. Keep roles with IDs 1, 2, and 3 in the association
2. Remove any other roles that were previously associated
3. Add any new roles that weren't previously associated

This is equivalent to doing a "sync" operation on the many-to-many relationship, ensuring that the association exactly matches what you provide.

### Nested Associations

`CommonChanges` can handle nested associations as well:

```elixir
# Create a user with posts, and each post has comments
user_params = %{
  "name" => "John Doe",
  "email" => "john@example.com",
  "posts" => [
    %{
      "title" => "Post 1",
      "content" => "Content 1",
      "comments" => [
        %{"content" => "Comment 1"},
        %{"content" => "Comment 2"}
      ]
    },
    %{
      "title" => "Post 2",
      "content" => "Content 2",
      "comments" => [
        %{"content" => "Comment 3"}
      ]
    }
  ]
}

user_changeset = User.changeset(%User{}, user_params)
user_changeset = CommonChanges.put_or_cast_assoc(user_changeset, :posts)
```

In this case, you would need to make sure that your `Post` schema also handles the `:comments` association in its changeset function.

## Practical Examples

### Creating a Record with Associations

```elixir
defmodule MyApp.Blog do
  alias MyApp.{Repo, Post, User}
  alias EctoShorts.{Actions, CommonChanges}

  def create_post_with_user(post_params) do
    # Start with an empty post
    %Post{}
    # Apply the post params
    |> Post.changeset(post_params)
    # Handle the user association
    |> CommonChanges.put_or_cast_assoc(:user)
    # Insert into the database
    |> Repo.insert()
  end
end
```

### Updating a Record with Associations

```elixir
defmodule MyApp.Blog do
  alias MyApp.{Repo, Post}
  alias EctoShorts.{Actions, CommonChanges}

  def update_post_with_comments(post_id, post_params) do
    with {:ok, post} <- Actions.get(Post, post_id) do
      post
      |> Post.changeset(post_params)
      |> CommonChanges.put_or_cast_assoc(:comments)
      |> Repo.update()
    end
  end
end
```

### Managing Many-to-Many Relationships

```elixir
defmodule MyApp.Accounts do
  alias MyApp.{Repo, User, Role}
  alias EctoShorts.{Actions, CommonChanges}

  def update_user_roles(user_id, role_ids) do
    with {:ok, user} <- Actions.get(User, user_id) do
      user
      |> User.changeset(%{})  # Empty changeset to start
      |> CommonChanges.put_or_cast_assoc(:roles, %{ids: role_ids})
      |> Repo.update()
    end
  end
end
```

## Integration with Actions

The `Actions` module in ecto_shorts automatically uses `CommonChanges` to handle associations when creating or updating records:

```elixir
# Create a user with posts
user_params = %{
  "name" => "John Doe",
  "email" => "john@example.com",
  "posts" => [
    %{"title" => "Post 1", "content" => "Content 1"},
    %{"title" => "Post 2", "content" => "Content 2"}
  ]
}

# Actions.create automatically handles the posts association
{:ok, user} = EctoShorts.Actions.create(User, user_params)

# Update a user's roles
role_params = %{
  "roles" => [1, 2, 3]  # List of role IDs
}

{:ok, user} = EctoShorts.Actions.update(User, user.id, role_params)
```

## Best Practices

1. **Define proper changesets**: Make sure your schemas have proper changeset functions that validate and cast all the necessary fields.

2. **Use IDs for existing records**: When referencing existing records in associations, use their IDs rather than trying to recreate the entire record.

3. **Be careful with nested associations**: While ecto_shorts makes it easier to work with nested associations, be mindful of the potential performance impact of deeply nested structures.

4. **Validate associations**: Add appropriate foreign key constraints and validations to ensure data integrity.

## Conclusion

The `CommonChanges` module in ecto_shorts simplifies working with associations in Ecto by providing intelligent functions that determine the appropriate way to handle each association. This reduces boilerplate code and makes your application more maintainable.

For more information on available options, see the [Common Changes Reference](../reference/common-changes.md).
