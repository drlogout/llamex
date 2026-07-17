defmodule Llamex.Analysis.Source do
  @moduledoc false

  alias Credo.Check.Params
  alias Credo.SourceFile

  def skip_tests?(%SourceFile{filename: filename}, params, check) do
    Params.get(params, :skip_tests, check) and skipped_file?(filename)
  end

  def skipped_file?(filename), do: test_file?(filename) or mix_task_file?(filename)

  def test_file?(filename) when is_binary(filename) do
    normalized = String.replace(filename, "\\", "/")

    String.starts_with?(normalized, "test/") or
      String.contains?(normalized, "/test/") or
      String.ends_with?(normalized, "_test.exs")
  end

  def test_file?(_filename), do: false

  def mix_task_file?(filename) when is_binary(filename) do
    normalized = String.replace(filename, "\\", "/")

    String.contains?(normalized, "/mix/tasks/") or
      String.starts_with?(normalized, "lib/mix/tasks/") or
      String.starts_with?(normalized, "mix/tasks/")
  end

  def mix_task_file?(_filename), do: false
end
