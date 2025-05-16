# Used by "mix format"
[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  import_deps: [:ecto],
  locals_without_parens: [
    assert_dynamic: 2,
    assert_query: 2,
    assert_sql: 3
  ],
  export: [
    locals_without_parens: [
      assert_dynamic: 2,
      assert_query: 2,
      assert_sql: 3
    ]
  ]
]
