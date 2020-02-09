defmodule EctoShorts.Repo do
  @moduledoc "This module is responsible for calling repo from config"
  @type queryable :: module | Ecto.Query.t()
  @type aggregates :: :avg | :count | :max | :min | :sum
  @type structs_or_struct_or_nil :: [Ecto.Schema.t()] | Ecto.Schema.t() | nil

  @spec insert(Ecto.Changeset.t()) :: {:error, Ecto.Changeset.t()} | {:ok, Ecto.Schema.t()}
  def insert(changeset), do: call(:insert, [changeset])

  @spec delete(Ecto.Schema.t()) :: {:error, Ecto.Changeset.t()} | {:ok, Ecto.Schema.t()}
  def delete(struct), do: call(:delete, [struct])

  @spec update(Ecto.Changeset.t()) :: {:error, Ecto.Changeset.t()} | {:ok, Ecto.Schema.t()}
  def update(changeset), do: call(:update, [changeset])

  @spec get(queryable, integer) :: nil | Ecto.Schema.t()
  def get(module, id), do: call(:get, [module, id])

  @spec one(Ecto.Query.t()) :: nil | Ecto.Schema.t()
  def one(query), do: call(:one, [query])

  @spec all(queryable) :: [Ecto.Schema.t()]
  def all(query), do: call(:all, [query])

  @spec preload(structs_or_struct_or_nil, any, keyword) :: structs_or_struct_or_nil
  def preload(structs_or_struct_or_nil, preloads, opts) do
    call(:preload, [structs_or_struct_or_nil, preloads, opts])
  end

  @spec aggregate(Ecto.Queryable.t(), aggregates, atom, keyword) :: any | nil
  def aggregate(queryable, aggregate, field, opts),
    do: call(:aggregate, [queryable, aggregate, field, opts])

  @spec stream(Ecto.Query.t()) :: Enum.t()
  def stream(query), do: call(:stream, [query])

  defp call(func, args) do
    apply(repo(), func, args)
  end

  defp repo, do: Application.get_env(:ecto_shorts, :repo)
end
