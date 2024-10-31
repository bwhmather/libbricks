/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#pragma once

#if !defined(_BRICKS_INSIDE) && !defined(BRICKS_COMPILATION)
#error "Only <bricks.h> can be included directly."
#endif

#include <glib.h>

#include "brk-version.h"

G_BEGIN_DECLS

BRK_AVAILABLE_IN_ALL
void
brk_init(void);

BRK_AVAILABLE_IN_ALL
gboolean
brk_is_initialized(void);

G_END_DECLS
