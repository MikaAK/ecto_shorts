defmodule EctoShorts.Actions.Error do
  @moduledoc """
  Standardized error handling for EctoShorts actions.
  
  This module provides a consistent way to generate error messages across
  all EctoShorts operations. It can be overridden by configuring a custom
  error module in your application configuration.
  
  ## Configuration
  
  To use a custom error module:
  
  ```elixir
  # In your config.exs
  config :ecto_shorts, :error_module, YourApp.CustomErrorModule
  ```
  
  Your custom module must implement the `create_error/3` callback.
  
  ## Standard Error Codes
  
  The default implementation uses the following error codes:
  
  * `:not_found` - When a requested resource cannot be found
  * `:bad_request` - When input parameters are invalid
  * `:internal_server_error` - For unexpected errors during processing
  """

  @type t :: ErrorMessage.t

  @doc """
  Callback for creating error messages.
  
  Custom error modules must implement this callback to be compatible
  with EctoShorts error handling.
  
  ## Parameters
  
  * `code` - An atom representing the error type (e.g., `:not_found`)
  * `message` - A human-readable error message
  * `details` - A map containing additional error context
  
  ## Returns
  
  An error structure compatible with the `t()` type
  """
  @callback create_error(atom, String.t, map) :: t

  @doc """
  Creates an error using the configured error module.
  
  This function delegates to the appropriate error module based on configuration.
  
  ## Parameters
  
  * `code` - An atom representing the error type (e.g., `:not_found`)
  * `message` - A human-readable error message
  * `details` - A map containing additional error context
  
  ## Returns
  
  An error structure as defined by the configured error module
  """
  def call(code, message, details) do
    module = error_module()

    module.create_error(code, message, details)
  end

  @doc """
  Returns the configured error module or falls back to the default.
  
  ## Returns
  
  The module to use for error handling
  """
  def error_module, do: Application.get_env(:ecto_shorts, :error_module) || EctoShorts.Actions.Error

  @doc """
  Default implementation of the error creation callback.
  
  Creates a standardized error message structure with the provided information.
  
  ## Parameters
  
  * `code` - An atom representing the error type (e.g., `:not_found`)
  * `message` - A human-readable error message
  * `details` - A map containing additional error context
  
  ## Returns
  
  An `ErrorMessage` struct with the provided information
  """
  def create_error(code, message, details), do: %ErrorMessage{
    code: code,
    message: message,
    details: details
  }
end
