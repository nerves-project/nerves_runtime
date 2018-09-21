defmodule Nerves.Runtime.UBootEnv.Tools do
  alias Nerves.Runtime.UBootEnv

  @spec fw_setenv(key :: binary, value :: binary) ::
          {:ok, env :: [binary]}
          | {:error, reason :: binary}
  def fw_printenv do
    case exec("fw_printenv") do
      {:ok, env} -> {:ok, decode(env)}
      error -> error
    end
  end

  @spec fw_setenv(key :: binary, value :: binary) ::
          :ok
          | {:error, reason :: binary}
  def fw_setenv(key, value) do
    case exec("fw_printenv", [key, value]) do
      {:ok, _} -> :ok
      error -> error
    end
  end

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
