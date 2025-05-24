# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ecto, :ecto_sql],
  locals_without_parens: [
    assert_dynamic: 2,
    assert_query: 2,
    assert_sql: 3,
    from: 1,
    from: 2
  ],
  export: [
    locals_without_parens: [
      assert_dynamic: 2,
      assert_query: 2,
      assert_sql: 3
    ]
  ]
]
