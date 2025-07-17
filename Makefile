all:
	ERL_FLAGS="-nostick" mix test test/nerves_runtime/auto_validate_test.exs
