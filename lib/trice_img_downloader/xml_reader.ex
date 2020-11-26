defmodule TriceImgDownloader.XMLReader do
  @moduledoc false
  import SweetXml, only: [sigil_x: 2]
  use GenServer
  use TriceImgDownloader.LogMacros

  @batch_size 100

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, any}
  def init(cfg_root) do
    info("Starting...")

    xml_paths =
      Application.get_env(:trice_img_downloader, :xmls)
      |> Stream.map(fn {name, needed} -> {Path.join([cfg_root, name]), needed} end)
      |> Enum.sort_by(fn {path, _} ->
        case File.stat(path) do
          {:ok, %{size: size}} ->
            size

          {:error, reason} ->
            warn(["Failed to stat file: ", path, "\nReason: ", inspect(reason)])
            0
        end
      end)

    send(self(), :STARTUP)

    {:ok, {xml_paths, [], []}}
  end

  @impl GenServer
  def handle_info(:STARTUP, {[], _, _} = state) do
    send(self(), :dispatch_some)
    {:noreply, state}
  end

  def handle_info(:STARTUP, {[{xml_path, needed} | paths], ostream, handles}) do
    send(self(), :STARTUP)

    {stream, handle} =
      if File.exists?(xml_path) do
        debug(["Processesing ", xml_path])

        handle = File.stream!(xml_path)

        cards =
          handle
          |> SweetXml.stream_tags([:card],
            namespace_conformant: true,
            discard: [:sets, :cards, :info, :prop, :text]
          )
          # We have to be eager here
          # If we use a stream instead,
          # GenServer incorrectly captures
          # a :wait message meant for the
          # stream_tags iterator
          |> Enum.map(fn {_, doc} ->
            SweetXml.xpath(
              doc,
              ~x".",
              name: ~x"./name/text()"s,
              sets: [
                ~x"./set"l,
                name: ~x"./text()"s,
                uuid: ~x"./@uuid"s,
                muid: ~x"./@muid"s,
                picurl: ~x"./@picURL"s
              ]
            )
          end)

        GenServer.cast(TriceImgDownloader.StatServer, {:loaded_cards, Enum.count(cards)})

        stream =
          cards
          |> Stream.concat(ostream)

        {stream, handle}
      else
        case needed do
          :required -> raise "Cannot find file: #{xml_path}"
          :optional -> warn(["Cannot find file: ", xml_path])
        end

        {ostream, nil}
      end

    {:noreply, {paths, stream, if(handle, do: [handle | handles], else: handles)}}
  end

  def handle_info(:dispatch_some, {paths, stream, handles}) do
    {cards, rest} =
      stream
      |> StreamSplit.take_and_drop(@batch_size)

    if Enum.empty?(cards) do
      info("Finished reading XMLs")

      for handle <- handles do
        File.close(handle)
      end
    else
      Enum.each(cards, fn card ->
        GenServer.cast(TriceImgDownloader.DownloadAgent, {:queue, card})
      end)
    end

    {:noreply, {paths, rest, handles}}
  end

  def handle_info(event, state) do
    warn(["Unexpected event: ", inspect(event)])
    {:noreply, state}
  end

  # def handle_info(:RELOAD, state) do
  #   send(self(), :STARTUP)
  #   {:noreply, state}
  # end
end
