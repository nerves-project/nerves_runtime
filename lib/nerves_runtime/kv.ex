defmodule Nerves.Runtime.KV do
  @moduledoc """
  Key Value storage for firmware variables provided by fwup.

  KV provides functionality to read and modify firmware metadata set by fwup.
  The firmware metadata contains information such as the active firmware
  slot, where the application data partition is located, etc. The firmware
  metadata store is a simple key-value store where both keys and values are
  stored as strings.

  The firmware metadata is stored in the U-boot environment block stored at
  the beginning of the disk outside of actual partitions. It is not stored
  redundantly, and it can be susceptible to corruption in case of power
  failure during writes. For this reason, it is recommended to use the
  firmware metadata with caution. The access patterns in this module lower
  the risk of corruption, and risk can be lowered further by storing as
  little data as possible in the firmware metadata.

  `UBootEnv` can alternatively be used for more direct access to the firmware
  metadata. However, since KV utilizes caching of the firmware metadata, you
  should use either KV or UBootEnv, not both.

  ## Examples

  Getting all firmware metadata:

      iex> Nerves.Runtime.KV.get_all()
      %{
        "a.nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
        "a.nerves_fw_application_part0_fstype" => "ext4",
        "a.nerves_fw_application_part0_target" => "/root",
        "a.nerves_fw_architecture" => "arm",
        "a.nerves_fw_author" => "The Nerves Team",
        "a.nerves_fw_description" => "",
        "a.nerves_fw_misc" => "",
        "a.nerves_fw_platform" => "rpi0",
        "a.nerves_fw_product" => "test_app",
        "a.nerves_fw_uuid" => "d9492bdb-94de-5288-425e-2de6928ef99c",
        "a.nerves_fw_vcs_identifier" => "",
        "a.nerves_fw_version" => "0.1.0",
        "b.nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
        "b.nerves_fw_application_part0_fstype" => "ext4",
        "b.nerves_fw_application_part0_target" => "/root",
        "b.nerves_fw_architecture" => "arm",
        "b.nerves_fw_author" => "The Nerves Team",
        "b.nerves_fw_description" => "",
        "b.nerves_fw_misc" => "",
        "b.nerves_fw_platform" => "rpi0",
        "b.nerves_fw_product" => "test_app",
        "b.nerves_fw_uuid" => "4e08ad59-fa3c-5498-4a58-179b43cc1a25",
        "b.nerves_fw_vcs_identifier" => "",
        "b.nerves_fw_version" => "0.1.1",
        "nerves_fw_active" => "b",
        "nerves_fw_devpath" => "/dev/mmcblk0",
        "nerves_serial_number" => ""
      }

  Parts of the firmware metadata are global, while others pertain to a
  specific firmware slot. This is indicated by the key - data which describes
  firmware of a specific slot have keys prefixed with the name of the
  firmware slot. In the above example, `"nerves_fw_active"` and
  `"nerves_serial_number"` are global, while `"a.nerves_fw_version"` and
  `"b.nerves_fw_version"` apply to the "a" and "b" firmware slots,
  respectively.

  It is also possible to get firmware metadata that only pertains to the
  currently active firmware slot:

      iex> Nerves.Runtime.KV.get_all_active()
      %{
        "nerves_fw_application_part0_devpath" => "/dev/mmcblk0p3",
        "nerves_fw_application_part0_fstype" => "ext4",
        "nerves_fw_application_part0_target" => "/root",
        "nerves_fw_architecture" => "arm",
        "nerves_fw_author" => "The Nerves Team",
        "nerves_fw_description" => "",
        "nerves_fw_misc" => "",
        "nerves_fw_platform" => "rpi0",
        "nerves_fw_product" => "test_app",
        "nerves_fw_uuid" => "4e08ad59-fa3c-5498-4a58-179b43cc1a25",
        "nerves_fw_vcs_identifier" => "",
        "nerves_fw_version" => "0.1.1"
      }

  Note that `get_all_active/0` strips out the `a.` and `b.` prefixes.

  Further, the two functions `get/1` and `get_active/1` allow you to get a
  specific key from the firmware metadata. `get/1` requires specifying the
  entire key name, while `get_active/1` will prepend the slot prefix for you:

      iex> Nerves.Runtime.KV.get("nerves_fw_active")
      "b"
      iex> Nerves.Runtime.KV.get("b.nerves_fw_uuid")
      "4e08ad59-fa3c-5498-4a58-179b43cc1a25"
      iex> Nerves.Runtime.KV.get_active("nerves_fw_uuid")
      "4e08ad59-fa3c-5498-4a58-179b43cc1a25"

  Aside from reading values from the KV store, it is also possible to write
  new values to the firmware metadata. New values may either have unique keys,
  in which case they will be added to the firmware metadata, or re-use a key,
  in which case they will overwrite the current value with that key:

      iex> :ok = Nerves.Runtime.KV.put("my_firmware_key", "my_value")
      iex> :ok = Nerves.Runtime.KV.put("nerves_serial_number", "my_new_serial_number")
      iex> Nerves.Runtime.KV.get("my_firmware_key")
      "my_value"
      iex> Nerves.Runtime.KV.get("nerves_serial_number")
      "my_new_serial_number"

  It is possible to write a collection of values at once, in order to
  minimize number of writes:

      iex> :ok = Nerves.Runtime.KV.put(%{"one_key" => "one_val", "two_key" => "two_val"})
      iex> Nerves.Runtime.KV.get("one_key")
      "one_val"

  Lastly, `put_active/1` and `put_active/2` allow you to write firmware metadata to the
  currently active firmware slot without specifying the slot prefix yourself:

      iex> :ok = Nerves.Runtime.KV.put_active("nerves_fw_misc", "Nerves is awesome")
      iex> Nerves.Runtime.KV.get_active("nerves_fw_misc")
      "Nerves is awesome"
  """

  use GenServer
  require Logger

  @callback init(opts :: any) :: initial_state :: map
  @callback put(state :: map) :: :ok | {:error, reason :: any()}

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

  @doc """
  Write a key-value pair to the firmware metadata
  """
  @spec put(String.t(), String.t()) :: :ok
  def put(key, value) do
    GenServer.call(__MODULE__, {:put, %{key => value}})
  end

  @doc """
  Write a collection of key-value pairs to the firmware metadata
  """
  @spec put(map()) :: :ok
  def put(kv) do
    GenServer.call(__MODULE__, {:put, kv})
  end

  @doc """
  Write a key-value pair to the active firmware slot
  """
  @spec put_active(String.t(), String.t()) :: :ok
  def put_active(key, value) do
    GenServer.call(__MODULE__, {:put_active, %{key => value}})
  end

  @doc """
  Write a collection of key-value pairs to the active firmware slot
  """
  @spec put_active(map()) :: :ok
  def put_active(kv) do
    GenServer.call(__MODULE__, {:put_active, kv})
  end

  @impl true
  def init(opts) do
    {:ok, mod().init(opts)}
  end

  @impl true
  def handle_call({:get_active, key}, _from, s) do
    {:reply, active(key, s), s}
  end

  @impl true
  def handle_call({:get, key}, _from, s) do
    {:reply, Map.get(s, key), s}
  end

  @impl true
  def handle_call(:get_all_active, _from, s) do
    active = active(s) <> "."
    reply = filter_trim_active(s, active)
    {:reply, reply, s}
  end

  @impl true
  def handle_call(:get_all, _from, s) do
    {:reply, s, s}
  end

  @impl true
  def handle_call({:put, kv}, _from, s) do
    {reply, s} = do_put(kv, s)
    {:reply, reply, s}
  end

  @impl true
  def handle_call({:put_active, kv}, _from, s) do
    {reply, s} =
      Map.new(kv, fn {key, value} -> {"#{active(s)}.#{key}", value} end)
      |> do_put(s)

    {:reply, reply, s}
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

  defp do_put(kv, s) do
    case mod().put(kv) do
      :ok -> {:ok, Map.merge(s, kv)}
      error -> {error, s}
    end
  end

  defp mod() do
    Application.get_env(:nerves_runtime, :modules)[__MODULE__] || @default_mod
  end
end
