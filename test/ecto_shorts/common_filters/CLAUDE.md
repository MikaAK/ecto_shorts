# Testing CommonFilters sub-modules

## Available schemas in `test/support/schema/`

- `EctoShorts.Schema.Post` — fields: `:title`, `:body`, `:published`, `:published_at`, `:views`, `:tags` (`{:array, :string}`), `:author_id`; associations: `:author` (`belongs_to User`), `:comments` (`has_many Comment`), `:authors` (`many_to_many User`)
- `EctoShorts.Schema.User` — fields: `:first_name`, `:last_name`, `:age`, `:email`; associations: `:comments` (`has_many`), `:books` (`has_many`)
- `EctoShorts.Schema.Comment` — fields: `:body`, `:post_id`, `:user_id`
- `EctoShorts.Schema.Book` — fields: `:title`, `:user_id`
- `EctoShorts.Schema.UserData` — fields: `:data` (`:map`), `:typed_map` (`{:map, :string}`), `:creator_id`; associations: `:creator` (`belongs_to User`); table: `data_stores`
- `EctoShorts.Schema.PostWithLock` — fields: `:title`, `:lock_version`; table: `posts_with_lock`

## Writing tests

Tests require no database. The `EctoShorts.Testing` module provides `assert_query/2` (compares
`inspect/1` output) and `assert_sql/2` (compares compiled SQL strings via `to_sql`).

```elixir
defmodule EctoShorts.CommonFilters.MyFilterTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  alias EctoShorts.CommonFilters
  alias EctoShorts.Schema.Post

  import Ecto.Query
  import ExUnit.CaptureLog

  describe "convert_params_to_filter/3 my_key shapes" do
    test "matches Ecto.Query for a root atom value" do
      expected = from(p in Post, ...)

      actual =
        CommonFilters.convert_params_to_filter(Post, %{my_key: :title}, [])

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a named binding value" do
      source = from(p in Post, join: a in assoc(p, :author), as: :author)
      expected = ...

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{as: %{author: %{my_key: :first_name}}},
          []
        )

      assert_query(expected, actual)
    end

    test "matches Ecto.Query for a positional binding value" do
      source = from(p in Post, join: a in assoc(p, :author))
      expected = ...

      actual =
        CommonFilters.convert_params_to_filter(
          source,
          %{at: %{2 => %{my_key: :first_name}}},
          []
        )

      assert_query(expected, actual)
    end

    test "logs a warning and returns query unchanged for an invalid payload" do
      q = from(p in Post)

      log =
        capture_log(fn ->
          assert ^q = CommonFilters.convert_params_to_filter(Post, %{my_key: 12345}, [])
        end)

      assert log =~ "EctoShorts.CommonFilters.MyFilter"
    end
  end
end
```

Create a matching schemaless file at
`test/ecto_shorts/common_filters_schemaless/common_filters_schemaless_my_filter_test.exs`
that repeats the root binding cases using `"posts"` as the source instead of `Post`. Named and
positional binding tests in the schemaless suite are optional because the field-validation path
is skipped when there is no schema.
