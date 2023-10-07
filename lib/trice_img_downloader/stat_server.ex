defmodule TriceImgDownloader.StatServer do
  @moduledoc false
  use GenServer
  use TriceImgDownloader.LogMacros

  @default_tick_rate 1_000

  defstruct tick_rate: @default_tick_rate,
            total_cards: 0,
            downloaded_cards: 0,
            skipped_cards: 0,
            errored_cards: 0,
            queue_refreshes: 0,
            start_time: nil

  @type state :: %__MODULE__{
          tick_rate: integer(),
          total_cards: integer(),
          downloaded_cards: integer(),
          skipped_cards: integer(),
          errored_cards: integer(),
          queue_refreshes: integer(),
          start_time: Time.t()
        }

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, state}
  def init(maybe_tick_rate) do
    info("starting #{to_string(__MODULE__)}")

    tick_rate =
      if is_integer(maybe_tick_rate) do
        maybe_tick_rate
      else
        @default_tick_rate
      end

    # Process.send_after(self(), :print_tick, tick_rate)

    {:ok, %__MODULE__{tick_rate: tick_rate, start_time: Time.utc_now()}}
  end

  @impl GenServer
  def handle_info(
        :print_tick,
        %__MODULE__{
          tick_rate: _tick_rate,
          total_cards: total_cards,
          downloaded_cards: downloaded_cards,
          skipped_cards: skipped_cards,
          errored_cards: errored_cards,
          queue_refreshes: queue_refreshes,
          start_time: started
        } = state
      ) do
    runtime = Time.diff(Time.utc_now(), started, :second)

    total_handled = downloaded_cards + skipped_cards + errored_cards

    percent_done =
      case total_cards do
        0 -> 0
        _ -> round(total_handled / total_cards * 100)
      end

    info([
      "\n",
      "Statistics:\n",
      ["Runtime:          ", Integer.to_string(runtime), "s\n"],
      ["Total Cards:      ", Integer.to_string(total_cards), "\n"],
      ["Downloaded Cards: ", Integer.to_string(downloaded_cards), "\n"],
      ["Skipped Cards:    ", Integer.to_string(skipped_cards), "\n"],
      ["Errored Cards:    ", Integer.to_string(errored_cards), "\n"],
      ["Queue Refreshes:  ", Integer.to_string(queue_refreshes), "\n"],
      "------------------\n",
      ["Completion:       ", Integer.to_string(percent_done), "%"]
    ])

    # Process.send_after(self(), :print_tick, tick_rate)

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:loaded_cards, count}, %{total_cards: cards} = state) do
    {:noreply, %__MODULE__{state | total_cards: cards + count}}
  end

  def handle_cast(:downloaded_card, %{downloaded_cards: cards} = state) do
    {:noreply, %__MODULE__{state | downloaded_cards: cards + 1}}
  end

  def handle_cast(:skipped_card, %{skipped_cards: cards} = state) do
    {:noreply, %__MODULE__{state | skipped_cards: cards + 1}}
  end

  def handle_cast(:errored_card, %{errored_cards: cards} = state) do
    {:noreply, %__MODULE__{state | errored_cards: cards + 1}}
  end

  def handle_cast(:queue_refresh, %{queue_refreshes: cards} = state) do
    {:noreply, %__MODULE__{state | queue_refreshes: cards + 1}}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end
end
