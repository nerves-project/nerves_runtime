defmodule Nerves.Runtime.KVBackend do
  @moduledoc """
  Behaviour for customizing the Nerves Runtime's key-value store
  """
  alias Nerves.Runtime.KV

  @doc """
  Load the KV store and return its contents

  This will be called on boot and should return all persisted key/value pairs.
  The results will be cached and if a change should be persisted, `c:save/2` will
  be called with the update.
  """
  @callback load(options :: keyword) ::
              {:ok, contents :: KV.string_map()} | {:error, reason :: any}

  @doc """
  Persist the updated KV pairs

  The KV map contains the KV pairs returned by `c:load/1` with any changes made
  by users of `Nerves.Runtime.KV`.
  """
  @callback save(contents :: KV.string_map(), options :: keyword) :: :ok | {:error, reason :: any}
end
