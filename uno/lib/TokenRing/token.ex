defmodule Uno.TokenRing.Token do
  @moduledoc false
  alias Uno.Model.GameState

  @enforce_keys [:phase, :gs, :origin, :actor, :round_id]
  defstruct [:phase, :gs, :origin, :actor, :round_id]

  @type phase :: :sync | :turn
  @type t :: %__MODULE__{
               phase: phase(),
               gs: %GameState{},
               origin: String.t(),
               actor: String.t(),
               round_id: non_neg_integer()
             }

  def new_sync(%GameState{} = gs, origin, actor, round_id \\ 1) when is_binary(origin) and is_binary(actor) do
    %__MODULE__{phase: :sync, gs: gs, origin: origin, actor: actor, round_id: round_id}
  end

  def to_turn(%__MODULE__{} = token), do: %__MODULE__{token | phase: :turn}

  def sync_next_round(%__MODULE__{} = token, %GameState{} = new_gs, origin, next_actor)
      when is_binary(origin) and is_binary(next_actor) do
    %__MODULE__{
      phase: :sync,
      gs: new_gs,
      origin: origin,
      actor: next_actor,
      round_id: token.round_id + 1
    }
  end
end
