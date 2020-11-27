import Config

config :logger, LoggerFileBackend,
  default_level: :debug,
  metadata: [:application, :module, :function],
  format: "$time $metadata[$level]$levelpad $message\n",
  path: "log/scrybot.log"
