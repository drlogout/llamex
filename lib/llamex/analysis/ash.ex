defmodule Llamex.Analysis.Ash do
  @moduledoc """
  Ash-specific AST classification helpers.

  Each function inspects an AST node and returns whether it matches
  a known Ash call pattern. No runtime Ash/Spark dependency is required.
  """

  alias Llamex.Analysis.AST

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

  # Pagination options (:page, :limit, :offset) are deliberately not
  # listed: passing a page window at call time is Ash's designed
  # pagination API, not ad-hoc query shaping.
  @ad_hoc_option_keys [:load, :filter, :filters, :sort, :query]

  def ash_implementation_module?(ast) do
    ast
    |> AST.module_uses()
    |> Enum.any?(&AST.ash_module_name?/1)
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

  # Returns true when the node is a call that passes `authorize?: false`.
  # Only matches Ash-related calls: direct Ash.* calls, Ash.Query.*,
  # Ash.Changeset.*, or dotted-module domain interface calls.
  def authorize_false?(node) do
    case AST.call_identity(node) do
      %{module_name: module_name, args: args} when is_binary(module_name) ->
        ash_related_module?(module_name) and has_authorize_false?(args)

      _ ->
        false
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
    normalized = String.trim_trailing(name, "!")

    unscoped_collection_name?(normalized) and not scoped_collection_name?(normalized)
  end

  defp unscoped_collection_name?(name) do
    name in ["all", "list", "read"] or
      String.starts_with?(name, "all_") or
      String.starts_with?(name, "list_all") or
      String.starts_with?(name, "get_all") or
      String.starts_with?(name, "read_all") or
      String.ends_with?(name, "_all")
  end

  defp scoped_collection_name?(name) do
    String.contains?(name, "_for_") or
      String.contains?(name, "_by_") or
      String.contains?(name, "_with_")
  end

  # Any remote call (call with a module) can be Ash-related.
  # Single-segment names like `Support` are often aliases for full
  # domain modules like `MyApp.Support`.
  defp ash_related_module?(module_name) do
    is_binary(module_name) and module_name != ""
  end

  defp has_authorize_false?(args) do
    Enum.any?(args, fn
      opts when is_list(opts) ->
        Keyword.keyword?(opts) and Keyword.get(opts, :authorize?) == false

      _ ->
        false
    end)
  end
end
