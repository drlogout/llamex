defmodule Llamex do
  @moduledoc """
  Credo checks for issues commonly introduced by LLM-assisted Elixir refactors.
  """

  @checks [
    Llamex.Check.NoOneLiners,
    Llamex.Check.NoAdHocAshQueries,
    Llamex.Check.ConsistentInterfaces,
    Llamex.Check.NoDBWorkInMemory
  ]

  @doc "Returns all checks shipped by Llamex."
  def checks, do: @checks
end
