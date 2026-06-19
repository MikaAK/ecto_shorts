defmodule EctoShorts.Schema.TimestampFree do
  @moduledoc false
  use Ecto.Schema

  schema "timestamp_free" do
    field :title, :string
  end
end
