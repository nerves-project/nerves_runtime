defmodule Nerves.Runtime.FwupOps do
  @moduledoc """
  Convenience functions for /usr/share/fwup/ops.fw

  The `/usr/share/fwup/ops.fw` is provided by the Nerves system for handling
  some eMMC/MicroSD card operations. Look for `fwup-ops.conf` in the Nerves
  system source tree for more details. It used to be called
  `revert.fw`/`fwup-revert.conf` when it only handled reverting which firmware
  image was active.
  """

  alias Nerves.Runtime.Heart

  @old_revert_fw_path "/usr/share/fwup/revert.fw"
  @ops_fw_path "/usr/share/fwup/ops.fw"

  @typedoc """
  General options for utilities

  * `:devpath` - The location of the storage device (defaults to `"/dev/rootdisk0"`)
  * `:fwup_path` - The path to the `fwup` utility
  * `:ops_fw_path` - The path to the `ops.fw` file (defaults to `"/usr/share/fwup/ops.fw"`)
  * `:reboot` - Call `Nerves.Runtime.reboot/0` after running (defaults to
   `true` on destructive operations)
  """
  @type options() :: [devpath: String.t(), ops_fw_path: String.t(), reboot: boolean()]

  @doc """
  Revert to the previous firmware

  This invokes the "revert" task in the `ops.fw` and then reboots (unless told
  otherwise).  The revert task switches the active firmware partition to the
  opposite one so that future reboots use the previous firmware.
  """
  @spec revert(options()) :: :ok | {:error, reason :: any} | no_return()
  def revert(opts \\ []) do
    reboot? = Keyword.get(opts, :reboot, true)

    with :ok <- run_fwup("revert", opts) do
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
    run_fwup("prevent-revert", opts)
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
    run_fwup("validate", opts)
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

    with :ok <- run_fwup("factory-reset", opts) do
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

  defp run_fwup(task, opts) do
    devpath = Keyword.get(opts, :devpath, "/dev/rootdisk0")

    with {:ok, ops_fw} <- ops_fw_path(opts),
         {:ok, fwup} <- fwup_path(opts) do
      params = [ops_fw, "-t", task, "-d", devpath, "-q", "-U", "--enable-trim"]

      case System.cmd(fwup, params) do
        {_, 0} -> :ok
        {result, _} -> {:error, result}
      end
    end
  end

  defp fwup_path(opts) do
    fwup_path =
      opts[:fwup_path] || Application.get_env(:nerves_runtime, :fwup_path, "fwup")

    case System.find_executable(fwup_path) do
      nil -> {:error, "Can't find fwup"}
      path -> {:ok, path}
    end
  end

  defp ops_fw_path(opts) do
    app_path = Application.get_env(:nerves_runtime, :revert_fw_path)
    overridden_path = opts[:ops_fw_path]

    cond do
      is_binary(overridden_path) and File.exists?(overridden_path) -> {:ok, overridden_path}
      is_binary(app_path) and File.exists?(app_path) -> {:ok, app_path}
      File.exists?(@ops_fw_path) -> {:ok, @ops_fw_path}
      File.exists?(@old_revert_fw_path) -> {:ok, @old_revert_fw_path}
      true -> {:error, "ops.fw or revert.fw not found in Nerves system"}
    end
  end
end
