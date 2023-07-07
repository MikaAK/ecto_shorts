defmodule EctoShorts.Actions.Error do
  @moduledoc """
  This module generates errors from actions it can be
  overridden by config by setting error module

  Errors from Actions: [:not_found, :bad_request, :internal_server_error]
  """

  @type t :: ErrorMessage.t()

  @callback create_error(atom, String.t(), map) :: t

  def call(code, message, details) do
    apply(error_module(), :create_error, [code, message, details])
  end

  def error_module,
    do: Application.get_env(:ecto_shorts, :error_module) || EctoShorts.Actions.Error

  def create_error(code, message, details),
    do: %ErrorMessage{
      code: code,
      message: message,
      details: details
    }
end
