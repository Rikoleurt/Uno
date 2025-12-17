defmodule Uno.Model.Player do
  @moduledoc false
  defstruct name: nil, deck: [Uno.Model.Card], uno_called: false

  alias Uno.Model.{Card, Player, GameState}

  def call_uno(%Player{} = p), do: %Player{p | uno_called: true}

  def use_card(%Player{} = player, %Card{} = card, discard_pile, %GameState{} = gs) do
    if not playable?(card, discard_pile) do
      {:error, :invalid_move}
    else
      new_discard = [card | discard_pile]
      new_player = %Player{player | deck: List.delete(player.deck, card), uno_called: false}

      new_gs =
        gs
        |> GameState.update_current_player(new_player)
        |> Map.put(:discard_pile, new_discard)
        |> GameState.next_turn()

      {:ok, new_player, new_discard, new_gs}
    end
  end


  defp playable?(%Card{effect: effect} = card, discard_pile) do
    case effect do
      :wild -> true
      :wild_draw_four -> true
      _ -> Card.same_color?(card, discard_pile) or Card.same_number?(card, discard_pile)
    end
  end

  defp next_index(gs = %GameState{}), do: Integer.mod(gs.token_index + gs.direction, length(gs.players))

  def is_win(%Player{deck: deck}), do: deck == []
end
