defmodule EctoShorts.Actions.Error do
  @type t :: %{code: atom, message: String.t} |
             %{code: atom, message: String.t, details: map}

  @callback create_error(atom, String.t, map) :: t

  def call(code, message, details) do
    apply(error_module(), :create_error, [code, message, details])
  end

  def error_module, do: Application.get_env(:ecto_shorts, :error_module)

  def create_error(code, message, details), do: %{
    code: code,
    message: message,
    details: details
  }
end
