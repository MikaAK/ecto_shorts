defmodule EctoShorts do
  @moduledoc """
  Ecto Shorts is a library created to help shorten ecto interactions
  and remove most of the related code.

  The major limitation right now is this is restricted to functioning
  on 1 repo, in the future I would expect multi-repo support to expand

  There are 2 main modules Actions and CommonChanges

  ### Actions
  `EctoShorts.Actions` allows for filters to be constructed from data such as

  ```elixir
  Actions.all(User, %{
    favorite_food: "curry",
    age: %{gte: 18, lte: 50},
    name: %{ilike: "steven"},
    preload: [:address],
    last: 5
  })
  ```

  which the equivelent would be

  ```elixir
  Repo.all from u in User,
    preload: [:address],
    limit: 5,
    where: u.favorite_food == "curry" and
           u.age >= 18 and u.age <= 50 and
           ilike(u.name, "%steven%")
  ```

  ### CommonChanges
  `EctoShorts.CommonChanges` is responsible for updating relations on schemas it allows
  you to update associations or create using changesets and handles choosing between
  `put_assoc` and `cast_assoc`

  ```elixir
  Actions.update(User, 1, %{friends: [%{id: 5, name: "Billy"}]})
  Actions.update(User, 1, %{friends: [%{id: 5, name: "Bob"}]})
  ```

  Another feature is you can update many to many relationship members using a id list of members

  ###### How to make user 1 friends with users 5, 6, 7
  ```elixir
  Actions.update(User, 1, %{friends: [%{id: 5}, %{id: 6}, %{id: 7}]})
  ```

  ## Config
  You can configure both the Repo and Error module via
  ```elixir
  config :ecto_shorts,
    repo: MyRepo,
    error_module: EctoShorts.Actions.Error
  ```
  """
end
