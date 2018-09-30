# Variables to override
#
# CC            C compiler
# CROSSCOMPILE	crosscompiler prefix, if any
# CFLAGS	compiler flags for compiling all C files
# ERL_CFLAGS	additional compiler flags for files using Erlang header files
# ERL_EI_INCLUDE_DIR include path to ei.h (Required for crosscompile)
# ERL_EI_LIBDIR path to libei.a (Required for crosscompile)
# LDFLAGS	linker flags for linking all binaries
# ERL_LDFLAGS	additional linker flags for projects referencing Erlang libraries

# Check that we're on a supported build platform
ifeq ($(CROSSCOMPILE),)
    # Not crosscompiling, so check that we're on Linux.
    ifneq ($(shell uname -s),Linux)
        $(warning nerves_runtime only works on Linux, but crosscompilation)
        $(warning is supported by defining $$CROSSCOMPILE, $$ERL_EI_INCLUDE_DIR,)
        $(warning and $$ERL_EI_LIBDIR. See Makefile for details. If using Nerves,)
        $(warning this should be done automatically.)
        $(warning .)
        $(warning Skipping C compilation unless targets explicitly passed to make.)
	DEFAULT_TARGETS = priv
    endif
endif
DEFAULT_TARGETS ?= priv priv/uevent priv/kmsg_tailer

# Look for the EI library and header files
# For crosscompiled builds, ERL_EI_INCLUDE_DIR and ERL_EI_LIBDIR must be
# passed into the Makefile.
ifeq ($(ERL_EI_INCLUDE_DIR),)
ERL_ROOT_DIR = $(shell erl -eval "io:format(\"~s~n\", [code:root_dir()])" -s init stop -noshell)
ifeq ($(ERL_ROOT_DIR),)
   $(error Could not find the Erlang installation. Check to see that 'erl' is in your PATH)
endif
ERL_EI_INCLUDE_DIR = "$(ERL_ROOT_DIR)/usr/include"
ERL_EI_LIBDIR = "$(ERL_ROOT_DIR)/usr/lib"
endif

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

LDFLAGS += -lmnl
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -pedantic
CC ?= $(CROSSCOMPILE)-gcc

# Enable for debug messages
# CFLAGS += -DDEBUG

CFLAGS += -std=gnu99

ifeq ($(origin CROSSCOMPILE), undefined)
SUDO_ASKPASS ?= /usr/bin/ssh-askpass
SUDO ?= sudo

# If not cross-compiling, then run sudo and suid the port binary
# so that it's possible to debug
update_perms = \
	SUDO_ASKPASS=$(SUDO_ASKPASS) $(SUDO) -- sh -c 'chown root:root $(1); chmod +s $(1)'
else
# If cross-compiling, then permissions need to be set some build system-dependent way
update_perms =
endif

.PHONY: all clean

all: $(DEFAULT_TARGETS)

%.o: %.c
	$(CC) -c $(ERL_CFLAGS) $(CFLAGS) -o $@ $<

priv:
	mkdir -p priv

priv/uevent: src/uevent.o
	$(CC) $^ $(ERL_LDFLAGS) $(LDFLAGS) -o $@
	$(call update_perms, $@)

priv/kmsg_tailer: src/kmsg_tailer.o
	$(CC) $^ $(ERL_LDFLAGS) $(LDFLAGS) -o $@

clean:
	rm -f priv/uevent priv/kmsg_tailer src/*.o
