defmodule Uno.TokenRing.PlayerServer do
  @moduledoc false

  use GenServer

  alias Uno.TokenRing.Token
  alias Uno.Model.{GameState, Player, Card}

  # -----------------------
  # Public API
  # -----------------------

  def start_link(player_name, next_name) when is_binary(player_name) and is_binary(next_name) do
    GenServer.start_link(__MODULE__,
      %{name: player_name, next: next_name, last_turn: nil},
      name: server_ref(player_name)
    )
  end

  def inject_token(player_name, token) when is_map(token) do
    GenServer.cast(server_ref(player_name), {:token, token})
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
  def handle_cast({:token, %Token{} = token}, state) do
    gs = token.gs
    IO.puts("[#{state.name}@#{node()}] recv token phase=#{token.phase} round=#{token.round_id}")

    case token.phase do
      :sync ->
        state = %{state | last_turn: gs}
        show_game_state(gs, state.name)

        if state.name == token.origin do
          token2 = Token.to_turn(token)
          GenServer.cast(server_ref(token2.actor), {:token, token2})
          {:noreply, state}
        else
          forward_to_next(token, state)
        end

      :turn ->
        if state.name != token.actor do
          forward_to_next(token, state)
        else
          result = run_local_turn(gs)

          case result do
            {:game_over, winner, %GameState{} = final_gs} ->
              broadcast_game_over(winner, final_gs)
              {:noreply, %{state | last_turn: final_gs}}

            %GameState{} = new_gs ->
              next_actor = GameState.current_player(new_gs).name
              token2 = Token.next_round_sync(token, new_gs, state.name, next_actor)
              forward_to_next(token2, state)
          end
        end
    end
  end

  @impl true
  def handle_cast({:token, other}, state) do
    IO.puts("[#{state.name}@#{node()}] recv unknown token: #{inspect(other)}")
    {:noreply, state}
  end


  defp broadcast_game_over(winner, %GameState{} = gs) do
    Enum.each(gs.players, fn p ->
      GenServer.cast(server_ref(p.name), {:game_over, winner})
    end)
  end

  defp forward_to_next(token, state) do
    IO.puts("[#{state.name}@#{node()}] forward -> #{state.next}")
    GenServer.cast(server_ref(state.next), {:token, token})
    {:noreply, state}
  end




  # -----------------------
  # CLI
  # -----------------------

  defp run_local_turn(gs = %GameState{}), do: loop_cmd(gs)

  defp show_game_state(gs = %GameState{}, my_name) do
    top_card = hd(gs.discard_pile)
    current_player = GameState.current_player(gs).name

    IO.puts("\n--- STATE UPDATE for #{my_name} ---")
    IO.puts("Top discard: #{format_card(top_card)}")
    IO.puts("Current player : #{current_player}")

    Enum.each(gs.players, fn p ->
      hand_size = length(p.deck)
      if p.name == my_name do
        IO.puts("  #{p.name}: #{hand_size} cards")
      else
        IO.puts("  #{p.name}: #{hand_size} cards")
      end
    end)

    IO.puts("-----------------------------\n")
  end


  defp loop_cmd(gs = %GameState{}) do
    player = GameState.current_player(gs)
    top = hd(gs.discard_pile)

    IO.puts("Commands:")
    IO.puts("  play <color> <number>   (ex: play red 5)")
    IO.puts("  pick card")
    IO.puts("  uno!")

    IO.puts("\n=== #{player.name}'s turn ===")
    IO.puts("Top discard: #{format_card(top)}")
    IO.puts("Ta main:")
    show_hand(player)

    cmd = IO.gets("> ")
      |> to_string()
      |> String.trim()

    case String.downcase(cmd) do
      "uno!" ->
        p = Player.call_uno(player)
        gs |> GameState.update_current_player(p) |> loop_cmd()

      "pick card" ->
        {picked, new_gs} = GameState.draw_cards(gs, 1)
        p2 = %Player{player | deck: player.deck ++ picked, uno_called: false}
        new_gs |> GameState.update_current_player(p2) |> GameState.next_turn()

      <<"play ", rest::binary>> ->
        handle_play(String.trim(rest), gs, player)

      _ ->
        IO.puts("Commands:")
        IO.puts("  play <color> <number>   (ex: play red 5)")
        IO.puts("  pick card")
        IO.puts("  uno!")
        loop_cmd(gs)
    end
  end

  defp handle_play(rest, gs = %GameState{}, %Player{name: name} = player) do
    parts = String.split(rest, ~r/\s+/, trim: true)

    with {:ok, want} <- parse_play(parts),
         {:ok, card} <- get_cards(player, want),
         {:ok, new_player, _new_discard, new_gs} <-
           Player.use_card(player, card, gs.discard_pile, gs) do

      new_gs2 =
        if new_gs.token_index == gs.token_index do
          GameState.next_turn(new_gs)
        else
          new_gs
        end

      if Player.is_win(new_player) do
        IO.puts("\n#{name} has won!\n")
        {:game_over, name, new_gs2}
      else
        new_gs2
      end
    else
      {:error, reason} ->
        IO.puts("Invalid card: #{inspect(reason)}")
        loop_cmd(gs)

      _ ->
        IO.puts("Invalid card.")
        loop_cmd(gs)
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
