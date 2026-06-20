defmodule EctoShorts.FilterError do
  @moduledoc """
  An exception raised when a filter value has an invalid structure.

  In Elixir, an exception is a way to signal that something went wrong that
  the program cannot recover from automatically. This exception is raised by
  `EctoShorts.CommonFilters` when a filter value is wrong in a way that
  cannot be safely ignored.

  EctoShorts distinguishes between two kinds of problems:

  * **Warnings** — a field name is not found on the schema, or a value type
    does not match. These are logged as warnings and the filter is skipped,
    so the rest of the query still runs.
  * **Errors** — the filter value has a structural problem that makes it
    impossible to continue building the query safely. These raise
    `EctoShorts.FilterError`.

  Examples that raise this exception:

  * Passing a non-map value where an association filter expects a map or
    keyword list — for example, `%{comments: "invalid"}` when `:comments` is
    a schema association.
  * A positional binding index (`:at`) that is less than 1 or greater than
    the configured `max_positional_bindings`.
  * An arithmetic expression with the wrong number of operands.
  * An unknown date or time unit inside a date range filter.
  """
  defexception [:message]
end
