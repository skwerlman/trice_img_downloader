defmodule TriceImgDownloader.Scryfall.Api do
  @moduledoc false
  @scryfall_uri "https://api.scryfall.com"
  use Tesla

  @type error :: {:error, reason :: String.t(), type :: String.t()}

  plug(TriceImgDownloader.Ratelimiter.Middleware, {:scryfall_bucket, 1000, 10})
  # plug(TriceImgDownloader.Scryfall.Cache.Middleware)
  plug(Tesla.Middleware.BaseUrl, @scryfall_uri)
  plug(Tesla.Middleware.Timeout, timeout: 4000)
  plug(Tesla.Middleware.Retry, delay: 125, max_retries: 3)
  plug(Tesla.Middleware.Compression)
  plug(Tesla.Middleware.DecodeJson)

  defp handle_errors({:ok, %{body: body} = resp}) do
    case body["object"] do
      "error" -> {:error, body["details"], body["type"]}
      _ -> {:ok, resp}
    end
  rescue
    # this is normal for non-json things (like images)
    FunctionClauseError -> {:ok, resp}
  end

  defp handle_errors({:error, status}) do
    reason =
      case status do
        :econnrefused ->
          "Connection refused! Did we exceed the ratelimit?"

        :timeout ->
          "Scryfall timed out! Are they down for maintenance?"

        :invalid_uri ->
          "We seem to have generated a bad URI. Please report this bug."

        _ ->
          "Unknown error!"
      end

    {:error, reason, to_string(status)}
  end

  @spec image(String.t()) :: {:ok, map} | error
  def image(url) do
    url
    |> get()
    |> handle_errors()
  end

  @spec cards(String.t(), [keyword]) :: {:ok, map} | error
  def cards(uuid, options \\ []) do
    query = [{:format, "json"} | options]

    "/cards/#{uuid}"
    |> get(query: query)
    |> handle_errors()
  end
end
