defmodule Uno.Model.Turn do
  @moduledoc false
  defstruct players: [], draw_pile: [], discard_pile: [], token_index: 0, direction: 1

  alias Uno.Model.{Card, Player}

  def new(players) do
    cards = Card.create_card_set() |> Enum.shuffle()
    {players, cards} = distribute(players, cards, 1)

    [first | rest] = cards

    %__MODULE__{
      players: players,
      draw_pile: rest,
      discard_pile: [first],
      token_index: 0,
      direction: 1
    }
  end

  def current_player(%__MODULE__{players: players, token_index: index}), do: Enum.at(players, index)

  def next_turn(%__MODULE__{players: players, token_index: index, direction: dir} = turn) do
    new_index = Integer.mod(index + dir, length(players))
    %__MODULE__{turn | token_index: new_index}
  end

  def update_player_at(%__MODULE__{} = turn, index, %Player{} = player) do
    %__MODULE__{turn | players: List.replace_at(turn.players, index, player)}
  end

  def update_current_player(%__MODULE__{} = turn, %Player{} = player) do
    update_player_at(turn, turn.token_index, player)
  end

  def draw_cards(%__MODULE__{} = turn, n) when n > 0 do
    {picked, rest} = Enum.split(turn.draw_pile, n)
    {picked, %__MODULE__{turn | draw_pile: rest}}
  end

  def set_direction(%__MODULE__{} = turn, direction), do: %__MODULE__{turn | direction: direction}
  def set_index(%__MODULE__{} = turn, index), do: %__MODULE__{turn | token_index: index}

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
end
