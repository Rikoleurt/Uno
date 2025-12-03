defmodule Uno.Model.Player do
  @moduledoc false
  defstruct name: nil, deck: [Uno.Model.Card]

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

  def use_card(deck, card, stack = [h | _]) do
    if(card.number == h.number or card.color == h.color) do
      new_deck = deck -- [card]
      new_stack = [card | stack]
      {new_deck, new_stack}
    else
      IO.puts("Can't use this card")
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
