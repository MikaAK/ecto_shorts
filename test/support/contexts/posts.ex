defmodule EctoShorts.Support.Contexts.Posts do
  @moduledoc """
  Highlights query building using:
    * query builder functions at context level
    * custom query functions from schema
  """
  alias EctoShorts.Actions.QueryBuilder
  alias EctoShorts.Support.Schemas.Comment

  @behaviour QueryBuilder

  @impl QueryBuilder
  def filters, do: [:select_body, :post_id_with_comment_count_gte]

  @impl QueryBuilder
  def build_query(Comment, %{select_body: true}, query),
    do: Comment.select_body(query)

  def build_query(Comment, %{select_body: _}, query),
    do: query

  @impl QueryBuilder
  def build_query(Comment, %{post_id_with_comment_count_gte: val}, query),
    do: Comment.post_id_with_comment_count_gte(query, val)
end
