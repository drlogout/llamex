defmodule Llamex.Check.ConsistentInterfaces do
  @moduledoc """
  Flags Ash domain interface declarations whose names drift from referenced actions.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    param_defaults: [skip_tests: true],
    explanations: [
      check: """
      Ash domain code interfaces are the public API for resource actions. When an
      interface name drifts away from the action it calls, callers have to learn
      two vocabularies for the same operation and generated API surfaces become
      harder to audit.

      This check flags `define` declarations where the interface name differs
      from the referenced action name, for example `define :list_cards,
      action: :search_cards`.

      Prefer naming the interface after the action, or rename the resource action
      if the interface name is the better domain term. The check does not rewrite
      declarations because the right fix is a domain naming decision.
      """,
      params: [
        skip_tests:
          "When true, files under `test/`, `*_test.exs` files, and files under `lib/mix/tasks/` are skipped."
      ]
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.{AST, Source}

  @message "Keep interface names consistent with action names. Avoid redundant arg passing"

  @impl true
  def run(source_file, params \\ []) do
    if Source.skip_tests?(source_file, params, __MODULE__) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)

      source_file
      |> AST.ast()
      |> AST.walk(&interface_issue(&1, issue_meta))
    end
  end

  defp interface_issue({:define, meta, [interface, opts]}, issue_meta)
       when is_atom(interface) and is_list(opts) do
    maybe_issue(interface, Keyword.get(opts, :action), meta[:line], issue_meta)
  end

  defp interface_issue({:define, meta, [interface, [do: block]]}, issue_meta)
       when is_atom(interface) do
    action =
      block
      |> AST.block_expressions()
      |> Enum.find_value(fn
        {:action, _meta, [action]} when is_atom(action) -> action
        _ -> nil
      end)

    maybe_issue(interface, action, meta[:line], issue_meta)
  end

  defp interface_issue(_, _), do: nil

  defp maybe_issue(interface, action, _line, _issue_meta)
       when is_nil(action) or interface == action do
    nil
  end

  defp maybe_issue(interface, action, line, issue_meta) do
    format_issue(issue_meta,
      message:
        "#{@message}: interface #{inspect(interface)} references action #{inspect(action)}",
      trigger: Atom.to_string(interface),
      line_no: line
    )
  end
end
