defmodule EctoShorts do
@moduledoc """
EctoShorts is a library focused on making Ecto easier to use, such as making queries more flexible and pleasant to write, and the resulting code more readable and dynamic
"""

  def filter(module_or_query, filters, order_by_prop \\ :id, order_direction \\ :desc) do
    EctoShorts.CommonFilters.convert_params_to_filter(module_or_query, filters, order_by_prop, order_direction)
  end

end
