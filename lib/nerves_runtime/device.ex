defmodule Nerves.Runtime.Device do
  require Logger

  @moduledoc """
  This is a utility module for triggering UEvents from the Linux kernel. You
  don't need to use it directly. See the README.md for receiving events when
  devices are added or removed from the system.
  """

  @doc """
  Send an "add" request to all existing devices so that the UEvent handler
  can know about them.
  """
  @spec discover() :: :ok
  def discover() do
    cmd = Application.app_dir(:nerves_runtime, ["priv", "nerves_runtime"])

    {_, code} = System.cmd(cmd, [], arg0: "uevent_discover")

    if code != 0 do
      Logger.error("Unexpected error from uevent discovery")
    end

    :ok
  end
end
