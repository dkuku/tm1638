defmodule TM1638 do
  defstruct dio: nil,
            clk: nil,
            stb: nil,
            brightness: 1

  @type t :: map()
  @type bit :: 1 | 0
  @type brightness :: 1..7
  @type pin :: non_neg_integer()

  import Bitwise
  alias TM1638
  alias Circuits.GPIO

  @read_mode 0x02
  @write_mode 0x00
  @incr_addr 0x00
  @fixed_addr 0x04
  @display_length 8
  @default_brightness 3

  @spec init(list) :: {:ok, TM1638.t()}
  def init(_args \\ []) do
    dio = Application.fetch_env!(:tm1638, :dio)
    clk = Application.fetch_env!(:tm1638, :clk)
    stb = Application.fetch_env!(:tm1638, :stb)
    brightness = Application.get_env(:tm1638, :brightness, @default_brightness)

    {:ok, init(dio, clk, stb, brightness)}
  end

  @spec init(pin, pin, pin, integer) :: TM1638.t()
  def init(dio, clk, stb, brightness \\ @default_brightness) do
    {:ok, dio_id} = GPIO.open(dio, :output)
    {:ok, clk_id} = GPIO.open(clk, :output)
    {:ok, stb_id} = GPIO.open(stb, :output)

    tm = %__MODULE__{
      dio: dio_id,
      clk: clk_id,
      stb: stb_id,
      brightness: brightness
    }

    init_display(tm)
  end

  @spec init_display(TM1638.t()) :: TM1638.t()
  def init_display(tm) do
    tm
    |> cs_disable()
    |> clock_high()
    |> turn_on()
    |> clear_display()
  end

  @spec cs_disable(TM1638.t()) :: TM1638.t()
  def cs_disable(tm) do
    GPIO.write(tm.stb, 1)
    tm
  end

  @spec cs_enable(TM1638.t()) :: TM1638.t()
  def cs_enable(tm) do
    GPIO.write(tm.stb, 0)
    tm
  end

  @spec clock_high(TM1638.t()) :: TM1638.t()
  def clock_high(tm) do
    GPIO.write(tm.clk, 1)
    tm
  end

  @spec clock_low(TM1638.t()) :: TM1638.t()
  def clock_low(tm) do
    GPIO.write(tm.clk, 0)
    tm
  end

  @spec data_high(TM1638.t()) :: TM1638.t()
  def data_high(tm) do
    GPIO.write(tm.dio, 1)
    tm
  end

  @spec data_low(TM1638.t()) :: TM1638.t()
  def data_low(tm) do
    GPIO.write(tm.dio, 0)
    tm
  end

  @spec data_set_to(TM1638.t(), bit) :: TM1638.t()
  def data_set_to(tm, value) do
    GPIO.write(tm.dio, value)
    tm
  end

  @doc """
  Clear the display
  Turn off every led
  """
  @spec clear_display(TM1638.t()) :: TM1638.t()
  def clear_display(tm) do
    tm
    |> cs_enable()
    # set data read mode (automatic address increased)
    |> set_data_mode(@write_mode, @incr_addr)
    # address command set to the 1st address
    |> send_byte(0xC0)

    for _i <- 1..(@display_length * 2) do
      # set to zero all the addresses
      send_byte(tm, 0x00)
    end

    cs_disable(tm)
  end

  @doc """
  Turn off (physically) the leds
  """
  @spec turn_off(TM1638.t()) :: TM1638.t()
  def turn_off(tm) do
    send_command(tm, 0x80)
  end

  @doc """
  Turn on the display and set the brightness
  The pulse width used is set to:

  0 => 1/16
  1 => 2/16
  2 => 4/16
  3 => 10/16
  4 => 11/16
  5 => 12/16
  6 => 13/16
  7 => 14/16
  """
  @spec turn_on(TM1638.t()) :: TM1638.t()
  def turn_on(tm) do
    send_command(tm, 0x88 ||| (tm.brightness &&& 7))
  end

  def turn_on(tm, _brightness), do: tm

  @doc """
  Set Leds
  values accepts an integer in range 0..255
  and sets all leds according to the bits in integer
  """
  @spec leds(TM1638.t(), byte) :: TM1638.t()
  def leds(tm, values) when values in 0..255 do
    for <<(bit::1 <- <<values>>)>> do
      bit
    end
    |> Enum.with_index()
    |> Enum.each(fn {bit, index} -> led(tm, index, bit) end)

    tm
  end

  @doc """
  Set single led to on or off
  the leds are on the bit 0 of the odd addresses 
  (led_0 on address 1, led_1 on address 3)
  """
  @spec led(TM1638.t(), 0..7, bit) :: TM1638.t()
  def led(tm, index, value) when index in 0..7 and value in 0..1 do
    send_data(tm, rem(index, @display_length) * 2 + 1, value)
  end

  @doc """
  Send a command
  """
  @spec send_command(TM1638.t(), byte) :: TM1638.t()
  def send_command(tm, cmd) do
    tm
    |> cs_enable()
    |> send_byte(cmd)
    |> cs_disable()
  end

  @doc """
  Send a data at address
  """
  @spec send_data(TM1638.t(), byte, byte) :: TM1638.t()
  def send_data(tm, address, data) do
    tm
    |> cs_enable()
    |> set_data_mode(@write_mode, @fixed_addr)
    # set address and send byte (stb must go high and low before sending address)
    |> cs_disable()
    |> cs_enable()
    |> send_byte(0xC0 ||| address)
    |> send_byte(data)
    |> cs_disable()
  end

  @doc """
  Set the data modes
  :param wr_mode: read_mode (read the key scan) or write_mode (write data)
  :param addr_mode: incr_addr (automatic address increased) or fixed_addr
  """
  @spec set_data_mode(TM1638.t(), byte, byte) :: TM1638.t()
  def set_data_mode(tm, wr_mode, addr_mode) do
    send_byte(tm, 0x40 ||| wr_mode ||| addr_mode)
  end

  @doc """
  Send a byte (STROBE must be Low)

  Sending a bit from a byte consists of setting the STROBE to low
  Then setting to CLOCK to low, sending the bit via dio and
  setting the clock back to HIGH..
  """
  @spec send_byte(TM1638.t(), byte, integer) :: TM1638.t()
  def send_byte(tm, data, counter \\ 8)

  def send_byte(tm, data, counter) when counter > 0 do
    tm
    |> clock_low()
    |> data_set_to(data &&& 1)
    |> clock_high()

    send_byte(tm, data >>> 1, counter - 1)
  end

  def send_byte(tm, _data, _counter), do: tm

  @doc """
  Get the data buttons the four octets read
  on rpi ver B it takes around 16ms to get the whole 4 bits
  """
  @spec get_data(TM1638.t()) :: TM1638.t()
  def get_data(tm) do
    # set in read mode
    tm
    |> cs_enable()
    |> set_data_mode(@read_mode, @incr_addr)

    GPIO.set_pull_mode(tm.dio, :pullup)
    GPIO.set_direction(tm.dio, :input)
    GPIO.set_interrupts(tm.dio, :both)
    bytes = get_bytes(tm, 4)
    GPIO.set_direction(tm.dio, :output)

    cs_disable(tm)

    bytes
  end

  @doc """
  Receive the bytes_count from the board

  """
  @spec get_bytes(TM1638.t(), integer) :: TM1638.t()
  def get_bytes(tm, bytes_count \\ 4) do
    # read 4 bytes
    Enum.reduce(1..bytes_count, [], fn _x, bytes ->
      # read 8 bits
      byte =
        Enum.reduce(1..8, 0, fn _x, bit ->
          clock_low(tm)
          bit = bit >>> 1
          bit = if Circuits.GPIO.read(tm.dio) == 1, do: bit ||| 0x80, else: bit
          clock_high(tm)
          bit
        end)

      [byte | bytes]
    end)
  end

  @doc """
  Example:
  TM1638.display_segment(tm,1, "")
  -> set the i-th 7-segment display (and all the following, according to the length of value1)
  all the 7-segment displays after the #i are filled by the characters in value1
  this could be one-character string (so 7-segment #i is set to that character)
  or a longer string, and the following 7-segment displays are modified accordingly
  """
  @spec display_segment(TM1638.t(), integer, byte) :: TM1638.t()
  def display_segment(tm, index, value) do
    charbyte = Map.get(TM1638.Font.font(), value, " ")

    send_data(tm, rem(index, @display_length) * 2, charbyte)
  end

  @doc """
  Displays text starting from the correct position
  """
  @spec display_text(TM1638.t(), String.t(), integer) :: TM1638.t()
  def display_text(tm, text, start \\ 0)

  def display_text(tm, text, start) when is_binary(text) and start < 0 do
    text = String.duplicate(" ", -start) <> text
    display_text(tm, text)
  end

  def display_text(tm, text, start) when is_binary(text) do
    char_list =
      text
      |> String.slice(start..(start + @display_length))
      |> String.pad_trailing(@display_length)
      |> String.split("", trim: true)

    display_text(tm, char_list)
  end

  @spec display_text(TM1638.t(), [String.t()], integer) :: TM1638.t()
  def display_text(tm, char_list, _start) do
    char_list
    |> Enum.take(@display_length)
    |> Enum.with_index()
    |> Enum.each(fn {char, location} ->
      display_segment(tm, location, char)
    end)

    tm
  end

  @spec display_moving_text(TM1638.t(), String.t(), integer) :: TM1638.t()
  def display_moving_text(tm, text, speed \\ 500) do
    text_length = String.length(text)

    -@display_length
    |> Range.new(text_length + @display_length, 1)
    |> Enum.map(fn index ->
      display_text(tm, text, index)
      Process.sleep(speed)
    end)

    tm
  end
end
