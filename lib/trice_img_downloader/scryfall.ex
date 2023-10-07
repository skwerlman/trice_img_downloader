defmodule TriceImgDownloader.Scryfall do
  @moduledoc false
  use Supervisor
  use TriceImgDownloader.LogMacros

  @spec start_link(any()) :: {:error, any()} | {:ok, pid()}
  def start_link(_) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl Supervisor
  def init(:ok) do
    info("starting #{to_string(__MODULE__)}")

    children = [
      {ConCache,
       [
         name: cache_id(),
         # 30 minutes
         ttl_check_interval: 30 * 60 * 1000,
         # 2 days
         global_ttl: 48 * 60 * 60 * 1000,
         ets_options: [read_concurrency: true, name: :scryfall_cache_ets]
       ]}
    ]

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  @spec cache_id() :: TriceImgDownloader.Scryfall.CacheWorker
  def cache_id, do: TriceImgDownloader.Scryfall.CacheWorker
end
