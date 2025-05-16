defmodule EctoShorts.Actions.Error do
  @moduledoc """
  Defines a standard error structure used across EctoShorts actions and
  provides a flexible interface for generating actionable errors.

  This module can be overridden via configuration by setting
  `:error_module` in your application config or passing it in explicitly
  via options to `call/4`.

  ## Standard Error Fields

  Each error follows the structure:

  ```elixir
  %{
    code: atom(),
    message: binary(),
    details: nil | map()
  }
  ```
  """

  @type code :: atom()
  @type message :: binary()
  @type details :: map()
  @type opts :: keyword()

  @typedoc """
  Represents a standardized error returned by EctoShorts actions.

  Fields:
    * `:code` – an atom that categorizes the error type
    * `:message` – a human-readable message describing the error
    * `:details` – optional additional context as a map, or nil
  """
  @type t :: %{
          optional(atom()) => any(),
          code: atom(),
          message: binary(),
          details: details() | nil
        }

  @doc """
  Defines the callback used to construct an error struct.

  This callback must be implemented by custom error modules and
  is invoked by `EctoShorts.Actions.Error.call/4`.

  The returned map must include the keys `:code`, `:message`, and `:details`.

  ## Usage

  ```elixir

  defmodule MyApp.CustomError do
    @behaviour EctoShorts.Actions.Error

    def create_error(code, message, details) do
      %{code: code, message: "[MyApp] " <> message, details: details}
    end
  end

  ```
  """
  @callback create_error(atom, String.t(), map) :: t()

  @default_error_module __MODULE__

  @doc """
  Creates an error struct using the default or configured error module.

  Accepts an error `code`, a human-readable `message`, and optional
  `details` map. Uses the `:error_module` option configured in the
  application environment if no module is passed in options.

  Raises if the returned structure is not a valid error map.

  ## Examples

      iex> EctoShorts.Actions.Error.call(:not_found, "User not found", %{id: 123}, [])
      %{code: :not_found, message: "User not found", details: %{id: 123}}

      iex> EctoShorts.Actions.Error.call(:bad_request, "Missing param", nil, error_module: MyApp.CustomError, [])
  """
  @spec call(code(), message(), details() | nil) :: t()
  @spec call(code(), message(), details() | nil, opts()) :: t()
  def call(code, message, details, opts \\ []) do
    error_module = error_module(opts)

    case error_module.create_error(code, message, details) do
      %{code: _, message: _, details: _} = error_message ->
        error_message

      term ->
        raise """
        Expected the error returned by #{inspect(error_module)} to a map of type:

        ```
        %{
          code: atom(),
          message: binary(),
          details: nil | map()
        }
        ```

        got:

        #{inspect(term)}
        """
    end
  end

  defp error_module(opts) do
    opts[:error_module] ||
      EctoShorts.Config.error_module() ||
      @default_error_module
  end

  @doc """
  Default implementation of `create_error/3`.

  Can be overridden in a custom module if configured in application
  settings or passed via `:error_module`.
  """
  @spec create_error(code(), message(), details()) :: t()
  def create_error(code, message, details) do
    struct!(ErrorMessage, code: code, message: message, details: details)
  end
end
