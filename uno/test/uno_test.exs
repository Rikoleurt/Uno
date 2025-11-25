defmodule UnoTest do
  use ExUnit.Case
  doctest Uno

  test "greets the world" do
    assert Uno.hello() == :world
  end

  test "token" do
    assert Uno.test() == :ok
  end

  test "ok/0 returns :ok" do
    assert Uno.Model.Player.ok() == :ok
  end
end

