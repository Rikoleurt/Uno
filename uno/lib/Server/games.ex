defmodule Uno.Games do
  @spec start_game(String.t()) :: DynamicSupervisor.on_start_child()
  def start_game(game_id) do
    DynamicSupervisor.start_child(
      Uno.GameSupervisor,
      {Uno.GameServer, game_id}
    )
  end

  def join(game_id, player_name) do
    Uno.GameServer.join(game_id, player_name)
  end

  def get_state(game_id) do
    Uno.GameServer.get_state(game_id)
  end
end
