defmodule Uno.TokenRing.Bootstrap do
  alias Uno.Model.{Turn, Player}

  # players_specs = [{"Alice", :"alice@127.0.0.1"}, {"Bob", :"bob@127.0.0.1"}, ...]
  def start_players(players_specs) do
    Enum.each(players_specs, fn {name, node} ->
      :rpc.call(node, Uno.TokenRing.PlayerServer, :start_link, [name])
    end)
  end

  def start_game(%Turn{} = turn) do
    first = Turn.current_player(turn).name
    Uno.TokenRing.PlayerServer.inject_token(first, turn)
  end
end

