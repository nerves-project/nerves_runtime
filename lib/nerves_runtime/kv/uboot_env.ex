defmodule Nerves.Runtime.KV.UBootEnv do
  @moduledoc """
  ## Technical Information

  Nerves.Runtime.KV.UBootEnv uses a non-replicated U-Boot environment block for
  storing firmware and provisioning information. It has the following format:

    * CRC32 of bytes 4 through to the end
    * `"<key>=<value>\0"` for each key/value pair
    * `"\0"` an empty key/value pair to terminate the list.
      This looks like "\0\0" when you're viewing the file in a hex editor.
    * Filler bytes to the end of the environment block. These are usually `0xff`.

  The U-Boot environment configuration is loaded from /etc/fw_env.config.
  If you are using OTP >= 21, the contents of the U-Boot environment will be
  read directly from the device. This addresses an issue with parsing
  multi-line values from a call to `fw_printenv`.
  """

  @behaviour Nerves.Runtime.KV

  alias Nerves.Runtime.UBootEnv

  def init(_opts) do
    case UBootEnv.read() do
      {:ok, kv} -> kv
      _error -> %{}
    end
  end

  def put(key, value) do
    case UBootEnv.read() do
      {:ok, kv} ->
        kv
        |> Map.put(key, value)
        |> UBootEnv.write()

      error ->
        error
    end
  end
end
