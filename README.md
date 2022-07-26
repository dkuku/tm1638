# TM1638 library for elixir/nerves


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tm1638` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tm1638, "~> 0.1.0"}
  ]
end
```

## Configration
```
config :tm1638,
  stb: 22,
  clk: 24,
  dio: 23,
  brightness: 3
```
or in livebook
```

Application.put_env(:tm1638, :stb, 22)
Application.put_env(:tm1638, :clk, 24)
Application.put_env(:tm1638, :dio, 23)
Application.put_env(:tm1638, :brightness, 3)
```

## Examples

### iterate over all 8 leds
```
{:ok, tm} = TM1638.init()

TM1638.clear_display(tm)
Enum.each(1..255, fn x -> 
TM1638.leds(tm, x)
Process.sleep(10)
end)
TM1638.clear_display(tm)
```

### read buttons every 100 ms
```
defmodule GetData do
  def get() do
    {:ok, tm} = TM1638.init()
    TM1638.get_data(tm)
  end
end
Enum.each(1..100, fn _ -> 
:timer.tc(GetData, :get, [])
|> IO.inspect
Process.sleep(100)
end)
```

### display moving text
```
TM1638.init()
|> elem(1)
|> TM1638.clear_display()
|> TM1638.display_moving_text("elixir is fun")
|> TM1638.clear_display()
```
