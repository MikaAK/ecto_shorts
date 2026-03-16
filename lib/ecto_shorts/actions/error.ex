defmodule EctoShorts.Actions.Error do
  @moduledoc """
  Defines the default error structure and a pluggable behaviour for building
  action errors across EctoShorts.

  Every `EctoShorts.Actions` function that can fail returns an error value
  produced by calling `call/4` on the configured error module. By default,
  `call/4` delegates to this module's own `create_error/3`, which builds an
  `%ErrorMessage{}` struct from the `error_message` library.

  ## Implementing a custom error module

  Implement the `EctoShorts.Actions.Error` behaviour to control the shape of
  error values across your application:

      defmodule MyApp.Error do
        @behaviour EctoShorts.Actions.Error

        @impl true
        def create_error(code, message, details) do
          %{code: code, message: "[MyApp] " <> message, details: details}
        end
      end

  ## Configuration

  Register your custom error module globally in your application config:

      # config/config.exs
      config :ecto_shorts, error_module: MyApp.Error

  Or pass it at runtime via the `:error_module` option on any
  `EctoShorts.Actions` function.

  See also `EctoShorts.Config.error_module/0` and `EctoShorts.Actions`.
  """

  @doc """
  Builds an error value from the given `code`, `message`, and `details`.

  Called by `EctoShorts.Actions.Error.call/4` once the error module is
  resolved. Must return any value - the shape is determined entirely by the
  implementing module.

  ## Arguments

  * `code` - an atom representing the error type (e.g. `:not_found`,
    `:conflict`, `:bad_request`).
  * `message` - a human-readable string describing the error.
  * `details` - a map containing additional context (e.g. IDs, params).

  ## Return value

  Any term. The default implementation returns `%ErrorMessage{}`.

  ## Example implementation

      @impl true
      def create_error(code, message, details) do
        %{code: code, message: "[MyApp] " <> message, details: details}
      end

  See also `call/4`.
  """
  @callback create_error(atom(), binary(), map()) :: any()

  alias EctoShorts.Config

  @default_error_module __MODULE__

  @doc """
  Creates an error struct using the default or configured error module.

  `code` is an atom representing the error type (e.g., `:not_found`,
  `:conflict`). `message` is a human-readable binary string. `details`
  is a map of additional context. `opts` is an optional keyword list.

  Resolves the error module in this order: the `:error_module` key in
  `opts`, then the `:error_module` application config, then falls back
  to `EctoShorts.Actions.Error` itself.

  Returns the result of calling `create_error/3` on the resolved module.
  By default this is an `ErrorMessage` struct with `:code`, `:message`,
  and `:details` fields.

  ## Options

  * `:error_module` - a module implementing the `EctoShorts.Actions.Error`
    behaviour. Defaults to `EctoShorts.Config.error_module/0`.

  ## Examples

      iex> EctoShorts.Actions.Error.call(:not_found, "User not found", %{id: 123})
      %ErrorMessage{code: :not_found, message: "User not found", details: %{id: 123}}

      # Using a custom error module at runtime
      # EctoShorts.Actions.Error.call(:bad_request, "Missing param", nil, error_module: MyApp.Error)

  See also `create_error/3` and `EctoShorts.Config.error_module/0`.
  """
  @spec call(atom(), binary(), map() | nil, keyword()) :: any()
  def call(code, message, details, opts \\ []) do
    error_module(opts).create_error(code, message, details)
  end

  defp error_module(opts) do
    opts[:error_module] ||
      Config.error_module() ||
      @default_error_module
  end

  @doc """
  Default implementation of `create_error/3`.

  Builds an `%ErrorMessage{}` struct from the given `code`, `message`, and
  `details`. This is the fallback used when no custom error module is
  configured via `:error_module`.

  Returns `%ErrorMessage{code: code, message: message, details: details}`.

  See also `call/4` and the `c:create_error/3` callback.
  """
  def create_error(code, message, details) do
    struct!(ErrorMessage,
      code: code,
      message: message,
      details: details
    )
  end
end
