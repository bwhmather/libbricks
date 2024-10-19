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
#include <gtk/gtk.h>

G_BEGIN_DECLS

GtkWidget *
brk_tab_page_get_bin(BrkTabPage *self);

void
brk_tab_page_set_parent(BrkTabPage *self, BrkTabPage *parent);

// TODO should be replaced with `brk_tab_page_close`
void
brk_tab_page_set_closing(BrkTabPage *self, gboolean closing);
gboolean
brk_tab_page_get_closing(BrkTabPage *self);

void
brk_tab_page_set_selected(BrkTabPage *self, gboolean selected);

gboolean
brk_tab_page_get_has_focus(BrkTabPage *self);

void
brk_tab_page_save_focus(BrkTabPage *self);

void
brk_tab_page_grab_focus(BrkTabPage *self);

G_END_DECLS
