defmodule UnoTest do
  use ExUnit.Case
  doctest Uno

  test "greets the world" do
    assert Uno.hello() == :world
  end
end
