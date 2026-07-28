defmodule Llamex.Check.NoAdHocAshQueries do
  @moduledoc """
  Flags ad-hoc Ash query and changeset construction outside Ash implementation modules.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    param_defaults: [skip_tests: true],
    explanations: [
      check: """
      Ash projects should route application code through domain code interfaces instead of
      constructing ad-hoc queries and changesets at call sites.

      This check flags direct calls such as `Ash.Query.for_read/2`,
      `Ash.Changeset.for_create/3`, `Ash.read!/1`, `Ash.create!/1`, and domain
      interface calls that pass inline query-shaping options like `load`,
      `filter`, `sort`, or `query`. Pagination options (`page`, `limit`,
      `offset`) are allowed — paging at call time is Ash's designed API.

      Move the query/action shape into the Ash resource action or domain interface,
      then call that interface from web, worker, and application modules. Ash
      modules (`use Ash.*`) are excluded. Aggregate terminal calls like
      `Ash.count!/1` are allowed.
      """,
      params: [
        skip_tests:
          "When true, files under `test/`, `*_test.exs` files, and files under `lib/mix/tasks/` are skipped."
      ]
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.{Ash, AST, Source}

  @message "Avoid ad-hoc queries. Use domain interfaces instead"

  @impl true
  def run(source_file, params \\ []) do
    if Source.skip_tests?(source_file, params, __MODULE__) do
      []
    else
      ast = AST.ast(source_file)

      if Ash.ash_implementation_module?(ast) do
        []
      else
        ast
        |> AST.walk(&ad_hoc_issue(&1, IssueMeta.for(source_file, params)))
      end
    end
  end

  defp ad_hoc_issue(node, issue_meta) do
    cond do
      Ash.aggregate_call?(node) ->
        nil

      Ash.direct_ad_hoc_call?(node) or Ash.domain_interface_with_ad_hoc_options?(node) ->
        issue_for(node, issue_meta)

      true ->
        nil
    end
  end

  defp issue_for(node, issue_meta) do
    call = AST.call_identity(node)

    format_issue(issue_meta,
      message: @message,
      trigger: call && call.trigger,
      line_no: call && call.line
    )
  end
end
