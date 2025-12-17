defmodule Uno.TokenRing.Bootstrap do
  alias Uno.Model.{GameState, Player}

  # players_specs = [{"Alice", :"alice@127.0.0.1"}, {"Bob", :"bob@127.0.0.1"}, ...]
  def start_players(players_specs) do
    Enum.each(players_specs, fn {name, node} ->
      :rpc.call(node, Uno.TokenRing.PlayerServer, :start_link, [name])
    end)
  end

  def start_game(gs = %GameState{}) do
    first = GameState.current_player(gs).name
    Uno.TokenRing.PlayerServer.inject_token(first, gs)
  end
end

