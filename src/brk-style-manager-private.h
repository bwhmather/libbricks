/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#pragma once

#if !defined(BRICKS_COMPILATION)
#error "Private headers can only be included when building libbricks."
#endif

#include <gdk/gdk.h>
#include <glib-object.h>
#include <glib.h>

G_BEGIN_DECLS

#define BRK_TYPE_STYLE_MANAGER (brk_style_manager_get_type())

G_DECLARE_FINAL_TYPE(BrkStyleManager, brk_style_manager, BRK, STYLE_MANAGER, GObject);

BrkStyleManager *
brk_style_manager_new(GdkDisplay *display);

GdkDisplay *
brk_style_manager_get_display(BrkStyleManager *);

G_END_DECLS
