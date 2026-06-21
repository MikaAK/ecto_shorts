defmodule EctoShorts.Actions.ErrorTest do
  use ExUnit.Case, async: true

  alias EctoShorts.Actions.Error

  defmodule CustomError do
    @behaviour EctoShorts.Actions.Error

    @impl true
    def create_error(code, message, details) do
      %{custom: true, code: code, message: message, details: details}
    end
  end

  describe "call/4" do
    test "builds the error using the custom module from the options" do
      result = Error.call(:not_found, "gone", %{id: 1}, error_module: CustomError)

      assert %{custom: true, code: :not_found, message: "gone", details: %{id: 1}} = result
    end
  end
end
