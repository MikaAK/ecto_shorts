defmodule EctoShorts.FilterError do
  @moduledoc """
  Raised when a caller-supplied filter is structurally invalid in a way that
  cannot be safely skipped (e.g. an unknown date unit, or arithmetic with the
  wrong number of operands). See spec §3.11.
  """
  defexception [:message]
end
