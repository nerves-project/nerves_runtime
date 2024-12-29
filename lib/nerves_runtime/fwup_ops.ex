defmodule Nerves.Runtime.FwupOps do
  @moduledoc """
  Functions for managing firmware slots via an ops.fw file

  The `/usr/share/fwup/ops.fw` is provided by the Nerves system for handling
  some eMMC/MicroSD card operations. Look for `fwup-ops.conf` in the Nerves
  system source tree for more details. It used to be called
  `revert.fw`/`fwup-revert.conf` when it only handled reverting which firmware
  image was active.

  This is a GenServer to maintain state and serialize firmware slot operations.
  """
  use GenServer

  alias Nerves.Runtime.Heart
  alias Nerves.Runtime.KV

  @old_revert_fw_path "/usr/share/fwup/revert.fw"
  @ops_fw_path "/usr/share/fwup/ops.fw"

  @typedoc """
  Options for calling fwup

  * `:devpath` - The location of the storage device (defaults to `"/dev/rootdisk0"`)
  * `:fwup_env` - Additional environment variables to pass to `fwup`
  * `:fwup_path` - The path to the `fwup` utility
  * `:ops_fw_path` - The path to the `ops.fw` file (defaults to `"/usr/share/fwup/ops.fw"`)
  * `:reboot` - Call `Nerves.Runtime.reboot/0` after running (defaults to
   `true` on destructive operations)
  """
  @type options() :: [
          devpath: String.t(),
          fwup_env: %{String.t() => String.t()},
          fwup_path: String.t(),
          ops_fw_path: String.t(),
          reboot: boolean()
        ]

  @doc """
  Start the FwupOps GenServer

  Pass in the default options for running `fwup`. They can be overridden
  on a one-off basis by passing options to other functions.
  """
  @spec start_link(options()) :: GenServer.on_start()
  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args, name: __MODULE__)
  end

  @doc """
  Revert to the previous firmware

  This invokes the "revert" task in the `ops.fw` and then reboots (unless told
  otherwise).  The revert task switches the active firmware partition to the
  opposite one so that future reboots use the previous firmware.
  """
  @spec revert(options()) :: :ok | {:error, reason :: any} | no_return()
  def revert(opts \\ []) do
    reboot? = Keyword.get(opts, :reboot, true)

    with {:ok, _} <- call_run_fwup("revert", opts) do
      if reboot? do
        Nerves.Runtime.reboot()
      else
        :ok
      end
    end
  end

  @doc """
  Make it impossible to revert to the other partition

  This wipes the opposite firmware partition and clears out metadata for it.
  Attempts to revert will fail. This is useful if loading a special firmware
  temporarily that shouldn't be used again even accidentally.
  """
  @spec prevent_revert(options()) :: :ok | {:error, reason :: any}
  def prevent_revert(opts \\ []) do
    with {:ok, _} <- call_run_fwup("prevent-revert", opts) do
      KV.reload()
    end
  end

  @doc """
  Validate the current partition

  For Nerves systems that support automatic rollback of firmware versions, this
  marks the partition as good so that it will continue to be used on future
  boots.

  Call `Nerves.Runtime.validate_firmware/0` instead.
  """
  @spec validate(options()) :: :ok | {:error, reason :: any}
  def validate(opts \\ []) do
    with {:ok, _} <- call_run_fwup("validate", opts) do
      KV.reload()
    end
  end

  @doc """
  Reset the application data partition to its original state

  This clears out the application data partition at a low level so that it will
  be reformatted on the next boot. If all application settings are stored on
  the partition, then this will be like a factory reset. Be aware that many
  settings are stored on the application data partition including network
  settings like WiFi SSIDs and passwords. Factory reset devices may not connect
  to the network afterwards.
  """
  @spec factory_reset(options()) :: :ok | {:error, reason :: any}
  def factory_reset(opts \\ []) do
    reboot? = Keyword.get(opts, :reboot, true)

    with {:ok, _} <- call_run_fwup("factory-reset", opts) do
      if reboot? do
        # Graceful shutdown can cause writes to happen that may undo parts of
        # the factory reset, so ungracefully reboot to minimize the time
        # window of this happening after the call to `fwup`.
        Heart.guarded_immediate_reboot()
      else
        :ok
      end
    end
  end

  @doc """
  Return boot status

  This invokes the "status" task in the `ops.fw` to report the current
  firmware slot and what slot will be tried on the next reboot. The `ops.fw`
  is expected to print the slot name or two slot names separated by "->".
  """
  @spec status(options()) ::
          {:ok, %{current: String.t(), next: String.t()}} | {:error, reason :: any}
  def status(opts \\ []) do
    with {:ok, raw_result} <- call_run_fwup("status", opts),
         {:ok, result} <- deframe(raw_result, []) do
      Enum.find_value(result, {:error, "Invalid status"}, &find_status/1)
    end
  end

  defp find_status({:warning, <<slot::1-bytes>>}), do: {:ok, %{current: slot, next: slot}}

  defp find_status({:warning, <<current::1-bytes, "->", next::1-bytes>>}),
    do: {:ok, %{current: current, next: next}}

  defp find_status(_status), do: nil

  @impl GenServer
  def init(init_args) do
    # Handle old :reverse_fw_path option
    default_ops_fw_path = Keyword.get(init_args, :revert_fw_path, @ops_fw_path)

    defaults = [
      # devpath: "/dev/rootdisk0",
      # fwup_env: %{},
      # fwup_path: "fwup",
      ops_fw_path: default_ops_fw_path
    ]

    specified_options = Keyword.take(init_args, [:devpath, :fwup_env, :fwup_path, :ops_fw_path])

    {:ok, Keyword.merge(defaults, specified_options)}
  end

  @impl GenServer
  def handle_call({:run_fwup, task, options}, _from, default_options) do
    result = run_fwup(task, Keyword.merge(default_options, options))
    {:reply, result, default_options}
  end

  defp call_run_fwup(task, options) do
    GenServer.call(__MODULE__, {:run_fwup, task, options}, 1000)
  catch
    :exit, {:noproc, _} ->
      {:error, "FwupOps server not running"}
  end

  defp run_fwup(task, opts) do
    with {:ok, ops_fw} <- ops_fw_path(opts),
         {:ok, fwup} <- fwup_path(opts) do
      params = [
        "-a",
        "-i",
        ops_fw,
        "-t",
        task,
        "-d",
        opts[:devpath],
        "-q",
        "-U",
        "--enable-trim",
        "--framing"
      ]

      case System.cmd(fwup, params, env: opts[:fwup_env]) do
        {results, 0} -> {:ok, results}
        {result, _} -> output_to_error(result)
      end
    end
  end

  defp output_to_error(raw_result) do
    with {:ok, result} <- deframe(raw_result, []) do
      Enum.find(result, {:error, "Unknown"}, &find_error/1)
    end
  end

  defp find_error({:error, _message}), do: true
  defp find_error(_status), do: false

  defp fwup_path(opts) do
    case System.find_executable(opts[:fwup_path]) do
      nil -> {:error, "can't find fwup"}
      path -> {:ok, path}
    end
  end

  defp ops_fw_path(opts) do
    ops_fw_path = opts[:ops_fw_path]

    cond do
      is_binary(ops_fw_path) and File.exists?(ops_fw_path) -> {:ok, ops_fw_path}
      File.exists?(@ops_fw_path) -> {:ok, @ops_fw_path}
      File.exists?(@old_revert_fw_path) -> {:ok, @old_revert_fw_path}
      true -> {:error, "ops.fw or revert.fw not found in Nerves system"}
    end
  end

  defp deframe(<<length::32, payload::binary-size(length), rest::binary>>, acc) do
    case decode(payload) do
      {:ok, result} -> deframe(rest, [result | acc])
      {:error, _} -> {:error, "Invalid framing"}
    end
  end

  defp deframe(<<>>, acc) do
    {:ok, Enum.reverse(acc)}
  end

  defp deframe(_, _acc) do
    {:error, "Invalid framing"}
  end

  defp decode(<<"OK", _result::16, _meassage::binary>>), do: {:ok, :ok}
  defp decode(<<"ER", _error_code::16, message::binary>>), do: {:ok, {:error, message}}
  defp decode(<<"WN", _code::16, meassage::binary>>), do: {:ok, {:warning, meassage}}
  defp decode(<<"PR", percent::16>>), do: {:ok, {:progress, percent}}
  defp decode(_), do: {:error, "Invalid message"}
end
