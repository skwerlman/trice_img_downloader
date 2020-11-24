import Config

config :trice_img_downloader,
  config_root: Path.expand("./priv/data/Cockatrice"),
  # config_root: Path.expand("~/.local/share/Cockatrice/Cockatrice/"),
  xmls: [
    {"cards.xml", :required},
    {"tokens.xml", :required},
    {"spoiler.xml", :optional}
  ],
  database_settings: "settings/cardDatabase.ini",
  img_size: "large"
