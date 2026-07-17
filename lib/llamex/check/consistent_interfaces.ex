defmodule Llamex.Check.ConsistentInterfaces do
  @moduledoc """
  Flags Ash domain interface declarations whose names drift from referenced actions.
  """

  use Credo.Check,
    base_priority: :normal,
    category: :warning,
    explanations: [
      check: "Flags Ash code interfaces whose names and action declarations are inconsistent."
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.AST

  @message "Keep interface names consistent with action names. Avoid redundant arg passing"

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> AST.ast()
    |> AST.walk(&interface_issue(&1, issue_meta))
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
