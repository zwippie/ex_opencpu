# OpenCPU

OpenCPU client to interact with a OpenCPU server, see https://www.opencpu.org/.

Almosts exactly mimics the behaviour of the Ruby opencpu gem (https://github.com/roqua/opencpu).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `opencpu` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:opencpu, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/opencpu](https://hexdocs.pm/opencpu).

## Configuration

Create an entry in your `config/config.exs` for `:opencpu` with at least an endpoint_url, the rest of the configuration is optional: Set `username` and `password` to use http basic auth for each request.

```elixir
config :opencpu,
  endpoint_url: "https://public.opencpu.org/ocpu",
  username: "username",
  password: "password,
  verify_ssl: true,
  timeout: 5

```

## Usage

Execute a request on the OpenCPU server:

```elixir
OpenCPU.execute(:animation, "flip.coin")
# %{"freq" => [0.56, 0.44], "nmax" => [50]}
```

Prepare and use a delayed calculation to retreive a plot/graphic, supported formats are `:png` and `:svg`:

```elixir
delayed_calculation = OpenCPU.prepare("animation", "flip.coin")
OpenCPU.DelayedCalculation.graphics(delayed_calculation, 0, :png)
# Returns the PNG file contents
```
