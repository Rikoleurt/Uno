defmodule Uno.TokenRing.PlayerServer do
  @moduledoc false

  use GenServer

  alias Uno.TokenRing.Token
  alias Uno.Model.{GameState, Player, Card}

  # -----------------------
  # API
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
    IO.puts("[#{state.name}@#{node()}] recieve token.phase : #{token.phase} round_number : #{token.round_id}")

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
              token2 = Token.sync_next_round(token, new_gs, state.name, next_actor)
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

  defp run_local_turn(gs = %GameState{}), do: cmd(gs)

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


  defp cmd(gs = %GameState{}) do
    player = GameState.current_player(gs)
    top = hd(gs.discard_pile)

    if gs.must_draw > 0 do
      n = gs.must_draw
      IO.puts("\n=== #{player.name} must draw #{n} cards and loses the turn ===\n")

      {picked, gs2} = GameState.draw_cards(gs, n)
      p2 = %Player{player | deck: player.deck ++ picked, uno_called: false}

      %GameState{gs2 | must_draw: 0}
      |> GameState.update_current_player(p2)
      |> GameState.next_turn()
    else

      IO.puts("Commands:")
      IO.puts("  play <color> <number|skip|reverse>   (ex: play red 5 | play blue skip)")
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
          gs |> GameState.update_current_player(p) |> cmd()

        "pick card" ->
          {picked, new_gs} = GameState.draw_cards(gs, 1)
          p2 = %Player{player | deck: player.deck ++ picked, uno_called: false}
          new_gs |> GameState.update_current_player(p2) |> GameState.next_turn()

        <<"play ", rest::binary>> ->
          handle_play(String.trim(rest), gs, player)

        _ ->
          IO.puts("Commands:")
          IO.puts("  play <color> <number|skip|reverse|draw_two|wild_draw_four>   (ex: play red 5 | play blue skip)")
          IO.puts("  play <color> <number>   (ex: play red 5)")
          IO.puts("  pick card")
          IO.puts("  uno!")
          cmd(gs)
      end
    end
  end

  defp prompt_wild_color() do
    IO.puts("Choose a color for wild (red/blue/yellow/green):")

    IO.gets("> ")
    |> to_string()
    |> String.trim()
    |> String.downcase()
    |> case do
         "red" -> :red
         "blue" -> :blue
         "yellow" -> :yellow
         "green" -> :green
         _ ->
           IO.puts("Invalid color. Try again.")
           prompt_wild_color()
       end
  end

  defp handle_play(rest, gs = %GameState{}, %Player{name: name} = player) do
    parts = String.split(rest, ~r/\s+/, trim: true)

    with {:ok, want} <- parse_play(parts),
         {:ok, card} <- get_cards(player, want) do
      # If wild / wild_draw_four: choose color (either provided or prompted)
      chosen_color =
        if card.effect in [:wild, :wild_draw_four] do
          case Map.get(want, :chosen_color) do
            nil -> prompt_wild_color()
            c -> c
          end
        else
          nil
        end

      case Player.use_card(player, card, gs.discard_pile, gs) do
        {:ok, new_player, _new_discard, new_gs} ->
          new_gs =
            if card.effect in [:wild, :wild_draw_four] and is_atom(chosen_color) do
              colored = %Card{card | color: chosen_color}
              %GameState{new_gs | discard_pile: [colored | tl(new_gs.discard_pile)]}
            else
              new_gs
            end

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

        {:error, reason} ->
          IO.puts("Invalid card: #{inspect(reason)}")
          cmd(gs)
      end
    else
      {:error, reason} ->
        IO.puts("Invalid card: #{inspect(reason)}")
        cmd(gs)

      _ ->
        IO.puts("Invalid card.")
        cmd(gs)
    end
  end


  # -----------------------
  # Parsing helpers - Card Analysis
  # -----------------------

  defp parse_play([value_s]) do
    with {:ok, value} <- parse_value(value_s) do
      {:ok, %{color: :wild, value: value, chosen_color: nil}}
    end
  end

  defp parse_play([value_s, color_s]) do
    with {:ok, value} <- parse_value(value_s),
         true <- value in [:wild, :wild_draw_four],
         {:ok, chosen} <- parse_chosen_color(color_s) do
      {:ok, %{color: :wild, value: value, chosen_color: chosen}}
    else
      _ ->
        with {:ok, color} <- parse_color(value_s),
             {:ok, value} <- parse_value(color_s) do
          {:ok, %{color: color, value: value, chosen_color: nil}}
        end
    end
  end

  defp parse_play(_), do: {:error, :bad_format}

  defp parse_value(s) do
    s = s |> String.trim() |> String.downcase()
    s = if String.starts_with?(s, ":"), do: String.slice(s, 1..-1), else: s

    case s do
      "skip" -> {:ok, :skip}
      "reverse" -> {:ok, :reverse}
      "draw_two" -> {:ok, :draw_two}
      "wild" -> {:ok, :wild}
      "wild_draw_four" -> {:ok, :wild_draw_four}
      "draw_four" -> {:ok, :wild_draw_four}
      _ ->
        case Integer.parse(s) do
          {n, ""} when n >= 0 and n <= 9 -> {:ok, n}
          _ -> {:error, :bad_value}
        end
    end
  end

  defp parse_chosen_color(s) do
    case String.downcase(s) do
      "red" -> {:ok, :red}
      "blue" -> {:ok, :blue}
      "yellow" -> {:ok, :yellow}
      "green" -> {:ok, :green}
      _ -> {:error, :bad_color}
    end
  end

  defp parse_color(s) do
    case String.downcase(s) do
      "red" -> {:ok, :red}
      "blue" -> {:ok, :blue}
      "yellow" -> {:ok, :yellow}
      "green" -> {:ok, :green}
      "wild" -> {:ok, :wild}
      _ -> {:error, :bad_color}
    end
  end

  defp parse_number(s) do
    case Integer.parse(s) do
      {n, ""} when n >= 0 and n <= 9 -> {:ok, n}
      _ -> {:error, :bad_number}
    end
  end

  defp get_cards(%Player{} = player, %{color: color, value: value}) do
    card =
      Enum.find(player.deck, fn %Card{} = c ->
        cond do
          is_integer(value) ->
            c.effect == nil and c.color == color and c.number == value
          is_atom(value) ->
            if value in [:wild, :wild_draw_four] do
              c.effect == value
            else
              c.effect == value and c.color == color
            end
          true ->
            false
        end
      end)

    if card, do: {:ok, card}, else: {:error, :card_not_in_hand}
  end

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
       do: "#{Atom.to_string(color)} #{Atom.to_string(e)}"

  defp server_ref(name), do: {:global, {:uno_player, name}}
end
