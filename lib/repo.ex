defmodule EctoShorts.Repo do
  def call(func, args) do
    apply(repo(), func, args)
  end

  defp repo, do: Application.get_env(:ecto_shorts, :repo)
end
