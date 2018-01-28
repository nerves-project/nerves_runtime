defmodule Nerves.Runtime.KV do
  @moduledoc """
  Key Value Storage for firmware vairables provided by fwup

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

  @doc """
  Start the KV store server
  """
  def start_link(kv \\ "") do
    GenServer.start_link(__MODULE__, kv, name: __MODULE__)
  end

  @doc """
  Get the key for only the active firmware slot
  """
  def get_active(key) do
    GenServer.call(__MODULE__, {:get_active, key})
  end

  @doc """
  Get the key regardless of firmware slot
  """
  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Get all key value pairs for only the active firmware slot
  """
  def get_all_active() do
    GenServer.call(__MODULE__, :get_all_active)
  end

  @doc """
  Get all keys regardless of firmware slot
  """
  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  # GenServer API

  def init(_kv) do
    exec = System.find_executable("fw_printenv")
    s = load_kv(exec)
    {:ok, s}
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

  defp load_kv(nil), do: %{}

  defp load_kv(exec) do
    case System.cmd(exec, []) do
      {result, 0} ->
        parse_kv(result)

      _ ->
        Logger.warn("#{inspect(__MODULE__)} could not find executable fw_printenv")
        %{}
    end
  end

  def parse_kv(str) do
    String.split(str, "\n")
    |> Enum.map(&String.split(&1, "="))
    |> Enum.reduce(%{}, fn
      [k, v], acc ->
        Map.put(acc, k, v)

      _, acc ->
        acc
    end)
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
end
