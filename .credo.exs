# config/.credo.exs
%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        {Credo.Check.Refactor.Nesting, max_nesting: 4}
      ]
    }
  ]
}
