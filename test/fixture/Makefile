all: ops-status.fw ops-fail.fw ops.fw

%.fw: %.conf
	fwup -c -f $< -o $@

.PHONY: all
