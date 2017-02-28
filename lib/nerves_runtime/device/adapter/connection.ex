defmodule Nerves.Runtime.Device.Adapter.Connection do

  @callback handle_data_in(data :: any, state :: map) ::
    {:noreply, state :: map} |
    {:disconnect, state :: map}
end
