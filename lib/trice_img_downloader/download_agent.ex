defmodule TriceImgDownloader.DownloadAgent do
  @moduledoc false
  use GenServer
  use TriceImgDownloader.LogMacros
  alias TriceImgDownloader.ConfigServer
  alias TriceImgDownloader.Scryfall.Api

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, Qex.t()}
  def init(_) do
    info("starting #{to_string(__MODULE__)}")
    Process.send_after(self(), :download_one, 500)
    {:ok, Qex.new()}
  end

  @impl GenServer
  def handle_cast({:queue, card}, queue) do
    if Enum.empty?(queue) do
      info("New items in queue, resuming downloads...")
      send(self(), :download_one)
    end

    {:noreply, Qex.push(queue, card)}
  end

  @impl GenServer
  def handle_info(:download_one, queue) do
    q2 =
      case Qex.first(queue) do
        {:value, card} ->
          info(["Downloading image for ", card.name])

          sets =
            card.sets
            |> Enum.map(fn %{name: set} -> set end)

          response =
            ConfigServer
            |> GenServer.call({:pick_a_set, sets})

          case response do
            :try_later ->
              Process.send_after(self(), :download_one, 2000)
              queue

            :none ->
              warn(["No enabled sets for ", card.name])
              {_, q} = Qex.pop!(queue)
              send(self(), :download_one)
              GenServer.cast(TriceImgDownloader.StatServer, :skipped_card)
              q

            set_name ->
              set =
                card.sets
                |> Stream.filter(fn %{name: s} -> s == set_name end)
                |> Enum.at(0)

              with base_path <- Application.get_env(:trice_img_downloader, :config_root),
                   size <- Application.get_env(:trice_img_downloader, :img_size, "large"),
                   folder <- "#{base_path}/pics/downloadedPics/#{set_normalize(set_name)}/",
                   path <-
                     "#{base_path}/pics/downloadedPics/#{set_normalize(set_name)}/#{normalize(card.name)}.jpg",
                   {:mkdir, :ok} <- {:mkdir, File.mkdir_p(folder)},
                   {:file_check, false} <- {:file_check, File.exists?(path)},
                   {:get_info, art_uris} when is_binary(art_uris) or is_map_key(art_uris, size) <-
                     {:get_info, get_info(set)},
                   {:download, {:ok, blob}} <- {:download, download(art_uris, size)},
                   {:open, {:ok, file}} <- {:open, File.open(path, [:write, :exclusive, :binary])} do
                IO.binwrite(file, blob)
                File.close(file)
                GenServer.cast(TriceImgDownloader.StatServer, :downloaded_card)
              else
                {:file_check, true} ->
                  debug(["Already downloaded card: ", card.name])
                  GenServer.cast(TriceImgDownloader.StatServer, :skipped_card)

                {:error, :eexist} ->
                  debug(["Already downloaded card: ", card.name])
                  GenServer.cast(TriceImgDownloader.StatServer, :skipped_card)

                err ->
                  error([
                    "Failed to download art for ",
                    card.name,
                    "\n",
                    "Reason: ",
                    inspect(err, pretty: true, limit: :infinity, printable_limit: :infinity)
                  ])

                  GenServer.cast(TriceImgDownloader.StatServer, :errored_card)
              end

              {_, q} = Qex.pop!(queue)
              send(self(), :download_one)
              q
          end

        :empty ->
          info("Download queue is empty, asking XMLReader for more...")
          GenServer.cast(TriceImgDownloader.StatServer, :queue_refresh)
          GenServer.cast(TriceImgDownloader.XMLReader, :dispatch_some)
          queue
      end

    {:noreply, q2}
  end

  defp get_info(%{uuid: uuid}) when is_binary(uuid) and uuid != "" do
    with {:ok, res} <- Api.cards(uuid, []),
         body <- res.body do
      case body["image_uris"] do
        nil ->
          Enum.at(body["card_faces"], 0)["image_uris"]

        uris ->
          uris
      end
    else
      resp ->
        resp
    end
  end

  defp get_info(%{picurl: uri}) when is_binary(uri) and uri != "" do
    uri
  end

  defp get_info(spec) do
    error(["No implemented download method for ID specification: ", inspect(spec)])
    {:error, :no_method}
  end

  defp download(uri, _) when is_binary(uri) do
    case Api.image(uri) do
      {:ok, res} -> {:ok, res.body}
      res -> res
    end
  end

  defp download(uris, size) when is_map(uris) do
    with uri when not is_nil(uri) <- uris[size],
         {:ok, res} <- Api.image(uri) do
      {:ok, res.body}
    else
      resp -> resp
    end
  end

  defp normalize(name) do
    name
    # Fire // Ice
    |> String.replace(" // ", "")
    # Circle of Protection: Red, "Ach! Hans, Run!", Question Elemental?
    |> String.replace(~r(:|"|\?), "")
    # Who/What/When/Where/Why
    |> String.replace("/", " ")
  end

  defp set_normalize("CON"), do: "CON_"
  defp set_normalize(set_name), do: set_name
end
