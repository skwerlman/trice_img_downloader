defmodule TriceImgDownloader.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false
  use Application
  use TriceImgDownloader.LogMacros

  @spec start(any, any) :: {:error, any} | {:ok, pid}
  def start(_type, _args) do
    config_root = Application.get_env(:trice_img_downloader, :config_root)
    info("starting #{to_string(__MODULE__)}")

    tui_opts = [
      app: TriceImgDownloader.Interface,
      # shutdown: {:application, :trice_img_downloader},
      shutdown: :system,
      interval: 250
    ]

    children = [
      TriceImgDownloader.StatServer,
      # {TriceImgDownloader.ConfigServer, config_root},
      # TriceImgDownloader.Scryfall,
      # {TriceImgDownloader.XMLReader, config_root},
      # TriceImgDownloader.DownloadAgent,
      {Ratatouille.Runtime.Supervisor, runtime: tui_opts}
    ]

    opts = [strategy: :one_for_one, name: TriceImgDownloader.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def stop(_) do
    IO.puts("Quitting...")
  end
end
