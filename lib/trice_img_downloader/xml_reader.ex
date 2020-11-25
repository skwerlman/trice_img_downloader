defmodule TriceImgDownloader.XMLReader do
  @moduledoc false
  import SweetXml, only: [sigil_x: 2]
  use GenServer
  use TriceImgDownloader.LogMacros

  @batch_size 10

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, any}
  def init(cfg_root) do
    info("Starting...")

    xml_paths =
      Application.get_env(:trice_img_downloader, :xmls)
      |> Enum.map(fn {name, needed} -> {Path.join([cfg_root, name]), needed} end)

    send(self(), :STARTUP)

    {:ok, {xml_paths, {[], 0}, []}}
  end

  @impl GenServer
  def handle_info(:STARTUP, {[], _, _} = state) do
    send(self(), :dispatch_some)
    {:noreply, state}
  end

  def handle_info(:STARTUP, {[{xml_path, needed} | paths], {ostream, _}, handles}) do
    send(self(), :STARTUP)

    {stream, handle} =
      if File.exists?(xml_path) do
        debug(["Processesing ", xml_path])

        handle = File.stream!(xml_path)

        stream =
          handle
          |> SweetXml.stream_tags([:card], namespace_conformant: true, discard: [:sets, :card])
          |> Stream.map(fn {_, doc} ->
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
          |> Stream.concat(ostream)

        {stream, handle}
      else
        case needed do
          :required -> raise "Cannot find file: #{xml_path}"
          :optional -> warn(["Cannot find file: ", xml_path])
        end

        {ostream, nil}
      end

    {:noreply, {paths, {stream, 0}, if(handle, do: [handle | handles], else: handles)}}
  end

  def handle_info(:dispatch_some, {paths, {stream, dropped}, handles}) do
    cards =
      stream
      |> Stream.drop(dropped)
      |> Enum.take(@batch_size)

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

    {:noreply, {paths, {stream, dropped + @batch_size}, handles}}
  end

  # def handle_info(:RELOAD, state) do
  #   send(self(), :STARTUP)
  #   {:noreply, state}
  # end
end
