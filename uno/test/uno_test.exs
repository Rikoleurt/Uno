defmodule UnoTest do
  use ExUnit.Case
  doctest Uno

  test "pick card" do
    IO.puts("------------- Pick Card -------------")
    set = Uno.Model.Player.shuffle(Uno.Model.Card.create_card_set)
    deck = []
    IO.inspect(Uno.Model.Player.pick_cards(deck, set, 2))
  end

  test "use card" do
    IO.puts "------------- Use Card -------------"
    set = Uno.Model.Player.shuffle(Uno.Model.Card.create_card_set)
    deck = [
      %Uno.Model.Card{number: 7, color: :green, effect: nil},
      %Uno.Model.Card{number: 2, color: :yellow, effect: nil}
    ]
    IO.inspect Uno.Model.Player.use_card(deck, hd(deck), set)
  end
end

