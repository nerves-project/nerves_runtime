defmodule Nerves.Runtime.KV do
  @moduledoc """
  Key Value Storage for firmware variables provided by fwup

  KV provides access to metadata variables set by fwup.
  It can be used to obtain information such as the active
  firmware slot, where the application data partition
  is located, etc.

  Values are stored in two ways.
  * Values that do not pertain to a specific firmware slot
  For example:
    `"nerves_fw_active" => "a"`

  * Values that pertain to a specific firmware slot
  For Example:
    `"a.nerves_fw_author" => "The Nerves Team"`

  You can find values for just the active firmware slot by
  using get_active and get_all_active. The result of these
  functions will trim the firmware slot (`"a."` or `"b."`)
  from the leading characters of the keys returned.
  """

  use GenServer
  require Logger

  @callback init(opts :: any) :: initial_state :: map

  alias __MODULE__

  mod =
    if Nerves.Runtime.target() != "host" do
      KV.UBootEnv
    else
      KV.Mock
    end

  @default_mod mod

  @doc """
  Start the KV store server
  """
  @spec start_link(any()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get the key for only the active firmware slot
  """
  @spec get_active(String.t()) :: String.t() | nil
  def get_active(key) do
    GenServer.call(__MODULE__, {:get_active, key})
  end

  @doc """
  Get the key regardless of firmware slot
  """
  @spec get(String.t()) :: String.t() | nil
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Get all key value pairs for only the active firmware slot
  """
  @spec get_all_active() :: map()
  def get_all_active() do
    GenServer.call(__MODULE__, :get_all_active)
  end

  @doc """
  Get all keys regardless of firmware slot
  """
  @spec get_all() :: map()
  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  def init(opts) do
    {:ok, mod().init(opts)}
  end

  def handle_call({:get_active, key}, _from, s) do
    {:reply, active(key, s), s}
  end

  def handle_call({:get, key}, _from, s) do
    {:reply, Map.get(s, key), s}
  end

  def handle_call(:get_all_active, _from, s) do
    active = active(s) <> "."
    reply = filter_trim_active(s, active)
    {:reply, reply, s}
  end

  def handle_call(:get_all, _from, s) do
    {:reply, s, s}
  end

  defp active(s), do: Map.get(s, "nerves_fw_active", "")

  defp active(key, s) do
    Map.get(s, "#{active(s)}.#{key}")
  end

  defp filter_trim_active(s, active) do
    Enum.filter(s, fn {k, _} ->
      String.starts_with?(k, active)
    end)
    |> Enum.map(fn {k, v} -> {String.replace_leading(k, active, ""), v} end)
    |> Enum.into(%{})
  end

  defp mod() do
    Application.get_env(:nerves_runtime, :modules)[__MODULE__] || @default_mod
  end
end
