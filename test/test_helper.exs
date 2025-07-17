# SPDX-FileCopyrightText: 2017 Justin Schneck
# SPDX-FileCopyrightText: 2021 Masatoshi Nishiguchi
# SPDX-FileCopyrightText: 2024 Frank Hunleth
#
# SPDX-License-Identifier: Apache-2.0

Mimic.copy(:heart)
Mimic.copy(Nerves.Runtime)
Mimic.copy(Nerves.Runtime.AutoValidate)
Mimic.copy(Nerves.Runtime.Heart)

ExUnit.start()
