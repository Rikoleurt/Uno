defmodule Uno.Model.Player do
  @moduledoc false
  defstruct name: nil, deck: [Uno.Model.Card]

  alias Uno.Model.{Card, Player, Turn}

  def new(name, deck) do
    %__MODULE__{
      name: name,
      deck: deck
    }
  end

  def shuffle(list), do: Enum.shuffle(list)

  def pick_cards(deck, stack, n) when n > 0 do
    picked = Enum.take(stack, n)
    remaining_stack = Enum.drop(stack, n)
    new_deck = deck ++ picked
    {new_deck, remaining_stack}
  end

  def use_card(%Player{deck: deck} = player, %Card{effect: effect} = card, discard_pile, %Turn{} = turn_manager) do
    playable? =
      case effect do
        :wild -> true
        :wild_draw_four -> true
        _ ->
          Card.same_color?(card, discard_pile) or Card.same_number?(card, discard_pile)
      end

    if not playable? do
      IO.puts("error")
      {:error, :invalid_move}
    else
      {new_turn_manager, new_discard_pile} =
        case effect do
          :wild ->
            # handle_wild_card()
            {turn_manager, [card | discard_pile]}
          :wild_draw_four ->
            # handle_wild_color() + add 4 to next player
            {turn_manager, [card | discard_pile]}
          _ ->
            tm = Card.handle_effect(card, turn_manager)
            {tm, [card | discard_pile]}
        end
      new_player = %Player{player | deck: deck -- [card]}
      {:ok, new_player, new_discard_pile, new_turn_manager}
    end
  end

  def is_win(deck) do
    length(deck) == 0
  end

  def uno?(deck) do
    length(deck) == 2
  end

  # When using a card, must check if :
  # 1. the number is superior or equal
  # 2. the color is the same
  # 3. the number is equal => Color change
  # 4. it is a wild card
  # 5. it is an action card
end
