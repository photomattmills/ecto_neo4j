use Mix.Config

config :dogma,

  # Select a set of rules as a base
  rule_set: Dogma.RuleSet.All,

  # Pick paths not to lint
  exclude: [
    ~r(\Alib/vendor/),
  ],

  # Override an existing rule configuration
  override: %{
    FunctionArity => [ max: 6 ],
    LineLength    => [ max_length: 85 ],
  }
