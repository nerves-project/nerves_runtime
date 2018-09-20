use Mix.Config

config :nerves_runtime, :enable_syslog, Mix.env() != :test

config :nerves_runtime,
  target: "host"
