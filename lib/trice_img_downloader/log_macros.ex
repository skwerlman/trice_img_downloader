defmodule TriceImgDownloader.LogMacros do
  @moduledoc false

  @doc false
  # this is public because it needs to be called from the process invoking the logger
  def __log_macro_prefix__(p) do
    {_, rname} = Process.info(p, :registered_name)

    prefix =
      case rname do
        [] -> inspect(p)
        _ -> to_string(rname)
      end

    String.pad_trailing("[#{prefix}]", 42)
  end

  defmacro __using__(_) do
    quote do
      require Logger
      import TriceImgDownloader.LogMacros, only: [debug: 1, info: 1, warn: 1, error: 1]
    end
  end

  defmacro debug(msg) do
    quote do
      _ =
        Logger.debug(fn ->
          [TriceImgDownloader.LogMacros.__log_macro_prefix__(self()), unquote(msg)]
        end)

      :ok
    end
  end

  defmacro info(msg) do
    quote do
      _ =
        Logger.info(fn ->
          [TriceImgDownloader.LogMacros.__log_macro_prefix__(self()), unquote(msg)]
        end)

      :ok
    end
  end

  defmacro warn(msg) do
    quote do
      _ =
        Logger.warn(fn ->
          [TriceImgDownloader.LogMacros.__log_macro_prefix__(self()), unquote(msg)]
        end)

      :ok
    end
  end

  defmacro error(msg) do
    quote do
      _ =
        Logger.error(fn ->
          [TriceImgDownloader.LogMacros.__log_macro_prefix__(self()), unquote(msg)]
        end)

      :ok
    end
  end
end
