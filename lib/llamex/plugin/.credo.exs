%{
  configs: [
    %{
      name: "default",
      checks: %{
        extra: [
          {Llamex.Check.NoOneLiners, []},
          {Llamex.Check.NoAdHocAshQueries, []},
          {Llamex.Check.ConsistentInterfaces, []},
          {Llamex.Check.NoDBWorkInMemory, []}
        ]
      }
    }
  ]
}
