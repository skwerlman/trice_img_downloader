defmodule TriceImgDownloader.XMLReader do
  @moduledoc false
  import SweetXml, only: [sigil_x: 2]
  use GenServer
  use TriceImgDownloader.LogMacros

  @config_folder Application.get_env(:trice_img_downloader, :config_root)
  @xml_paths Application.get_env(:trice_img_downloader, :xmls)
             |> Enum.map(fn {name, needed} -> {Path.join([@config_folder, name]), needed} end)

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl GenServer
  @spec init(any) :: {:ok, any}
  def init(_) do
    info("Starting...")

    send(self(), :STARTUP)

    {:ok, @xml_paths}
  end

  @impl GenServer
  def handle_info(:STARTUP, []) do
    {:noreply, []}
  end

  def handle_info(:STARTUP, [{xml_path, needed} | paths]) do
    send(self(), :STARTUP)

    if File.exists?(xml_path) do
      debug(["Processesing ", xml_path])

      :ok =
        xml_path
        |> File.stream!()
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
        |> Enum.each(fn card ->
          GenServer.cast(TriceImgDownloader.DownloadAgent, {:queue, card})
        end)

      debug("Done.")
    else
      case needed do
        :required -> raise "Cannot find file: #{xml_path}"
        :optional -> warn(["Cannot find file: ", xml_path])
      end
    end

    {:noreply, paths}
  end

  # def handle_info(:RELOAD, state) do
  #   send(self(), :STARTUP)
  #   {:noreply, state}
  # end
end
