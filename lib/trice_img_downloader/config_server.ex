defmodule TriceImgDownloader.ConfigServer do
  @moduledoc false
  use GenServer
  use TriceImgDownloader.LogMacros

  @type state :: {
          config_path :: Path.t(),
          loaded_ok? :: boolean(),
          priorities :: Keyword.t(integer())
        }

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(config_folder :: Path.t()) :: {:ok, state}
  def init(config_folder) do
    info("starting #{to_string(__MODULE__)}")

    database_settings =
      Path.join([
        config_folder,
        Application.get_env(:trice_img_downloader, :database_settings)
      ])

    send(self(), :STARTUP)

    {:ok, {database_settings, false, []}}
  end

  @impl GenServer
  def handle_info(:STARTUP, {path, _ok?, _pri}) do
    debug("Loading set priorities")

    {ok, ini} =
      path
      |> ConfigParser.parse_file()

    ok? =
      case ok do
        :ok -> true
        _ -> false
      end

    priorities =
      if ok? do
        pri =
          ini["sets"]
          |> Stream.map(fn {k, _v} -> k |> String.split("\\") |> hd() end)
          |> Stream.uniq()
          |> Stream.map(fn set ->
            enabled? = ConfigParser.getboolean(ini, "sets", set <> "\\enabled")

            if enabled? do
              case ConfigParser.getint(ini, "sets", set <> "\\sortkey") do
                nil ->
                  warn(["Skipping enabled set with no sortkey: ", set])
                  :skip

                p ->
                  %{set: set, priority: p}
              end
            else
              :skip
            end
          end)
          |> Stream.reject(fn x -> x == :skip end)
          |> Enum.sort_by(fn %{priority: p} -> p end)

        debug(["Loaded priorities for ", Integer.to_string(length(pri)), " sets"])
        pri
      else
        error(["Failed to load config! ", to_string(ini)])
        []
      end

    {:noreply, {path, ok?, priorities}}
  end

  def handle_info(:RELOAD, {path, _ok?, pri}) do
    info("Reloading config...")
    send(self(), :STARTUP)
    {:noreply, {path, false, pri}}
  end

  @impl GenServer
  def handle_call({:pick_a_set, sets}, _from, {_, true, pri} = state) do
    debug(["Picking set from: ", inspect(sets)])

    [set | _] =
      pri
      |> Stream.filter(fn %{set: s} -> s in sets end)
      |> Enum.sort_by(fn %{priority: p} -> p end)
      |> case do
        [] -> [:none]
        x -> x
      end

    reply =
      case set do
        :none ->
          debug("Picked :none")
          :none

        _ ->
          %{set: r, priority: p} = set
          debug(["Picked ", inspect(r), " (priority ", Integer.to_string(p), ")"])
          r
      end

    {:reply, reply, state}
  end

  def handle_call({:pick_a_set, _sets}, _from, {_, false, _pri} = state) do
    debug("Tried to pick a set, but configs weren't ready")
    {:reply, :try_later, state}
  end
end
