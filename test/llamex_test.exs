defmodule LlamexTest do
  use ExUnit.Case
  doctest Llamex

  test "greets the world" do
    assert Llamex.hello() == :world
  end
end
