defmodule Uno.Model.Player do
  @moduledoc false
  defstruct [Uno.Model.Card]

  def shuffle(list), do: Enum.shuffle(list)

  def pick_cards(deck, stack, n) when n > 0 do
    picked = Enum.take(stack, n)
    remaining_stack = Enum.drop(stack, n)
    new_deck = deck ++ picked
    {new_deck, remaining_stack}
  end

  def use_card(deck, card, stack) do
    new_deck = deck -- [card]
    new_stack = [card | stack]
    {new_deck, new_stack}
  end

end
