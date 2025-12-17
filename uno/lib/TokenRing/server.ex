defmodule Uno.TokenRing.PlayerServer do
  @moduledoc false

  use GenServer

  alias Uno.Model.{Turn, Player, Card}

  # -----------------------
  # Public API
  # -----------------------

  def start_link(player_name) when is_binary(player_name) do
    GenServer.start_link(__MODULE__, %{name: player_name}, name: server_ref(player_name))
  end

  def inject_token(player_name, %Turn{} = turn) do
    GenServer.cast(server_ref(player_name), {:token, turn})
  end

  # -----------------------
  # GenServer callbacks
  # -----------------------

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:ready, _from, state), do: {:reply, :ok, state}

  @impl true
  def handle_cast({:game_over, winner}, state) do
    IO.puts("\n=== GAME OVER ===\nWinner: #{winner}\n")
    {:noreply, state}
  end

  @impl true
  def handle_cast({:token, %Turn{} = turn}, state) do
    current = Turn.current_player(turn)

    IO.puts("[#{state.name}@#{node()}] recv token idx=#{turn.token_index} current=#{current.name}")

    if current.name != state.name do
      IO.puts("[#{state.name}@#{node()}] reroute -> #{current.name}")
      GenServer.cast(server_ref(current.name), {:token, turn})
      {:noreply, state}
    else
      result = run_local_turn(turn)

      case result do
        {:game_over, winner, %Turn{} = final_turn} ->
          IO.puts("[#{state.name}@#{node()}] GAME OVER winner=#{winner}")
          broadcast_game_over(winner, final_turn)
          {:noreply, state}

        %Turn{} = new_turn ->
          next_name = Turn.current_player(new_turn).name
          IO.puts("[#{state.name}@#{node()}] send -> #{next_name} idx=#{new_turn.token_index}")
          GenServer.cast(server_ref(next_name), {:token, new_turn})
          {:noreply, state}
      end
    end
  end


  defp broadcast_game_over(winner, %Turn{} = turn) do
    Enum.each(turn.players, fn p ->
      GenServer.cast(server_ref(p.name), {:game_over, winner})
    end)
  end



  # -----------------------
  # CLI
  # -----------------------

  defp run_local_turn(%Turn{} = turn), do: loop_cmd(turn)

  defp loop_cmd(%Turn{} = turn) do
    player = Turn.current_player(turn)
    top = hd(turn.discard_pile)

    IO.puts("Commands:")
    IO.puts("  play <color> <number>   (ex: play red 5)")
    IO.puts("  pick card")
    IO.puts("  uno!")

    IO.puts("\n=== Tour de #{player.name} ===")
    IO.puts("Top discard: #{format_card(top)}")
    IO.puts("Ta main:")
    show_hand(player)

    cmd = IO.gets("> ")
      |> to_string()
      |> String.trim()

    case String.downcase(cmd) do
      "uno!" ->
        p = Player.call_uno(player)
        turn |> Turn.update_current_player(p) |> loop_cmd()

      "pick card" ->
        {picked, turn1} = Turn.draw_cards(turn, 1)
        p2 = %Player{player | deck: player.deck ++ picked, uno_called: false}
        turn1 |> Turn.update_current_player(p2) |> Turn.next_turn()

      <<"play ", rest::binary>> ->
        handle_play(String.trim(rest), turn, player)

      _ ->
        IO.puts("Commands:")
        IO.puts("  play <color> <number>   (ex: play red 5)")
        IO.puts("  pick card")
        IO.puts("  uno!")
        loop_cmd(turn)
    end
  end

  defp handle_play(rest, %Turn{} = turn, %Player{name: name} = player) do
    parts = String.split(rest, ~r/\s+/, trim: true)

    with {:ok, want} <- parse_play(parts),
         {:ok, card} <- get_cards(player, want),
         {:ok, new_player, _new_discard, new_turn0} <-
           Player.use_card(player, card, turn.discard_pile, turn) do

      new_turn =
        if new_turn0.token_index == turn.token_index do
          Turn.next_turn(new_turn0)
        else
          new_turn0
        end

      if Player.is_win(new_player) do
        IO.puts("\n#{name} has won!\n")
        {:game_over, name, new_turn}
      else
        new_turn
      end
    else
      {:error, reason} ->
        IO.puts("Invalid card: #{inspect(reason)}")
        loop_cmd(turn)

      _ ->
        IO.puts("Invalid card.")
        loop_cmd(turn)
    end
  end


  # -----------------------
  # Parsing helpers
  # -----------------------

  defp parse_play([color_s, number_s]) do
    with {:ok, color} <- parse_color(color_s),
         {:ok, number} <- parse_number(number_s) do
      {:ok, %{color: color, number: number}}
    end
  end

  defp parse_play(_), do: {:error, :bad_format}

  defp parse_color(s) do
    case String.downcase(s) do
      "red" -> {:ok, :red}
      "blue" -> {:ok, :blue}
      "yellow" -> {:ok, :yellow}
      "green" -> {:ok, :green}
      _ -> {:error, :bad_color}
    end
  end

  defp parse_number(s) do
    case Integer.parse(s) do
      {n, ""} when n >= 0 and n <= 9 -> {:ok, n}
      _ -> {:error, :bad_number}
    end
  end

  defp get_cards(%Player{} = player, %{color: color, number: number}) do
    card =
      Enum.find(player.deck, fn %Card{} = c ->
        c.effect == nil and c.color == color and c.number == number
      end)

    if card, do: {:ok, card}, else: {:error, :card_not_in_hand}
  end

  # -----------------------
  # Display helpers
  # -----------------------

  defp show_hand(%Player{deck: deck}) do
    deck
    |> Enum.with_index(1)
    |> Enum.each(fn {c, i} ->
      IO.puts("  #{i}) #{format_card(c)}")
    end)
  end

  defp format_card(%Card{effect: nil, color: color, number: n}),
       do: "#{Atom.to_string(color)} #{n}"

  defp format_card(%Card{effect: e, color: color}),
       do: "#{Atom.to_string(color)} #{inspect(e)}"

  defp server_ref(name), do: {:global, {:uno_player, name}}
end
