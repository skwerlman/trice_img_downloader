import Config

config :logger, :console,
  default_level: :debug,
  format: "$time [$level]$levelpad $message\n"
