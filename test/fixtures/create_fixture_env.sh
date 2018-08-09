#!/bin/sh

# Create the test environment file manually so that users of nerves_runtime
# don't need uboot-tools and fwup installed.

set -e

FIXTURE_UBOOT=fixture_uboot.bin
FIXTURE_FWUP=fixture_fwup.bin

rm -f $FIXTURE_UBOOT
rm -f $FIXTURE_FWUP

# Create a U-boot environment block using the uboot-tools
dd if=/dev/zero of=$FIXTURE_UBOOT count=24
fw_setenv -c support/fixture_fw_env.config -s support/fixture_env.script

# Create a U-boot environment block using fwup
fwup -c -f support/fixture_env_fwup.conf -o fixture_env_fwup.fw
fwup -d $FIXTURE_FWUP fixture_env_fwup.fw
rm -f fixture_env_fwup.fw
