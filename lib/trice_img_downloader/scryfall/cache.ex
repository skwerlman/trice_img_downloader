defmodule TriceImgDownloader.Scryfall.Cache.Middleware do
  @moduledoc false
  @behaviour Tesla.Middleware
  require Logger
  import TriceImgDownloader.LogMacros
  alias TriceImgDownloader.Scryfall

  @impl Tesla.Middleware
  @spec call(atom | %Tesla.Env{query: any, url: any}, any, any) :: Tesla.Env.result()
  def call(env, next, _options) do
    case ConCache.get(Scryfall.cache_id(), {env.url, env.query}) do
      nil ->
        debug("[Api] [Cache] hitting the real api: #{inspect({env.url, env.query})}")
        {status, result} = Tesla.run(env, next)

        if status == :ok do
          case result do
            %{status: status} when status in 200..299 ->
              ConCache.put(Scryfall.cache_id(), {env.url, env.query}, result.body)

            %{status: status} ->
              warn("[Api] [Cache] not caching: status #{inspect(status)}")
          end

          {:ok, result}
        else
          {:error, result}
        end

      cached ->
        debug("url was cached")
        {:ok, %{env | body: cached}}
    end
  end
end
