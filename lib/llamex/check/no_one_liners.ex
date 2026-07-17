defmodule Llamex.Check.NoOneLiners do
  @moduledoc """
  Flags redundant wrapper functions that only delegate or wrap a delegated result.
  """

  use Credo.Check,
    base_priority: :high,
    category: :refactor,
    explanations: [
      check: "Flags redundant wrapper functions introduced by mechanical refactors."
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.AST

  @message "Redundant one-line wrapper. Replace with direct call"

  @impl true
  def run(source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    source_file
    |> AST.ast()
    |> AST.functions()
    |> Enum.filter(&redundant_wrapper?/1)
    |> Enum.map(&issue_for(&1, issue_meta))
  end

  defp redundant_wrapper?(%{name: name, head: head, args: args, body: body} = function)
       when is_atom(name) do
    not boundary_callback?(name) and
      not AST.function_has_guard?(head) and
      not AST.meaningful_pattern_args?(args) and
      not AST.function_body_has_rescue?(body) and
      trivial_body?(function)
  end

  defp redundant_wrapper?(_), do: false

  defp trivial_body?(%{do_block: body}) do
    case AST.block_expressions(body) do
      [call] ->
        remote_or_local_call?(call)

      [{:=, _, [left, right]}, {:ok, returned}] ->
        not is_nil(AST.variable_name(left)) and remote_or_local_call?(right) and
          AST.same_variable?(returned, AST.variable_name(left))

      [call, {:ok, _ignored}] ->
        remote_or_local_call?(call)

      _ ->
        false
    end
  end

  defp remote_or_local_call?(node) do
    case AST.call_identity(node) do
      %{function: function} when function in [:__aliases__, :{}] -> false
      %{function: function} when is_atom(function) -> true
      _ -> false
    end
  end

  defp boundary_callback?(name),
    do:
      name in [:handle_event, :handle_call, :handle_info, :handle_params] or
        String.starts_with?(Atom.to_string(name), "handle_")

  defp issue_for(%{name: name, line: line}, issue_meta) do
    format_issue(issue_meta,
      message: @message,
      trigger: Atom.to_string(name),
      line_no: line
    )
  end
end
