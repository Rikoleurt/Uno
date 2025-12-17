defmodule Uno.Model.Player do
  @moduledoc false
  defstruct name: nil, deck: [Uno.Model.Card], uno_called: false

  alias Uno.Model.{Card, Player, Turn}

  def call_uno(%Player{} = p), do: %Player{p | uno_called: true}

  def use_card(%Player{} = player, %Card{} = card, discard_pile, %Turn{} = turn) do
    if not playable?(card, discard_pile) do
      {:error, :invalid_move}
    else
      new_discard = [card | discard_pile]
      new_player = %Player{player | deck: List.delete(player.deck, card), uno_called: false}

      new_turn = turn
        |> Turn.update_current_player(new_player)
        |> Map.put(:discard_pile, new_discard)
        |> Turn.next_turn()

      {:ok, new_player, new_discard, new_turn}
    end
  end


  defp playable?(%Card{effect: effect} = card, discard_pile) do
    case effect do
      :wild -> true
      :wild_draw_four -> true
      _ -> Card.same_color?(card, discard_pile) or Card.same_number?(card, discard_pile)
    end
  end

  defp advance(%Turn{} = turn, steps), do: Enum.reduce(1..steps, turn, fn _, acc -> Turn.next_turn(acc) end)

  defp next_index(%Turn{} = turn) do
    Integer.mod(turn.token_index + turn.direction, length(turn.players))
  end

  def is_win(deck) do
    length(deck) == 0
  end
end
