defmodule Nerves.Runtime.UBootEnv.Tools do
  alias Nerves.Runtime.UBootEnv

  @moduledoc """
  This module uses U-boot tools' `fw_printenv` to read environment blocks.
  It is only useful on systems running old versions of OTP that can't read
  device files. This module has a known issue with parsing key/value pairs
  with embedded newlines.
  """

  @doc """
  Decode a U-Boot environment block using `fw_printenv`
  """
  @spec fw_printenv() :: {:ok, map()} | {:error, reason :: String.t()}
  def fw_printenv() do
    case exec("fw_printenv") do
      {:ok, env} -> {:ok, decode(env)}
      error -> error
    end
  end

  @doc """
  Set a U-Boot variable using `fw_setenv`.
  """
  @spec fw_setenv(String.t(), String.t()) ::
          :ok
          | {:error, reason :: String.t()}
  def fw_setenv(key, value) do
    case exec("fw_printenv", [key, value]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  @doc """
  Decode the output of `fw_printenv`
  """
  @spec decode(String.t()) :: map()
  def decode(env) when is_binary(env) do
    String.split(env, "\n", trim: true)
    |> UBootEnv.decode()
  end

  defp exec(cmd, args \\ []) do
    if exec = System.find_executable(cmd) do
      case System.cmd(exec, args) do
        {result, 0} ->
          {:ok, String.trim(result)}

        {result, _code} ->
          {:error, result}
      end
    else
      {:error, cmd <> " not found"}
    end
  end
end
