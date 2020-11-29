defmodule TriceImgDownloader.Interface do
  @moduledoc false
  use TriceImgDownloader.LogMacros
  import Ratatouille.View
  alias Ratatouille.Runtime.Command
  alias TriceImgDownloader.StatServer

  @behaviour Ratatouille.App

  @ui_available_space_offset 13

  @impl Ratatouille.App
  def init(%{window: %{height: height}}) do
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

    empty_log = for _ <- 0..(height - @ui_available_space_offset), do: ""

    {{{%StatServer{}, empty_log}, :init},
     Command.new(
       fn -> GenServer.call(StatServer, :get_stats) end,
       :stats
     )}
  end

  @impl Ratatouille.App
  def update({{model, log}, _}, msg) do
    case msg do
      {:stats, stats} ->
        {{stats, log}, :stats}

      :tick ->
        {{{model, log}, :tick},
         Command.new(
           fn -> GenServer.call(StatServer, :get_stats) end,
           :stats
         )}

      {:log, {entry, level}} ->
        {{model, tl(log) ++ [{to_string(entry), level}]}, :log}

      {:resize, %{h: height}} ->
        new_buffer_size = height - @ui_available_space_offset
        offset = new_buffer_size - length(log)

        debug("Resizing log buffer...")

        # FIXME HACK
        # If we draw too many labels, they overflow the log panel
        # To avoid this we need to keep the log beffer the same size
        # as the panel.
        case offset do
          0 ->
            {{model, log}, :resize}
          o when o >= 1 ->
            # new buffer is bigger than old buffer
            new_log = List.duplicate("", o) ++ log
            {{model, new_log}, :resize}
          o when o <= -1 ->
            # new buffer is smaller than old buffer
            new_log = log |> Enum.drop(-o)
            {{model, new_log}, :resize}
        end

      event ->
        debug(inspect(event))
        {{model, log}, event}
    end
  end

  @impl Ratatouille.App
  def subscribe(_model) do
    Ratatouille.Runtime.Subscription.interval(1_000, :tick)
  end

  @impl Ratatouille.App
  def render({{model, log}, last_event}) do
    total_handled = model.downloaded_cards + model.skipped_cards + model.errored_cards

    percent_done =
      case model.total_cards do
        0 -> 0
        _ -> round(total_handled / model.total_cards * 100)
      end

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
                text(content: Integer.to_string(model.total_cards), color: :blue)
              end

              label do
                text(content: Integer.to_string(model.downloaded_cards), color: :green)
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
                text(content: Integer.to_string(model.skipped_cards), color: :yellow)
              end

              label do
                text(content: Integer.to_string(model.errored_cards), color: :red)
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

        panel(height: :fill, title: " Log ") do
          for {entry, level} <- log do
            label do
              text(content: entry, color: level_to_color(level))
            end
          end
        end
      end
    end
  end

  defp level_to_color(:error), do: :red
  defp level_to_color(:warn), do: :yellow
  defp level_to_color(:info), do: :white
  defp level_to_color(:debug), do: :cyan
end
