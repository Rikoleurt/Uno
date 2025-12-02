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

  test "access data set" do
    IO.inspect(Uno.Model.Card.create_card_set)
  end

end

