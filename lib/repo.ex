defmodule EctoShorts.Repo do
  @moduledoc "This module is responsible for calling repo from config"

  def call(func, args) do
    apply(repo(), func, args)
  end

  defp repo, do: Application.get_env(:ecto_shorts, :repo)
end
