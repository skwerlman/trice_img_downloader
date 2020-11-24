# TriceImgDownloader

**TODO: Add description**

## Installation

First, (install elixir)[https://elixir-lang.org/install.html]

Once elixir is installed, and `mix` is available on your path, run the following commands:

Install Hex.pm support:
```
mix hex.local
```

Download and compile dependancies:
```
mix deps.get
mix deps.compile
```

Compile the program:
```
mix compile
```

## Running

Until we have release support set up, run the following to start the downloader:
```
mix run --no-halt
```

The downloader does not currently automatically exit when done, so you'll need to kill it by pressing `Ctrl+C` twice
