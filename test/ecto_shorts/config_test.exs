defmodule EctoShorts.ConfigTest do
  use ExUnit.Case
  doctest EctoShorts.Config

  alias EctoShorts.Config

  describe "repo!/1" do
    test "raises when no repo is configured and no opt is passed" do
      # Temporarily clear the app config repo to force the raise path.
      # The test env sets :repo to EctoShorts.Repo, so we override via opts
      # by passing repo: nil explicitly.
      assert_raise RuntimeError, ~r/EctoShorts repo not configured/, fn ->
        Config.repo!(repo: nil)
      end
    end
  end

  describe "replica!/1" do
    test "raises when neither replica nor repo is configured" do
      assert_raise RuntimeError, ~r/EctoShorts replica and repo not configured/, fn ->
        Config.replica!(replica: nil, repo: nil)
      end
    end
  end

  describe "error_module!/0" do
    test "returns the default EctoShorts.Actions.Error when not configured" do
      prior = Application.get_env(:ecto_shorts, :error_module)
      Application.delete_env(:ecto_shorts, :error_module)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :error_module, prior)
        else
          Application.delete_env(:ecto_shorts, :error_module)
        end
      end)

      assert Config.error_module!() === EctoShorts.Actions.Error
    end

    test "returns the configured error_module when set" do
      prior = Application.get_env(:ecto_shorts, :error_module)
      Application.put_env(:ecto_shorts, :error_module, MyApp.CustomError)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :error_module, prior)
        else
          Application.delete_env(:ecto_shorts, :error_module)
        end
      end)

      assert Config.error_module!() === MyApp.CustomError
    end
  end

  describe "dynamic_builder_module!/0" do
    test "raises when :dynamic_builder_module is not configured" do
      prior = Application.get_env(:ecto_shorts, :dynamic_builder_module)
      Application.delete_env(:ecto_shorts, :dynamic_builder_module)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :dynamic_builder_module, prior)
        else
          Application.delete_env(:ecto_shorts, :dynamic_builder_module)
        end
      end)

      assert_raise RuntimeError, ~r/dynamic_builder_module/, fn ->
        Config.dynamic_builder_module!()
      end
    end

    test "returns the configured module when set" do
      prior = Application.get_env(:ecto_shorts, :dynamic_builder_module)
      Application.put_env(:ecto_shorts, :dynamic_builder_module, EctoShorts.DynamicBuilders.Postgres)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :dynamic_builder_module, prior)
        else
          Application.delete_env(:ecto_shorts, :dynamic_builder_module)
        end
      end)

      assert Config.dynamic_builder_module!() === EctoShorts.DynamicBuilders.Postgres
    end
  end

  describe "query_builder_module!/0" do
    test "raises when :query_builder_module is not configured" do
      prior = Application.get_env(:ecto_shorts, :query_builder_module)
      Application.delete_env(:ecto_shorts, :query_builder_module)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :query_builder_module, prior)
        else
          Application.delete_env(:ecto_shorts, :query_builder_module)
        end
      end)

      assert_raise RuntimeError, ~r/query_builder_module/, fn ->
        Config.query_builder_module!()
      end
    end

    test "returns the configured module when set" do
      prior = Application.get_env(:ecto_shorts, :query_builder_module)
      Application.put_env(:ecto_shorts, :query_builder_module, MyApp.QueryBuilder)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :query_builder_module, prior)
        else
          Application.delete_env(:ecto_shorts, :query_builder_module)
        end
      end)

      assert Config.query_builder_module!() === MyApp.QueryBuilder
    end
  end

  describe "query_provider_module!/0" do
    test "raises when :query_provider_module is not configured" do
      prior = Application.get_env(:ecto_shorts, :query_provider_module)
      Application.delete_env(:ecto_shorts, :query_provider_module)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :query_provider_module, prior)
        else
          Application.delete_env(:ecto_shorts, :query_provider_module)
        end
      end)

      assert_raise RuntimeError, ~r/query_provider_module/, fn ->
        Config.query_provider_module!()
      end
    end

    test "returns the configured module when set" do
      prior = Application.get_env(:ecto_shorts, :query_provider_module)
      Application.put_env(:ecto_shorts, :query_provider_module, MyApp.QueryProvider)

      on_exit(fn ->
        if prior do
          Application.put_env(:ecto_shorts, :query_provider_module, prior)
        else
          Application.delete_env(:ecto_shorts, :query_provider_module)
        end
      end)

      assert Config.query_provider_module!() === MyApp.QueryProvider
    end
  end
end
