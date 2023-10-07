defmodule TriceImgDownloader.Interface do
  @moduledoc false
  use TriceImgDownloader.LogMacros
  import Ratatouille.View
  alias Ratatouille.Runtime.{Command, Subscription}
  alias TriceImgDownloader.StatServer

  @type model :: %{
          noise: boolean(),
          log_size: integer(),
          stats: StatServer.state(),
          last_event: atom()
        }

  @behaviour Ratatouille.App

  @ui_available_space_offset 14

  @impl Ratatouille.App
  def init(%{window: %{height: height}}) do
    info("starting #{to_string(__MODULE__)}")
    # register ourselves
    TriceImgDownloader.Supervisor
    |> Supervisor.which_children()
    |> Enum.filter(fn
      {Ratatouille.Runtime.Supervisor, _pid, _, _} -> true
      _ -> false
    end)
    # there is only one of us, so this is fine
    |> Enum.each(fn {Ratatouille.Runtime.Supervisor, pid, _, _} ->
      Process.register(pid, __MODULE__)
    end)

    # register the runtime
    TriceImgDownloader.Interface
    |> Supervisor.which_children()
    |> Enum.filter(fn
      {Ratatouille.Runtime, _pid, _, _} -> true
      _ -> false
    end)
    |> Enum.each(fn {Ratatouille.Runtime, pid, _, _} ->
      Process.register(pid, Ratatouille.Runtime)
    end)

    max = height - @ui_available_space_offset

    {%{stats: %StatServer{}, log_size: max, last_event: :init, noise: true},
     Command.new(
       fn -> GenServer.call(StatServer, :get_stats) end,
       :stats
     )}
  end

  @impl Ratatouille.App
  def update(%{noise: noise} = model, msg) do
    case msg do
      {:stats, new_stats} ->
        %{model | stats: new_stats, last_event: :stats}

      :tick ->
        {
          %{model | last_event: :tick},
          Command.new(
            fn -> GenServer.call(StatServer, :get_stats) end,
            :stats
          )
        }

      :log ->
        %{model | noise: not noise, last_event: :log}

      {:resize, %{h: height}} ->
        # FIXME HACK
        # If we draw too many labels, they overflow the log panel
        # To avoid this we need to keep the log beffer the same size
        # as the panel.
        new_buffer_size = height - @ui_available_space_offset

        debug("Resizing log buffer...")

        %{model | log_size: new_buffer_size, last_event: :resize}

      _event ->
        model
    end
  end

  @impl Ratatouille.App
  def subscribe(_model) do
    Subscription.batch([
      Subscription.interval(1_000, :tick),
      Subscription.interval(100, :log)
    ])
  end

  @impl Ratatouille.App
  def render(%{stats: stats, log_size: log_size, last_event: last_event}) do
    total_handled = stats.downloaded_cards + stats.skipped_cards + stats.errored_cards

    percent_done =
      case stats.total_cards do
        0 -> 0
        _ -> round(total_handled / stats.total_cards * 100)
      end

    log_entries =
      RingLogger.get()
      |> Enum.take(-log_size)

    footer =
      bar do
        label do
          text(content: "Press 'q' to quit")
          text(content: " | ")
          text(content: "Last Event: ", color: :cyan)
          text(content: inspect(last_event), color: :cyan)
        end
      end

    view(bottom_bar: footer) do
      panel(height: :fill, title: " Trice Image Downloader ", color: :green) do
        panel(title: " Stats ") do
          row do
            column(size: 3) do
              label do
                text(content: "Total cards:")
              end

              label do
                text(content: "Downloaded Cards:")
              end
            end

            column(size: 1) do
              label do
                text(content: Integer.to_string(stats.total_cards), color: :blue)
              end

              label do
                text(content: Integer.to_string(stats.downloaded_cards), color: :green)
              end
            end

            column(size: 3) do
              label do
                text(content: "Skipped Cards:")
              end

              label do
                text(content: "Errored Cards:")
              end
            end

            column(size: 1) do
              label do
                text(content: Integer.to_string(stats.skipped_cards), color: :yellow)
              end

              label do
                text(content: Integer.to_string(stats.errored_cards), color: :red)
              end
            end

            column(size: 3) do
              label do
                text(content: "Progress:")
              end
            end

            column(size: 1) do
              label do
                text(content: Integer.to_string(percent_done))
                text(content: "%")
              end
            end

            # spacer
            column(size: 1) do
            end
          end
        end

        panel(
          [height: :fill, title: " Log "],
          for %{level: level, message: entry} <- log_entries do
            label do
              text(content: String.replace(entry, "\n", " "), color: level_to_color(level))
            end
          end
        )
      end
    end
  end

  defp level_to_color(:error), do: :red
  defp level_to_color(:warn), do: :yellow
  defp level_to_color(:info), do: :white
  defp level_to_color(:debug), do: :blue
end
