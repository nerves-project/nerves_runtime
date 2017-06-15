defmodule Nerves.Runtime.KV do
  use GenServer
  require Logger

  def start_link(kv \\ "") do
    GenServer.start_link(__MODULE__, kv, name: __MODULE__)
  end

  def get_active(key) do
    GenServer.call(__MODULE__, {:get_active, key})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def get_all_active() do
    GenServer.call(__MODULE__, :get_all_active)
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

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
    reply =
      Enum.filter(s, fn({k, _}) ->
        String.starts_with?(k, active)
      end)
      |> Enum.into(%{})
    {:reply, reply, s}
  end

  def handle_call(:get_all, _from, s) do
    {:reply, s, s}
  end

  def load_kv(nil), do: %{}
  def load_kv(exec) do
    case System.cmd(exec, []) do
      {result, 0} ->
        parse_kv(result)
      _ ->
        Logger.warn "#{inspect __MODULE__} could not find executable fw_printenv"
        %{}
    end
  end

  def parse_kv(str) do
    String.split(str, "\n")
    |> Enum.map(& String.split(&1, "="))
    |> Enum.reduce(%{}, fn
      ([k, v], acc) ->
        Map.put(acc, k, v)
      (_, acc) -> acc
    end)
  end

  def active(s), do: Map.get(s, "nerves_fw_active", "")
  def active(key, s) do
    Map.get(s, "#{active(s)}.#{key}")
  end

end
