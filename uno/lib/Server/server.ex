defmodule Uno.GameServer do
  use GenServer

  # API publique

  def start_link(game_id) when is_binary(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via_tuple(game_id))
  end

  def join(game_id, player_name) do
    GenServer.call(via_tuple(game_id), {:join, player_name})
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  # Registry pour retrouver le process par game_id
  defp via_tuple(game_id), do: {:via, Registry, {Uno.GameRegistry, game_id}}

  # Callbacks

  @impl true
  def init(game_id) do
    state = %{
      game_id: game_id,
      players: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, player_name}, _from, state) do
    if player_name in state.players do
      {:reply, {:error, :already_joined}, state}
    else
      new_state = %{state | players: [player_name | state.players]}
      {:reply, {:ok, new_state}, new_state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end
end
