if Code.ensure_loaded?(Nerves.UART) do
  defmodule Nerves.Runtime.Device.Adapters.Tty do
    use Nerves.Runtime.Device.Adapter,
      subsystem: :tty

    require Logger

    def attributes(device) do
      <<"/dev/", device_file :: binary>> = Nerves.Runtime.Device.device_file(device)

      info =
        Nerves.UART.enumerate
        |> Enum.find(fn ({dev_file, _}) -> dev_file == device_file end)

      case info do
        {_, attributes} -> attributes
        nil -> %{}
      end
    end

    def handle_connect(device, s) do
      case Nerves.Runtime.Device.device_file(device) do
        <<"/dev/", devfile :: binary>> ->
          {:ok, pid} = Nerves.UART.start_link()
          Nerves.UART.configure(pid, s.opts)
          Nerves.UART.open(pid, devfile, s.opts)
          {:ok, Map.put(s, :driver, pid)}
        _ -> {:error, "no dev file found", s}
      end
    end

    def handle_info({:nerves_uart, _dev, message}, s) do
      {:data_in, message, s}
    end
  end
end
