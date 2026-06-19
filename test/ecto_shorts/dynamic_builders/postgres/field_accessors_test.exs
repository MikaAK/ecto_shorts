defmodule EctoShorts.DynamicBuilders.Postgres.FieldAccessorsTest do
  use ExUnit.Case, async: true
  use EctoShorts.Testing

  import Ecto.Query

  alias EctoShorts.DynamicBuilders.Postgres.FieldAccessors
  alias EctoShorts.Schema.Post

  test "field_dyn/2 for the root binding equals an inline field reference" do
    inline = from(p in Post, where: field(p, ^:title) == ^"x")
    f = FieldAccessors.field_dyn({:as, nil}, :title)
    composed = from(p in Post, where: ^dynamic([], ^f == ^"x"))
    assert_sql(inline, composed)
  end

  test "field_dyn/2 for a named binding equals an inline named-binding reference" do
    source = from(p in Post, join: a in assoc(p, :author), as: :author)
    inline = from(q in source, where: field(as(:author), ^:first_name) == ^"x")
    f = FieldAccessors.field_dyn({:as, :author}, :first_name)
    composed = from(q in source, where: ^dynamic([], ^f == ^"x"))
    assert_sql(inline, composed)
  end

  test "field_dyn/2 for a positional binding equals an inline positional reference" do
    source = from(p in Post, join: a in assoc(p, :author))
    inline = from([_p, a] in source, where: field(a, ^:first_name) == ^"x")
    f = FieldAccessors.field_dyn({:at, 2}, :first_name)
    composed = from(q in source, where: ^dynamic([], ^f == ^"x"))
    assert_sql(inline, composed)
  end

  test "known_binding?/1 is true for recognized shapes and false otherwise" do
    assert FieldAccessors.known_binding?({:as, nil})
    assert FieldAccessors.known_binding?({:as, :author})
    assert FieldAccessors.known_binding?({:at, 2})
    # beyond max_positional_bindings (default 10) → unrecognized
    refute FieldAccessors.known_binding?({:at, 999})
    refute FieldAccessors.known_binding?({:bogus, :shape})
  end
end
