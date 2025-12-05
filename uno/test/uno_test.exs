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
    IO.puts "------------- Use Card -------------"

    # 1) Création des joueurs (deck vide au début)
    players = [
      %Player{name: "Alice", deck: []},
      %Player{name: "Bob", deck: []},
      %Player{name: "Charlie", deck: []}
    ]

    # 2) Création et mélange du paquet
    card_set = Player.shuffle(Card.create_card_set())

    # Remarque : première carte sur la pile = 1 jaune
    discard_pile = [%Card{number: 1, color: :yellow, effect: nil}]

    # 3) Distribution : chaque joueur reçoit 7 cartes
    {dealt_players, remaining_cards} = Turn.distribute(players, card_set, 7)

    # 4) Création du turn_manager avec les joueurs distribués
    turn_manager = %Turn{
      players: dealt_players,
      discard_pile: discard_pile,
      token_index: 0,
      direction: 1
    }

    # 5) Premier joueur joue la première carte de son deck
    first_player = hd(dealt_players)
    deck = first_player.deck
    card_to_play = hd(deck)

    {:ok, new_deck, new_discard_pile, new_turn_manager} = Player.use_card(deck, card_to_play, discard_pile, turn_manager)

    IO.inspect deck, label: "deck"
    IO.inspect(new_deck, label: "new_deck")
    IO.inspect(discard_pile, label: "discard_pile")
    IO.inspect(new_discard_pile, label: "new_discard_pile")

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

