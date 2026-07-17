defmodule Llamex.Analysis.Ash do
  @moduledoc false

  alias Llamex.Analysis.AST

  @implementation_prefixes [
    "Ash.Resource.",
    "Ash.Policy.",
    "Ash.Query.",
    "Ash.Changeset."
  ]

  @aggregate_functions [:count, :count!, :sum, :sum!, :avg, :avg!, :min, :min!, :max, :max!]

  @direct_execution_functions [
    :read,
    :read!,
    :create,
    :create!,
    :update,
    :update!,
    :destroy,
    :destroy!,
    :bulk_create,
    :bulk_create!,
    :bulk_update,
    :bulk_update!,
    :bulk_destroy,
    :bulk_destroy!,
    :get,
    :get!,
    :load,
    :load!
  ]

  @ad_hoc_option_keys [:load, :offset, :limit, :filter, :filters, :sort, :query, :page]

  def ash_implementation_module?(ast) do
    ast
    |> AST.module_uses()
    |> Enum.any?(fn
      "Ash.Domain" -> false
      use_name -> Enum.any?(@implementation_prefixes, &String.starts_with?(use_name, &1))
    end)
  end

  def direct_ad_hoc_call?(node) do
    case AST.call_identity(node) do
      %{module_name: "Ash", function: function} ->
        function in @direct_execution_functions

      %{module_name: module_name, function: function}
      when module_name in ["Ash.Query", "Ash.Changeset"] ->
        not harmless_changeset_or_query_call?(function)

      _ ->
        false
    end
  end

  def aggregate_call?(node) do
    case AST.call_identity(node) do
      %{module_name: "Ash", function: function} -> function in @aggregate_functions
      _ -> false
    end
  end

  def domain_interface_with_ad_hoc_options?(node) do
    case AST.call_identity(node) do
      %{module_name: module_name, args: args} when is_binary(module_name) ->
        not AST.ash_module_name?(module_name) and Enum.any?(args, &ad_hoc_options?/1)

      _ ->
        false
    end
  end

  def db_origin_call?(node, aliases \\ %{}) do
    case AST.call_identity(node) do
      %{module: module, function: function} when not is_nil(module) ->
        db_origin_for?(AST.resolve_alias(module, aliases), function)

      _ ->
        false
    end
  end

  defp db_origin_for?(module, function) do
    module_name = inspect(module)

    cond do
      AST.ash_module_name?(module_name) and
          function in [:read, :read!, :create, :create!, :update, :update!] ->
        true

      String.contains?(module_name, ".") and db_style_function?(function) ->
        true

      true ->
        false
    end
  end

  def ad_hoc_options?(opts) when is_list(opts) do
    Keyword.keyword?(opts) and Enum.any?(@ad_hoc_option_keys, &Keyword.has_key?(opts, &1))
  end

  def ad_hoc_options?(_), do: false

  defp harmless_changeset_or_query_call?(function) do
    function in [
      :get_attribute,
      :get_argument,
      :force_change_attribute,
      :change_attribute,
      :set_context
    ]
  end

  defp db_style_function?(function) do
    name = Atom.to_string(function)

    String.starts_with?(name, "list_") or
      String.starts_with?(name, "get_") or
      String.starts_with?(name, "read_") or
      String.ends_with?(name, "_for_user") or
      String.contains?(name, "records") or
      String.contains?(name, "books") or
      String.ends_with?(name, "!")
  end
end
