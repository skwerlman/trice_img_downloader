defmodule TriceImgDownloader.Ratelimiter.Middleware do
  @moduledoc false
  @behaviour Tesla.Middleware
  use TriceImgDownloader.LogMacros

  defp block_while_limited({name, timeframe, requests} = bucket_info) do
    {status, _remaining} = ExRated.check_rate(name, timeframe, requests)

    case status do
      :ok ->
        :ok

      :error ->
        warn("ratelimited; sleeping for 500ms")
        _ = Process.sleep(500)
        block_while_limited(bucket_info)
    end
  end

  @spec call(Tesla.Env.t(), Tesla.Env.stack(), any()) :: Tesla.Env.result()
  def call(env, next, bucket_info) do
    :ok = block_while_limited(bucket_info)

    Tesla.run(env, next)
  end
end
