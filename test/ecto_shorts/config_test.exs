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
end
