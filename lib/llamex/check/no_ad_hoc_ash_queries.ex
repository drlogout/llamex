defmodule Llamex.Check.NoAdHocAshQueries do
  @moduledoc """
  Flags ad-hoc Ash query and changeset construction outside Ash implementation modules.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: "Flags direct Ash query/change APIs where domain interfaces should be used."
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.{Ash, AST}

  @message "Avoid ad-hoc queries. Use domain interfaces instead"

  @impl true
  def run(source_file, params \\ []) do
    ast = AST.ast(source_file)

    if Ash.ash_implementation_module?(ast) do
      []
    else
      ast
      |> AST.walk(&ad_hoc_issue(&1, IssueMeta.for(source_file, params)))
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
