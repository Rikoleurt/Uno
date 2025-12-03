defmodule Uno.Model.Turn do
  defstruct players: [], discard_pile: [], token_index: 0, direction: 1
  @moduledoc false

  alias Uno.Model.Card
  alias Uno.Model.Player
  alias Uno.Model.Turn

  def new(players) do
    deck = Card.create_card_set() |> Enum.shuffle()

    %__MODULE__{
      players: players,
      discard_pile: deck,
      token_index: 0,
      direction: 1
    }
  end

  def distribute(players, cards, 0), do: {players, cards}
  def distribute(players, cards, n) when n > 0 do
    {players_after_round, remaining_cards} = deal_round(players, cards)
    distribute(players_after_round, remaining_cards, n - 1)
  end

  defp deal_round([], cards), do: {[], cards}
  defp deal_round(players, []), do: {players, []}
  defp deal_round([%Player{deck: deck} = player | rest_players], [card | rest_cards]) do
    updated_player = %Player{player | deck: [card | deck]}
    {updated_rest_players, remaining_cards} = deal_round(rest_players, rest_cards)
    {[updated_player | updated_rest_players], remaining_cards}
  end

  def next_turn(%__MODULE__{players: players, token_index: index, direction: dir} = turn) do
    player_count = length(players)
    new_index = Integer.mod(index + dir, player_count)
    %__MODULE__{turn | token_index: new_index}
  end

  def handle_turn(player, card) do
    Player.use_card(player.deck, card, Turn.discard_pile)
    if Player.is_win(player.deck) do
      :stop
    else
      :continue
    end
  end

  def traverse_player([h]), do: h
  def traverse_player([_ | t]) do
    traverse_player(t)
  end

end
