defmodule EctoShorts.Actions.Source do
  @moduledoc since: "3.0.0"
  @moduledoc """
  when this is passed the :from key must point to a name and it returns {:ok, value} or {:error, reason}
  """

  defstruct [:store]

  @type t :: %__MODULE__{store: %{optional(String.t()) => term()}}

  @spec new(map() | keyword()) :: t()
  def new(attrs) do
    struct!(__MODULE__, store: Map.new(attrs[:store] || []))
  end

  def fetch(%__MODULE__{store: store}, key) do
    case store do
      %{^key => value} -> {:ok, value}
      _ -> :error
    end
  end
end
