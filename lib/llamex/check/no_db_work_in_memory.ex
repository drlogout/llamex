defmodule Llamex.Check.NoDBWorkInMemory do
  @moduledoc """
  Flags in-memory collection work on values that appear to originate from Ash reads.
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    explanations: [
      check: "Flags Enum/List work over values traced back to Ash domain interfaces or reads."
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.{Ash, AST}

  @message "Do not operate on the whole dataset in memory. Use DB queries via resources"

  @impl true
  def run(source_file, params \\ []) do
    ast = AST.ast(source_file)

    if AST.opt_out?(ast, :llamex_db_work_in_memory_allowed) do
      []
    else
      issue_meta = IssueMeta.for(source_file, params)
      aliases = AST.aliases(ast)
      functions = AST.functions(ast)
      helper_returns = helper_returns(functions)

      functions
      |> Enum.flat_map(&issues_for_function(&1, aliases, helper_returns, issue_meta))
      |> Enum.uniq_by(&{&1.line_no, &1.trigger})
    end
  end

  defp issues_for_function(function, aliases, helper_returns, issue_meta) do
    assignments = assignments(function.do_block)

    AST.walk(function.do_block, fn node ->
      collection_issue(
        node,
        collection_input(node),
        assignments,
        helper_returns,
        aliases,
        issue_meta
      )
    end)
  end

  defp collection_issue(_node, nil, _assignments, _helper_returns, _aliases, _issue_meta), do: nil

  defp collection_issue(node, input, assignments, helper_returns, aliases, issue_meta) do
    case trace_origin(input, assignments, helper_returns, aliases, 0) do
      {:ok, origin} -> issue_for(node, origin, issue_meta)
      :unknown -> nil
    end
  end

  defp collection_input({:|>, _, [input, right]}) do
    if AST.collection_call?(right), do: AST.innermost_pipe_input(input)
  end

  defp collection_input(node) do
    case AST.call_identity(node) do
      %{module: module, args: [input | _]} when module in [Enum, List, Stream] ->
        input

      _ ->
        nil
    end
  end

  defp assignments(body) do
    body
    |> AST.block_expressions()
    |> Enum.reduce(%{}, fn
      {:=, _, [left, right]}, acc ->
        case AST.variable_name(left) do
          nil -> acc
          name -> Map.put(acc, name, right)
        end

      _other, acc ->
        acc
    end)
  end

  defp helper_returns(functions) do
    Map.new(functions, fn function ->
      {function.name, last_expression(function.do_block)}
    end)
  end

  defp last_expression(body) do
    body
    |> AST.block_expressions()
    |> List.last()
  end

  defp trace_origin(_input, _assignments, _helper_returns, _aliases, depth) when depth > 4,
    do: :unknown

  defp trace_origin({:|>, _, [input, right]}, assignments, helper_returns, aliases, depth) do
    if Ash.db_origin_call?(right, aliases) do
      {:ok, AST.call_to_string(right)}
    else
      trace_origin(input, assignments, helper_returns, aliases, depth + 1)
    end
  end

  defp trace_origin(input, assignments, helper_returns, aliases, depth) do
    cond do
      Ash.db_origin_call?(input, aliases) ->
        {:ok, AST.call_to_string(input)}

      variable = AST.variable_name(input) ->
        case Map.fetch(assignments, variable) do
          {:ok, expression} ->
            trace_origin(expression, assignments, helper_returns, aliases, depth + 1)

          :error ->
            :unknown
        end

      local_call = local_call_name(input) ->
        case Map.fetch(helper_returns, local_call) do
          {:ok, expression} ->
            trace_origin(expression, assignments, helper_returns, aliases, depth + 1)

          :error ->
            :unknown
        end

      true ->
        :unknown
    end
  end

  defp local_call_name({name, _, args}) when is_atom(name) and is_list(args), do: name
  defp local_call_name(_), do: nil

  defp issue_for(node, origin, issue_meta) do
    call = AST.call_identity(collection_call_node(node))

    format_issue(issue_meta,
      message: "#{@message}. Traced path: #{origin}",
      trigger: call && call.trigger,
      line_no: call && call.line
    )
  end

  defp collection_call_node({:|>, _, [_input, right]}), do: right
  defp collection_call_node(node), do: node
end
