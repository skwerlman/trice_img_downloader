defmodule TriceImgDownloader.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :trice_img_downloader,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TriceImgDownloader.Application, []}
    ]
  end

  defp deps do
    [
      {:con_cache, "~> 1.0"},
      {:configparser_ex, "~> 4.0"},
      {:ex_rated, "~> 2.1"},
      {:jason, "~> 1.4"},
      {:logger_file_backend, "~> 0.0"},
      {:qex, "~> 0.5"},
      {:ratatouille, "~> 0.5"},
      {:ring_logger, "~> 0.10"},
      {:sweet_xml, "~> 0.7"},
      {:tesla, "~> 1.7"},
      {:dialyxir, "~> 1.4", runtime: false, only: [:dev, :test]},
      {:credo, "~> 1.7", runtime: false, only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end
end
