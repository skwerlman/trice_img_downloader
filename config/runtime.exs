import Config

config :logger,
  backends: [
    {LoggerFileBackend, :debug_log}
  ]

config :logger, :debug_log,
  default_level: :debug,
  metadata: [:application, :module, :function],
  format: "$time $metadata[$level]$levelpad $message\n",
  path: "log/downloader.log"
