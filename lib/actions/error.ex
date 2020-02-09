defmodule EctoShorts.Actions.Error do
  @moduledoc """
  This module generates errors from actions it can be
  overridden by config by setting error module

  Errors from Actions: [:not_found, :bad_request, :internal_server_error]
  """

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
