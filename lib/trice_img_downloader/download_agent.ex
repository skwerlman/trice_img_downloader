defmodule TriceImgDownloader.DownloadAgent do
  @moduledoc false
  use GenServer
  use TriceImgDownloader.LogMacros
  alias TriceImgDownloader.ConfigServer
  alias TriceImgDownloader.Scryfall.Api

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, Qex.t()}
  def init(_) do
    info("Starting...")
    # Process.send_after(self(), :download_one, 500)
    send(self(), :download_one)
    {:ok, Qex.new()}
  end

  @impl GenServer
  def handle_call({:queue, card}, _from, queue) do
    if Enum.empty?(queue) do
      info("New items in queue, resuming downloads...")
      Process.send_after(self(), :download_one, 25)
    end

    {:reply, :ok, Qex.push(queue, card)}
  end

  @impl GenServer
  def handle_info(:download_one, queue) do
    q2 =
      case Qex.first(queue) do
        {:value, card} ->
          info(["Downloading image for ", card.name])
          t = Process.send_after(self(), :download_one, 200)

          sets =
            card.sets
            |> Enum.map(fn %{name: set} -> set end)

          response =
            ConfigServer
            |> GenServer.call({:pick_a_set, sets})

          case response do
            :try_later ->
              Process.cancel_timer(t)
              Process.send_after(self(), :download_one, 2000)
              queue

            :none ->
              debug(["No enabled sets for ", card.name])
              {_, q} = Qex.pop!(queue)
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
                     "#{base_path}/pics/downloadedPics/#{set_normalize(set_name)}/#{
                       normalize(card.name)
                     }.jpg",
                   :ok <- File.mkdir_p(folder),
                   art_uris when is_binary(art_uris) or is_map_key(art_uris, size) <-
                     get_info(set),
                   {:ok, blob} <- download(art_uris, size),
                   {:ok, file} <- File.open(path, [:write, :exclusive, :binary]) do
                IO.binwrite(file, blob)
                File.close(file)
              else
                {:error, :eexist} ->
                  warn(["Skipping download for already downloaded card: ", card.name])

                err ->
                  error(["Failed to download art for ", card.name, "\n", inspect(err)])
              end

              {_, q} = Qex.pop!(queue)
              q
          end

        :empty ->
          info("Download queue is empty, asking XMLReader for more...")
          send(TriceImgDownloader.XMLReader, :dispatch_some)
          queue
      end

    {:noreply, q2}
  end

  defp get_info(%{uuid: uuid}) when is_binary(uuid) and uuid != "" do
    with {:ok, res} <- Api.cards(uuid, []),
         body <- res.body do
      body["image_uris"]
    else
      resp -> resp
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
    with {:ok, res} <- Api.image(uri) do
      {:ok, res.body}
    else
      resp -> resp
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
