defmodule TM1638Test do
  use ExUnit.Case
  doctest TM1638

  setup  do
    {:ok, tm} = TM1638.init()
    %{tm: tm}
  end
  test "init_display/1", %{tm: tm} do
    tm
    |> TM1638.init_display()

    assert Circuits.GPIO.read(tm.dio)
  end
end
