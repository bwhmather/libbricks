/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * Based on libadwaita:
 * Copyright (C) 2019 Purism SPC
 * Copyright (C) 2021 Manuel Genovés <manuel.genoves@gmail.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#pragma once

#if !defined(_BRICKS_INSIDE) && !defined(BRICKS_COMPILATION)
#error "Only <bricks.h> can be included directly."
#endif

#include <gtk/gtk.h>
#include <glib.h>

#include "brk-version.h"

G_BEGIN_DECLS

BRK_AVAILABLE_IN_ALL
double
brk_lerp(double a, double b, double t);

BRK_AVAILABLE_IN_ALL
gboolean
brk_get_enable_animations(GtkWidget *widget);

G_END_DECLS
