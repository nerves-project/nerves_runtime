# SPDX-FileCopyrightText: 2024 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0
#
all: ops-fail.fw ops.fw

%.fw: %.conf
	fwup -c -f $< -o $@

.PHONY: all
