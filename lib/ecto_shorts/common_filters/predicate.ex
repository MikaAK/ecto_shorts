defmodule EctoShorts.CommonFilters.Predicate do
  @moduledoc """
  One resolved filter predicate: a column, its routing family, whether it is
  negated, and the tidied operator-expression. Produced by `PredicateBuilder`,
  consumed by the dialect adapter. See spec §2.1.
  """
  @enforce_keys [:field, :routing, :negated, :expr]
  defstruct [:field, :routing, :negated, :expr]

  @type routing :: :scalar | :array | :map | :common
  @type t :: %__MODULE__{
          field: atom(),
          routing: routing(),
          negated: boolean(),
          expr: term()
        }
end
