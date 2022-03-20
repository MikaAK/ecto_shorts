# EctoShorts

 [![Hex version badge](https://img.shields.io/hexpm/v/ecto_shorts.svg)](https://hex.pm/packages/ecto_shorts)

Ecto Shorts is a library focused around making Ecto easier to use in an
application and helping to write shorter code

## Installation

Documentation can be found at [https://hexdocs.pm/ecto_shorts](https://hexdocs.pm/ecto_shorts).

```elixir
def deps do
  [
    {:ecto_shorts, "~> 0.1.5"}
  ]
end
```


### Usage
There are 4 main modules to `EctoShorts`. `SchemaHelpers`, `CommonFilters`, `CommonChanges` and `Actions`

To use create functions we must define `create_changeset(params)` on our schema, this usually looks like:
```elixir
def create_changeset(params \\ %{}), do: changeset(__MODULE__, params)
```

#### Actions
This module takes a schema and filter parameters and runs them through CommonFilters, esentially a wrapper
around Repo. All actions can accept an optional argument of a keyword list that can be used to configure which Repo the Action should use.

## Options
    * `:repo` - A module that uses the Ecto.Repo Module.
    * `:replica` - If you don't want to perform any reads against your Primary, you can specify a replica to read from.

For more info on filter options take a look at Common Filters

#### Common Changes
This module is responsible for determining put/cast assoc as well as creating and updating model relations

###### Extra Magic
If you pass a list of id's to a many to many relation it will count that as a `member_update` and remove or add members to the relations list

E.G. User many_to_many Fruit

This would update the user to have only fruits with id 1 and 3
```elixir
CommonChanges.put_or_cast_assoc(change(user, fruits: [%{id: 1}, %{id: 3}]), :fruits)
```

#### Schema Helpers
This module contains helpers to check schema data

#### Common Filters
This module creates query from filter paramters like

```elixir
CommonFilters.convert_params_to_filter(User, %{id: 5})
```
is the same as
```elixir
from u in User, where: id == 5
```

This allows for filters to be constructed from data such as
```elixir
CommonFilters.convert_params_to_filter(User, %{
  favorite_food: "curry",
  age: %{gte: 18, lte: 50},
  name: %{ilike: "steven"},
  preload: [:address],
  last: 5
})
```
which the equivalent would be
```elixir
from u in User,
  preload: [:address],
  limit: 5,
  where: u.favorite_food == "curry" and
         u.age >= 18 and u.age <= 50 and
         ilike(u.name, "%steven%")
```

We are also able to query on the first layer of relations like so:
```elixir
EctoShorts.Actions.all(User, %{
  roles: ["ADMIN", "SUPERUSER"]
})
```

which would be equivalent to:

```elixir
from u in User,
  inner_join: r in assoc(u, :roles), as: :ecto_shorts_roles,
  where: r.code in ["ADMIN", "SUPERUSER"]
```

###### List of common filters
- `preload` - Preloads fields onto the query results
- `start_date` - Query for items inserted after this date
- `end_date` - Query for items inserted before this date
- `before` - Get items with ID's before this value
- `after` - Get items with ID's after this value
- `ids` - Get items with a list of ids
- `first` - Gets the first n items
- `last` - Gets the last n items
- `search` - ***Warning:*** This requires schemas using this to have a `&by_search(query, val)` function
