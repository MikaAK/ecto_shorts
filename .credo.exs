allowed_imports = [
  [:Absinthe],
  [:ChannelCase],
  [:ConnCase],
  [:DataCase],
  [:EctoEnum],
  [:Ecto],
  [:ExUnit, :CaptureLog],
  [:ExUnit],
  [:Mix],
  [:ErrorHelpers],
  [:Phoenix],
  [:Phoenix, :Controller],
  [:Phoenix, :LiveView, :Router],
  [:Plug],
  [:Router, :Helpers],
  [:Swoosh, :TestAssertions],
  [:Telemetry, :Metrics],
  [:SharedUtils, :Support, :HTTPSandbox],
  [:LearnElixirLanderWeb, :Gettext],
  [:LearnElixirLanderWeb, :CoreComponents],
  [:LearnElixirLanderWeb, :AlpineComponents],
  [:TeachingPlatformWeb, :Gettext],
  [:TeachingPlatformWeb, :CoreComponents],
  [:TeachingPlatformWeb, :DisplayComponents],
  [:TeachingPlatformWeb, :InteractiveComponents],
  [:TeachingPlatformWeb, :AlpineComponents],
  [:TeachingPlatformWeb, :FormComponents]
]

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/*/lib/",
          "apps/*/src/",
          "apps/*/test/",
          "apps/*/web/"
        ],
        excluded: [
          ~r"_build/",
          ~r"deps/",
          # Ecto query DSL requires == and != operators, not === and !==
          ~r"lib/ecto_shorts/dynamics/adapters/postgres/.*/specs\.ex$",
          ~r"lib/ecto_shorts/testing\.ex$",
          ~r"lib/ecto_shorts/compiler/clause_spec\.ex$"
        ]
      },
      plugins: [],
      requires: ["deps/blitz_credo/lib/blitz_credo/"],
      strict: true,
      parse_timeout: 10000,
      color: true,
      checks: [

        # BlitzCredoChecks

        {BlitzCredoChecks.SetWarningsAsErrorsInTest, false},
        {BlitzCredoChecks.DocsBeforeSpecs, []},
        {BlitzCredoChecks.DoctestIndent, []},
        {BlitzCredoChecks.NoAsyncFalse, []},
        {BlitzCredoChecks.NoDSLParentheses, []},
        {BlitzCredoChecks.NoIsBitstring, []},
        {BlitzCredoChecks.StrictComparison, []},
        {BlitzCredoChecks.LowercaseTestNames, []},
        {BlitzCredoChecks.ImproperImport, allowed_modules: allowed_imports},

        # Consistency Checks
        {Credo.Check.Consistency.ExceptionNames, []},
        {Credo.Check.Consistency.LineEndings, []},
        {Credo.Check.Consistency.ParameterPatternMatching, []},
        {Credo.Check.Consistency.SpaceAroundOperators, []},
        {Credo.Check.Consistency.SpaceInParentheses, []},
        {Credo.Check.Consistency.TabsOrSpaces, []},

        # Design Checks
        {Credo.Check.Design.AliasUsage,
         [
           if_nested_deeper_than: 0,
           if_called_more_often_than: 0
         ]},

        # No outstanding TODOs
        {Credo.Check.Design.TagTODO, []},
        {Credo.Check.Design.TagFIXME, []},

        # # Readability Checks
        {Credo.Check.Readability.AliasOrder, false},
        {Credo.Check.Readability.FunctionNames, []},
        {Credo.Check.Readability.LargeNumbers, []},
        {Credo.Check.Readability.MaxLineLength, [max_length: 120]},
        {Credo.Check.Readability.ModuleAttributeNames, []},
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.ModuleNames, []},
        {Credo.Check.Readability.NestedFunctionCalls, []},
        {Credo.Check.Readability.ParenthesesInCondition, []},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
        {Credo.Check.Readability.PipeIntoAnonymousFunctions, []},
        {Credo.Check.Readability.PredicateFunctionNames, []},
        {Credo.Check.Readability.PreferImplicitTry, []},
        {Credo.Check.Readability.RedundantBlankLines, false},
        {Credo.Check.Readability.Semicolons, []},
        {Credo.Check.Readability.SeparateAliasRequire, []},
        {Credo.Check.Readability.SingleFunctionToBlockPipe, []},
        {Credo.Check.Readability.SpaceAfterCommas, false},
        {Credo.Check.Readability.StringSigils, []},
        {Credo.Check.Readability.TrailingBlankLine, false},
        {Credo.Check.Readability.TrailingWhiteSpace, false},
        {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
        {Credo.Check.Readability.VariableNames, []},
        {Credo.Check.Readability.WithSingleClause, []},

        # Refactoring Opportunities
        {Credo.Check.Refactor.Apply, []},
        {Credo.Check.Refactor.CondStatements, []},
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        {Credo.Check.Refactor.FilterCount, []},
        {Credo.Check.Refactor.FilterFilter, []},
        {Credo.Check.Refactor.FunctionArity, []},
        {Credo.Check.Refactor.LongQuoteBlocks, false},
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Refactor.MapJoin, []},
        {Credo.Check.Refactor.MatchInCondition, []},
        {Credo.Check.Refactor.NegatedConditionsInUnless, []},
        {Credo.Check.Refactor.NegatedConditionsWithElse, []},
        {Credo.Check.Refactor.Nesting, false},
        {Credo.Check.Refactor.RedundantWithClauseResult, []},
        {Credo.Check.Refactor.RejectReject, []},
        {Credo.Check.Refactor.UnlessWithElse, []},
        {Credo.Check.Refactor.WithClauses, []},

        # Warnings
        {Credo.Check.Warning.ApplicationConfigInModuleAttribute, []},
        {Credo.Check.Warning.BoolOperationOnSameValues, []},
        {Credo.Check.Warning.Dbg, []},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck, []},
        {Credo.Check.Warning.IExPry, []},
        {Credo.Check.Warning.IoInspect, []},
        {Credo.Check.Warning.LazyLogging, false},
        {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig, []},
        {Credo.Check.Warning.MixEnv, false},
        {Credo.Check.Warning.OperationOnSameValues, []},
        {Credo.Check.Warning.OperationWithConstantResult, []},
        {Credo.Check.Warning.RaiseInsideRescue, []},
        {Credo.Check.Warning.SpecWithStruct, []},
        {Credo.Check.Warning.UnusedEnumOperation, []},
        {Credo.Check.Warning.UnusedFileOperation, []},
        {Credo.Check.Warning.UnusedKeywordOperation, []},
        {Credo.Check.Warning.UnusedListOperation, []},
        {Credo.Check.Warning.UnusedPathOperation, []},
        {Credo.Check.Warning.UnusedRegexOperation, []},
        {Credo.Check.Warning.UnusedStringOperation, []},
        {Credo.Check.Warning.UnusedTupleOperation, []},
        {Credo.Check.Warning.UnsafeExec, []},
        {Credo.Check.Warning.WrongTestFileExtension, []},

        # Controversial and experimental checks
        {Credo.Check.Readability.StrictModuleLayout, false},
        {Credo.Check.Consistency.MultiAliasImportRequireUse, false},
        {Credo.Check.Consistency.UnusedVariableNames, false},
        {Credo.Check.Design.DuplicatedCode, false},
        {Credo.Check.Readability.AliasAs, false},
        {Credo.Check.Readability.MultiAlias, false},
        {Credo.Check.Readability.Specs, false},
        {Credo.Check.Readability.SinglePipe, []},
        {Credo.Check.Readability.WithCustomTaggedTuple, []},
        {Credo.Check.Refactor.ABCSize, false},
        {Credo.Check.Refactor.AppendSingleItem, false},
        {Credo.Check.Refactor.DoubleBooleanNegation, false},
        {Credo.Check.Refactor.ModuleDependencies, false},
        {Credo.Check.Refactor.NegatedIsNil, false},
        {Credo.Check.Refactor.PipeChainStart, []},
        {Credo.Check.Refactor.VariableRebinding, false},
        {Credo.Check.Warning.LeakyEnvironment, false},
        {Credo.Check.Warning.MapGetUnsafePass, false},
        {Credo.Check.Warning.UnsafeToAtom, false}
      ]
    }
  ]
}
