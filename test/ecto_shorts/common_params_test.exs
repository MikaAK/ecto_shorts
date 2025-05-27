defmodule EctoShorts.CommonParamsTest do
  use ExUnit.Case, async: true
  doctest EctoShorts.CommonParams

  alias EctoShorts.{
    CommonParams,
    Schemas.Post
  }

  describe "convert_to_insert_all_params" do
    test "generates valid insert params for insert_all when given a list of maps" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [%{title: "post_title"}])

      assert [
               %{
                 title: "post_title",
                 inserted_at: %NaiveDateTime{},
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [] = insert_options
    end

    test "generates valid insert params for update_all when given structs with data" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(Post, [
                 {%Post{id: 1}, %{title: "post_title"}}
               ])

      assert [
               %{
                 id: 1,
                 title: "post_title",
                 updated_at: %NaiveDateTime{}
               }
             ] = inserts

      assert [
               on_conflict: {:replace, [:title]},
               conflict_target: [:id]
             ] = insert_options
    end

    test "does not add placeholders for keys not present in params" do
      assert {:ok, {[entry], []}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{title: "post_title"}],
                 placeholders: %{permalink: "post_permalink"}
               )

      refute entry[:permalink]
    end

    test "replaces a specific field with a placeholder when :on_placeholder_conflict is {:replace, keys}" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [%{title: "post_title", permalink: "post_permalink"}],
                 placeholders: %{permalink: "different_value"},
                 on_placeholder_conflict: {:replace, [:permalink]}
               )

      assert [
               %{
                 title: "post_title",
                 permalink: {:placeholder, :permalink}
               }
             ] = inserts

      assert [] = insert_options
    end

    test "replaces all fields with placeholders when :on_placeholder_conflict is :replace_all" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [
                   %{
                     title: "post_title",
                     permalink: "post_permalink"
                   }
                 ],
                 placeholders: %{does_not_exist: "value", permalink: "placeholder_permalink"},
                 on_placeholder_conflict: :replace_all
               )

      assert [
               %{
                 title: "post_title",
                 permalink: {:placeholder, :permalink}
               }
             ] = inserts

      assert [] = insert_options
    end

    test "replaces field with placeholder when value matches placeholder value" do
      assert {:ok, {inserts, insert_options}} =
               CommonParams.convert_to_insert_all_params(
                 Post,
                 [
                   %{
                     title: "post_title",
                     permalink: "same_as_placeholder_value"
                   }
                 ],
                 placeholders: %{permalink: "same_as_placeholder_value"},
                 on_placeholder_conflict: {:replace, [:description]}
               )

      assert [
               %{
                 title: "post_title",
                 permalink: {:placeholder, :permalink}
               }
             ] = inserts

      assert [] = insert_options
    end

    test "returns an error changeset for invalid data" do
      assert {:error, [%Ecto.Changeset{valid?: false}]} =
               CommonParams.convert_to_insert_all_params(Post, [%{views: "invalid_type"}, %{}])
    end
  end

  describe "convert_to_update_all_params" do
    test "returns expected update_all params" do
      assert [
               inc: [views: 1],
               pull: [tags: "c", tags: "d"],
               push: [tags: "a", tags: "b"],
               set: [
                 notes: "post_notes",
                 title: "post_title",
                 updated_at: %NaiveDateTime{}
               ]
             ] =
               CommonParams.convert_to_update_all_params(Post, %{
                 title: "post_title",
                 views: %{inc: 1},
                 tags: %{push: ["a", "b"], pull: ["c", "d"]},
                 notes: {:set, "post_notes"}
               })
    end
  end
end
