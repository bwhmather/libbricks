/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * Based on libadwaita:
 * Copyright (C) 2020 Purism SPC
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Author: Alice Mikhaylenko <alice.mikhaylenko@puri.sm>
 */

#pragma once

#if !defined(BRICKS_COMPILATION)
#error "Private headers can only be included when building libbricks."
#endif

#include <glib.h>

#include "brk-tab-bar.h"
#include "brk-tab-box-private.h"

G_BEGIN_DECLS

gboolean
brk_tab_bar_tabs_have_visible_focus(BrkTabBar *self);

BrkTabBox *
brk_tab_bar_get_tab_box(BrkTabBar *self);

G_END_DECLS
