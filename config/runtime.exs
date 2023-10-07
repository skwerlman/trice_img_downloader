import Config

config :logger,
  backends: [
    {LoggerFileBackend, :debug_log},
    RingLogger
  ]

config :logger, :debug_log,
  default_level: :debug,
  metadata: [:application, :module, :function],
  # format: "$time $metadata[$level] $message\n",
  format: "$time [$level] $message\n",
  path: "log/downloader.log"

config :logger, RingLogger, max_size: 1024
