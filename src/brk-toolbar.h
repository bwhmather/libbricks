/*
 * Copyright (C) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
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

#define BRK_TYPE_TOOLBAR (brk_toolbar_get_type())

BRK_AVAILABLE_IN_ALL
G_DECLARE_FINAL_TYPE(BrkToolbar, brk_toolbar, BRK, TOOLBAR, GtkWidget)

BRK_AVAILABLE_IN_ALL
GtkWidget *
brk_toolbar_new(void) G_GNUC_WARN_UNUSED_RESULT;

BRK_AVAILABLE_IN_ALL
void
brk_toolbar_append(BrkToolbar *self, GtkWidget *widget);

BRK_AVAILABLE_IN_ALL
void
brk_toolbar_prepend(BrkToolbar *self, GtkWidget *widget);

BRK_AVAILABLE_IN_ALL
void
brk_toolbar_remove(BrkToolbar *self, GtkWidget *widget);

G_END_DECLS
