defmodule Uno.Model.GameState do
  @moduledoc false
  defstruct players: [], draw_pile: [], discard_pile: [], token_index: 0, direction: 1, must_draw: 0

  alias Uno.Model.{Card, Player}

  def new(players) do
    cards = Card.create_card_set() |> Enum.shuffle()
    {players, cards} = distribute(players, cards, 3)
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

  def next_turn(%__MODULE__{players: players, token_index: index, direction: dir} = gs) do
    new_index = Integer.mod(index + dir, length(players))
    %__MODULE__{gs | token_index: new_index}
  end

  def update_player_at(%__MODULE__{} = gs, index, %Player{} = player) do
    %__MODULE__{gs | players: List.replace_at(gs.players, index, player)}
  end

  def update_current_player(%__MODULE__{} = gs, %Player{} = player) do
    update_player_at(gs, gs.token_index, player)
  end

  def draw_cards(%__MODULE__{} = gs, n) when n > 0 do
    {picked, rest} = Enum.split(gs.draw_pile, n)
    {picked, %__MODULE__{gs | draw_pile: rest}}
  end

  def distribute(players, cards, 0), do: {players, cards}
  def distribute(players, cards, n) when n > 0 do
    {new_players, remaining_cards} = deal_cards(players, cards)
    distribute(new_players, remaining_cards, n - 1)
  end

  defp deal_cards([], cards), do: {[], cards}
  defp deal_cards(players, []), do: {players, []}
  defp deal_cards([%Player{deck: deck} = player | rest_players], [card | rest_cards]) do
    updated_player = %Player{player | deck: [card | deck]}
    {updated_rest_players, remaining_cards} = deal_cards(rest_players, rest_cards)
    {[updated_player | updated_rest_players], remaining_cards}
  end
end
