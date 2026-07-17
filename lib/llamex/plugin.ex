defmodule Llamex.Plugin do
  @moduledoc """
  Credo plugin entry point for enabling the full Llamex check suite.

  Individual `Llamex.Check.*` modules remain normal Credo checks and can be
  enabled directly when a project only wants part of the suite.
  """

  import Credo.Plugin

  @config_file Path.join([__DIR__, "plugin", ".credo.exs"]) |> File.read!()

  @doc false
  def init(exec) do
    register_default_config(exec, @config_file)
  end
end
