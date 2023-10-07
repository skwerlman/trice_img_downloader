defmodule TriceImgDownloader.XMLReader do
  @moduledoc false
  import SweetXml, only: [sigil_x: 2]
  use GenServer
  use TriceImgDownloader.LogMacros

  @batch_size 100

  @spec start_link(any) :: {:error, any} | {:ok, pid}
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, any, {:continue, :STARTUP}}
  def init(cfg_root) do
    info("starting #{to_string(__MODULE__)}")

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
    {:ok, {xml_paths, []}, {:continue, :STARTUP}}
  end

  @impl GenServer
  def handle_continue(:STARTUP, {[], _} = state) do
    debug("Finished processing XMLs")
    {:noreply, state}
  end

  def handle_continue(:STARTUP, {[{xml_path, needed} | paths], ostream}) do
    nstream =
      if File.exists?(xml_path) do
        debug(["Processesing ", xml_path])

        handle = File.stream!(xml_path)

        stream =
          handle
          |> SweetXml.stream_tags([:card],
            namespace_conformant: true,
            discard: [:sets, :cards, :info, :prop, :text]
          )
          |> Stream.map(
            fn {_, doc} ->
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
          |> Stream.map(
            fn x ->
              GenServer.cast(TriceImgDownloader.StatServer, {:loaded_cards, 1})
              x
            end)
          |> Stream.chunk_every(@batch_size)
          |> Stream.map(fn chunk -> dispatch(chunk) end)
          |> Enum.concat(ostream)

        stream
      else
        case needed do
          :required -> raise "Cannot find file: #{xml_path}"
          :optional -> warn(["Cannot find file: ", xml_path])
        end

        ostream
      end

    {:noreply, {paths, nstream}, {:continue, :STARTUP}}
  end

  @impl GenServer
  def handle_info(:START, state) do
    send(self(), :dispatch_some)
    {:noreply, state}
  end

  def handle_info(:dispatch_some, {paths, chunks}) do
    {_chunk, rest} = StreamSplit.pop(chunks)

    {:noreply, {paths, rest}}
  end

  def handle_info(event, state) do
    warn(["Unexpected event: ", inspect(event)])
    {:noreply, state}
  end

  # def handle_info(:RELOAD, state) do
  #   send(self(), :STARTUP)
  #   {:noreply, state}
  # end

  defp dispatch(cards) do
    if Enum.empty?(cards) do
      info("Finished dispatching cards")
    else
      Enum.each(cards, fn card ->
        GenServer.cast(TriceImgDownloader.DownloadAgent, {:queue, card})
      end)
    end
  end
end
