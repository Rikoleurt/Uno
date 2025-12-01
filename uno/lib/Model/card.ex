defmodule Uno.Model.Card do
  @moduledoc """
  """

  defstruct number: nil, color: nil, effect: nil
  @colors [:red, :yellow, :green, :blue]

  def get_color(%__MODULE__{color: color}) do
    color
  end

  def get_number(%__MODULE__{number: number}) do
    number
  end

  def get_effect(%__MODULE__{effect: effect}) do
    effect
  end

  def new(number, color, effect) do
    %__MODULE__{number: number, color: color, effect: effect}
  end

  defp create_number_cards do
    zeros = for color <- @colors do new(0, color, nil) end
    ones_to_nines = for color <- @colors, number <- 1..9, _ <- 1..2 do
      new(number, color, nil)
    end
    zeros ++ ones_to_nines
  end

  # 24 action card :
  # - 2x Skip, Reverse, Draw Two
  defp create_action_cards do
    for color <- @colors, effect <- [:skip, :reverse, :draw_two], _ <- 1..2 do
      new(nil, color, effect)
    end
  end

  # 8 wild card :
  # - 4x Wild
  # - 4x Wild Draw Four
  defp create_wild_cards do
    for effect <- [:wild, :wild_draw_four], _ <- 1..4 do
      new(nil, :wild, effect)
    end
  end

  def create_card_set do
    number_cards = create_number_cards()
    action_cards = create_action_cards()
    wild_cards   = create_wild_cards()
    number_cards ++ action_cards ++ wild_cards
  end
end
