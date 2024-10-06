/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * Based on libadwaita:
 * Copyright (C) 2023 Purism SPC
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Author: Alice Mikhaylenko <alice.mikhaylenko@puri.sm>
 */

#pragma once

#if !defined(_BRICKS_INSIDE) && !defined(BRICKS_COMPILATION)
#error "Only <bricks.h> can be included directly."
#endif

#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-version.h"

G_BEGIN_DECLS

#define BRK_TYPE_TOOLBAR_VIEW (brk_toolbar_view_get_type())

typedef enum {
    BRK_TOOLBAR_FLAT,
    BRK_TOOLBAR_RAISED,
    BRK_TOOLBAR_RAISED_BORDER,
} BrkToolbarStyle;

BRK_AVAILABLE_IN_ALL
G_DECLARE_FINAL_TYPE(BrkToolbarView, brk_toolbar_view, BRK, TOOLBAR_VIEW, GtkWidget)

BRK_AVAILABLE_IN_ALL
GtkWidget *
brk_toolbar_view_new(void) G_GNUC_WARN_UNUSED_RESULT;

BRK_AVAILABLE_IN_ALL
GtkWidget *
brk_toolbar_view_get_content(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_content(BrkToolbarView *self, GtkWidget *content);

BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_add_top_bar(BrkToolbarView *self, GtkWidget *widget);

BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_add_bottom_bar(BrkToolbarView *self, GtkWidget *widget);

BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_remove(BrkToolbarView *self, GtkWidget *widget);

BRK_AVAILABLE_IN_ALL
BrkToolbarStyle
brk_toolbar_view_get_top_bar_style(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_top_bar_style(BrkToolbarView *self, BrkToolbarStyle style);

BRK_AVAILABLE_IN_ALL
BrkToolbarStyle
brk_toolbar_view_get_bottom_bar_style(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_bottom_bar_style(BrkToolbarView *self, BrkToolbarStyle style);

BRK_AVAILABLE_IN_ALL
gboolean
brk_toolbar_view_get_reveal_top_bars(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_reveal_top_bars(BrkToolbarView *self, gboolean reveal);

BRK_AVAILABLE_IN_ALL
gboolean
brk_toolbar_view_get_reveal_bottom_bars(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_reveal_bottom_bars(BrkToolbarView *self, gboolean reveal);

BRK_AVAILABLE_IN_ALL
gboolean
brk_toolbar_view_get_extend_content_to_top_edge(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_extend_content_to_top_edge(BrkToolbarView *self, gboolean extend);

BRK_AVAILABLE_IN_ALL
gboolean
brk_toolbar_view_get_extend_content_to_bottom_edge(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
void
brk_toolbar_view_set_extend_content_to_bottom_edge(BrkToolbarView *self, gboolean extend);

BRK_AVAILABLE_IN_ALL
int
brk_toolbar_view_get_top_bar_height(BrkToolbarView *self);
BRK_AVAILABLE_IN_ALL
int
brk_toolbar_view_get_bottom_bar_height(BrkToolbarView *self);

G_END_DECLS
