defmodule Uno.Model.Player do
  @moduledoc false
  defstruct name: nil, deck: [Uno.Model.Card], uno_called: false

  alias Uno.Model.{Card, Player, GameState}

  def call_uno(%Player{} = p), do: %Player{p | uno_called: true}

  def use_card(%Player{} = player, %Card{} = card, discard_pile, %GameState{} = gs) do
    if not playable?(card, discard_pile) do
      {:error, :invalid_move}
    else
      gs2 = apply_effect(card, gs)
      update_gs(player, card, discard_pile, gs2)
    end
  end

  defp update_gs(%Player{} = player, %Card{effect: :skip} = card, discard_pile, %GameState{} = gs) do
    new_discard = [card | discard_pile]
    new_player = %Player{player | deck: List.delete(player.deck, card), uno_called: false}

    new_gs =
      gs
      |> GameState.update_current_player(new_player)
      |> Map.put(:discard_pile, new_discard)
      |> GameState.next_turn()
      |> GameState.next_turn()

    {:ok, new_player, new_discard, new_gs}
  end

  defp update_gs(%Player{} = player, %Card{} = card, discard_pile, %GameState{} = gs) do
    new_discard = [card | discard_pile]
    new_player = %Player{player | deck: List.delete(player.deck, card), uno_called: false}
    new_gs =
      gs
      |> GameState.update_current_player(new_player)
      |> Map.put(:discard_pile, new_discard)
      |> GameState.next_turn()

    {:ok, new_player, new_discard, new_gs}
  end

  defp apply_effect(%Card{effect: :reverse} = card, %GameState{} = gs), do: Card.handle_effect(card, gs)
  defp apply_effect(_card, %GameState{} = gs), do: gs

  defp playable?(%Card{effect: effect} = card, discard_pile) do
    case effect do
      :wild -> true
      :wild_draw_four -> true
      :skip -> Card.same_color?(card, discard_pile)
      :reverse -> Card.same_color?(card, discard_pile)
      _ -> Card.same_color?(card, discard_pile) or Card.same_number?(card, discard_pile)
    end
  end

  defp next_index(gs = %GameState{}), do: Integer.mod(gs.token_index + gs.direction, length(gs.players))

  def is_win(%Player{deck: deck}), do: deck == []
end
