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
    # stack = Uno.Model.Player.shuffle(Uno.Model.Card.create_card_set)
    discard_pile = [%Uno.Model.Card{number: 1, color: :yellow, effect: nil}]
    deck = [
      %Uno.Model.Card{number: 7, color: :green, effect: nil},
      %Uno.Model.Card{number: 2, color: :yellow, effect: nil}
    ]
    IO.inspect Uno.Model.Player.use_card(deck, Enum.at(deck, 1), discard_pile)
  end

  test "next player moves token and wraps around" do
    IO.puts "------------- Next Player -------------"

    players = [
      %Uno.Model.Player{name: "Alice"},
      %Uno.Model.Player{name: "Bob"},
      %Uno.Model.Player{name: "Charlie"}
    ]

    turn = %Uno.Model.Turn{players: players, token_index: 0, direction: 1}

    turn = Uno.Model.Turn.next_turn(turn)
    assert turn.token_index == 1

    turn = Uno.Model.Turn.next_turn(turn)
    assert turn.token_index == 2

    turn = Uno.Model.Turn.next_turn(turn)
    assert turn.token_index == 0
  end

  test "Distribute cards" do
    IO.puts "------------- Distribute Cards -------------"

    card_set = Uno.Model.Player.shuffle(Uno.Model.Card.create_card_set)
    IO.inspect length(card_set)
    players = [
      %Uno.Model.Player{name: "Alice", deck: []},
      %Uno.Model.Player{name: "Bob", deck: []},
      %Uno.Model.Player{name: "Charlie", deck: []},
      %Uno.Model.Player{name: "Daniel", deck: []}
    ]
    {updated_players, remaining_cards} = Uno.Model.Turn.distribute(players, card_set, 7)
    IO.inspect(updated_players, label: " ----- updated players -----")
    IO.inspect(length(remaining_cards), label: " --- remaining cards -----")
  end
end

