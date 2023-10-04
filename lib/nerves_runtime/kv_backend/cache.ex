defmodule Nerves.Runtime.KVBackend.Cache do
  @moduledoc """
  Cache for a Key-Value store

  This module makes operating on KV stores more efficient. Note that it
  necessarily raises the potential for consistency issues. These are not
  handled. Barring important reasons, `Nerves.Runtime.KV` should be used.
  """

  require Logger

  defstruct [:backend, :options, :contents]

  @typedoc false
  @type t() :: %{backend: module(), options: keyword(), contents: Nerves.Runtime.KV.string_map()}

  defguardp is_module(v) when is_atom(v) and not is_nil(v)

  @doc """
  Create a new cache

  Options:
  * `:kv_backend` - a KV backend of the form `{module, options}` or just `module`
  """
  @spec new(keyword()) :: t()
  def new(options) do
    case options[:kv_backend] do
      {backend, opts} when is_module(backend) and is_list(opts) ->
        initialize(backend, opts)

      backend when is_module(backend) ->
        initialize(backend, [])

      _ ->
        # Handle Nerves.Runtime v0.12.0 and earlier way
        initial_contents =
          options[:modules][Nerves.Runtime.KV.Mock] || options[Nerves.Runtime.KV.Mock]

        Logger.error(
          "Using Nerves.Runtime.KV.Mock is deprecated. Use `config :nerves_runtime, kv_backend: {Nerves.Runtime.KVBackend.InMemory, contents: #{inspect(initial_contents)}}`"
        )

        initialize(Nerves.Runtime.KVBackend.InMemory, contents: initial_contents)
    end
  rescue
    error ->
      Logger.error("Nerves.Runtime has a bad KV configuration: #{inspect(error)}")
      initialize(Nerves.Runtime.KVBackend.InMemory, [])
  end

  defp initialize(backend, options) do
    case backend.load(options) do
      {:ok, contents} ->
        %{backend: backend, options: options, contents: contents}

      {:error, reason} ->
        Logger.error("Nerves.Runtime failed to load KV: #{inspect(reason)}")
        %{backend: Nerves.Runtime.KVBackend.InMemory, options: [], contents: %{}}
    end
  end

  @doc """
  Get the key for only the active firmware slot
  """
  @spec get_active(t(), String.t()) :: String.t() | nil
  def get_active(cache, key) when is_binary(key) do
    active(key, cache)
  end

  @doc """
  Get the key regardless of firmware slot
  """
  @spec get(t(), String.t()) :: String.t() | nil
  def get(cache, key) when is_binary(key) do
    Map.get(cache.contents, key)
  end

  @doc """
  Get all key value pairs for only the active firmware slot
  """
  @spec get_all_active(t()) :: Nerves.Runtime.KV.string_map()
  def get_all_active(cache) do
    active = active(cache) <> "."
    filter_trim_active(cache, active)
  end

  @doc """
  Get all keys regardless of firmware slot
  """
  @spec get_all(t()) :: Nerves.Runtime.KV.string_map()
  def get_all(cache) do
    cache.contents
  end

  @doc """
  Write a key-value pair to the firmware metadata
  """
  @spec put(t(), String.t(), String.t()) :: {:ok, t()} | {:error, any()}
  def put(cache, key, value) when is_binary(key) and is_binary(value) do
    put(cache, %{key => value})
  end

  @doc """
  Write a collection of key-value pairs to the firmware metadata
  """
  @spec put(t(), Nerves.Runtime.KV.string_map()) :: {:ok, t()} | {:error, any()}
  def put(cache, kv) when is_map(kv) do
    with :ok <- cache.backend.save(kv, cache.options) do
      {:ok, %{cache | contents: Map.merge(cache.contents, kv)}}
    end
  end

  @doc """
  Write a key-value pair to the active firmware slot
  """
  @spec put_active(t(), String.t(), String.t()) :: {:ok, t()} | {:error, any()}
  def put_active(cache, key, value) when is_binary(key) and is_binary(value) do
    put_active(cache, %{key => value})
  end

  @doc """
  Write a collection of key-value pairs to the active firmware slot
  """
  @spec put_active(t(), Nerves.Runtime.KV.string_map()) :: {:ok, t()} | {:error, any()}
  def put_active(cache, kv) when is_map(kv) do
    kvs = Map.new(kv, fn {key, value} -> {"#{active(cache)}.#{key}", value} end)
    put(cache, kvs)
  end

  defp active(cache), do: Map.get(cache.contents, "nerves_fw_active", "")

  defp active(key, cache) do
    Map.get(cache.contents, "#{active(cache)}.#{key}")
  end

  defp filter_trim_active(cache, active) do
    Enum.filter(cache.contents, fn {k, _} ->
      String.starts_with?(k, active)
    end)
    |> Enum.map(fn {k, v} -> {String.replace_leading(k, active, ""), v} end)
    |> Enum.into(%{})
  end
end
