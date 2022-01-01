# .credo.exs
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Refactor.Nesting, max_nesting: 4},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        # {Credo.Check.Readability.Specs, tags: []},
        {Credo.Check.Readability.StrictModuleLayout, tags: []}
      ]
    }
  ]
}
