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

#include "brk-tab-page.h"
#include "brk-tab-view.h"

G_BEGIN_DECLS

gboolean
brk_tab_view_select_first_page(BrkTabView *self);
gboolean
brk_tab_view_select_last_page(BrkTabView *self);

void
brk_tab_view_detach_page(BrkTabView *self, BrkTabPage *page);
void
brk_tab_view_attach_page(BrkTabView *self, BrkTabPage *page, int position);

BrkTabView *
brk_tab_view_create_window(BrkTabView *self) G_GNUC_WARN_UNUSED_RESULT;

G_END_DECLS
