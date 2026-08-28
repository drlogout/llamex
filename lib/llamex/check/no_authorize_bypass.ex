defmodule Llamex.Check.NoAuthorizeBypass do
  @moduledoc """
  Flags `authorize?: false` in Ash action calls and code interface invocations.
  """

  use Credo.Check,
    base_priority: :high,
    category: :warning,
    param_defaults: [skip_tests: true],
    explanations: [
      check: """
      Calls outside an Ash implementation must receive the actor that started the
      operation. System-initiated calls must pass a named system actor instead of
      `authorize?: false`.

      This check flags calls outside documented Ash implementation modules that
      pass `authorize?: false` as a keyword option. Exemptions apply only to the
      module containing the call, not to sibling modules in the same file.

      Remove `authorize?: false` and pass the real actor. For system-initiated
      actions, pass `actor: %{system: :job_name}` or a similar system marker.
      """,
      params: [
        skip_tests:
          "When true, files under `test/`, `*_test.exs` files, and files under `lib/mix/tasks/` are skipped."
      ]
    ]

  alias Credo.IssueMeta
  alias Llamex.Analysis.{Ash, AST, Source}

  @message "Do not use authorize?: false. Pass the actor that started the call, or actor: %{system: name} for system-initiated actions"

  @impl true
  def run(source_file, params \\ []) do
    if Source.skip_tests?(source_file, params, __MODULE__) do
      []
    else
      ast = AST.ast(source_file)
      issue_meta = IssueMeta.for(source_file, params)

      AST.walk_with_ancestors(ast, &authorize_bypass_issue(&1, &2, issue_meta))
    end
  end

  defp authorize_bypass_issue(node, ancestors, issue_meta) do
    module_uses = AST.enclosing_module_uses(ancestors)

    if Ash.authorize_false?(node) and
         not Ash.authorization_implementation_module?(module_uses) do
      call = AST.call_identity(node)

      format_issue(issue_meta,
        message: @message,
        trigger: call && call.trigger,
        line_no: call && call.line
      )
    end
  end
end
