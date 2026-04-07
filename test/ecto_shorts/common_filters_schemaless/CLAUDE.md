# common_filters_schemaless

Each file here mirrors a file in `test/ecto_shorts/common_filters/` using a schemaless source
(`"table_name"` string or `{"table_name", SchemaModule}` tuple) instead of a schema module.

## What to test here

- Root binding cases: the same filter values as the schema-backed counterpart, using `"posts"` as source.
- Named and positional binding tests are **optional** — field validation is skipped for schemaless
  sources, so binding-specific behaviour is less meaningful.
- Cases where behaviour *differs* from schema-backed: e.g. `:in` on an array-named field routes to
  `ScalarExpr` without schema; use `:elements` to force `ArrayExpr`.

## File naming

`common_filters_schemaless_X_test.exs` mirrors `common_filters_X_test.exs`. When adding a new
filter, add both files.

## Module naming

```elixir
defmodule EctoShorts.CommonFilters.SchemalessMyFilterTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing
  alias EctoShorts.CommonFilters
  import Ecto.Query
end
```
