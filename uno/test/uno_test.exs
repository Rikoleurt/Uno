defmodule UnoTest do
  use ExUnit.Case, async: true
  doctest Uno
  alias Uno.Model.{Card, Player, Turn}

  test "pick card" do
    IO.puts("------------- Pick Card -------------")
    set = Player.shuffle(Card.create_card_set)
    deck = []
    IO.inspect(Player.pick_cards(deck, set, 2))
  end

  test "use card" do
    try do
      IO.puts "------------- Use Card -------------"

      # 1) Add players
      players = [
        %Player{name: "Alice", deck: []},
        %Player{name: "Bob", deck: []},
        %Player{name: "Charlie", deck: []}
      ]

      # 2) Shuffle the cards
      card_set = Player.shuffle(Card.create_card_set())
      discard_pile = [hd(card_set)]

      # 3) Distribution
      {dealt_players, remaining_cards} = Turn.distribute(players, card_set, 7)

      # 4) Add players to the lobby
      turn_manager = %Turn{
        players: dealt_players,
        discard_pile: discard_pile,
        token_index: 0,
        direction: 1
      }

      # 5) First player plays their first card
      first_player = hd(dealt_players)
      deck = first_player.deck
      card_to_play = hd(deck) # <= Should ask which card to play (turn manager)


      {:ok, new_deck, new_discard_pile, new_turn_manager} = Player.use_card(first_player, card_to_play, discard_pile, turn_manager)
      IO.inspect deck, label: "deck"
      IO.inspect(new_deck, label: "new_deck")
      IO.inspect(discard_pile, label: "discard_pile")
      IO.inspect(new_discard_pile, label: "new_discard_pile")
    rescue
      MatchError ->
        IO.puts("Please choose another card")
        #
    end
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

end

