# Llamex

Llamex is a Credo plugin suite for issues commonly introduced by LLM-assisted
Elixir refactorings. The MVP ships four checks:

- `Llamex.Check.NoOneLiners`
- `Llamex.Check.NoAdHocAshQueries`
- `Llamex.Check.ConsistentInterfaces`
- `Llamex.Check.NoDBWorkInMemory`

The checks prioritize detection and useful messages. They do not perform
automatic fixes.

## Installation

Add `llamex` to your dependencies:

```elixir
def deps do
  [
    {:llamex, "~> 0.1.0", only: [:dev, :test], runtime: false}
  ]
end
```

Then enable the checks in `.credo.exs`:

```elixir
%{
  configs: [
    %{
      name: "default",
      requires: ["./deps/llamex/lib/llamex/check/**/*.ex"],
      checks: [
        {Llamex.Check.NoOneLiners, []},
        {Llamex.Check.NoAdHocAshQueries, []},
        {Llamex.Check.ConsistentInterfaces, []},
        {Llamex.Check.NoDBWorkInMemory, []}
      ]
    }
  ]
}
```

## Checks

### NoOneLiners

Default severity: error-level priority.

Flags redundant wrapper functions where the body only delegates to another
function, assigns a delegated value and returns it, or ignores a helper result
before returning a synthetic success tuple.

It skips guarded or pattern-narrowing heads, rescue/catch/after bodies, and
boundary callbacks such as `handle_event/3`, `handle_call/3`, `handle_info/2`,
`handle_params/3`, and other `handle_*` functions.

Default message:

```text
Redundant one-line wrapper. Replace with direct call
```

### NoAdHocAshQueries

Default severity: warning.

Flags direct `Ash`, `Ash.Query`, and `Ash.Changeset` APIs in ordinary
application modules, plus domain interface calls with inline ad-hoc query
options such as `load`, `offset`, `limit`, `filter`, `sort`, `query`, and
`page`.

It allows aggregate terminals such as `Ash.count!/1` and Ash implementation
modules that `use Ash.Resource.*` or similar extension points.

Default message:

```text
Avoid ad-hoc queries. Use domain interfaces instead
```

### ConsistentInterfaces

Default severity: warning.

Flags Ash domain `define` declarations where the interface name differs from the
referenced action name.

Default message:

```text
Keep interface names consistent with action names. Avoid redundant arg passing
```

### NoDBWorkInMemory

Default severity: error-level priority for proven local origins.

Flags `Enum`, `List`, and `Stream` collection work when the collection can be
traced back to an Ash-style domain interface or direct Ash read in the current
file. Findings include the traced origin.

Use this module attribute to opt out when whole-dataset in-memory work is
intentional:

```elixir
@llamex_db_work_in_memory_allowed true
```

Credo's existing inline disable comments can also suppress findings.

Default message:

```text
Do not operate on the whole dataset in memory. Use DB queries via resources
```

## Confidence Model

Llamex classifies findings conservatively:

- `:proven` means the source is known from local AST or reliable metadata.
- `:likely` means the issue is strongly indicated through simple inference.
- `:possible` means there is a plausible path but incomplete information.

The current MVP implements proven local detection and conservative AST-only
heuristics. It fails soft when Ash/Spark metadata is unavailable.

## Known Limitations

- Cross-file tracing is intentionally shallow in the MVP.
- Dynamic dispatch, generated code, and complex macro expansion may be skipped.
- Ash classification is AST-first and does not require loading a full project
  index.
- Checks do not rewrite code.
