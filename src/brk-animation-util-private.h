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

#if !defined(BRICKS_COMPILATION)
#error "Private headers can only be included when building libbricks."
#endif

#include <glib.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

double
brk_lerp(double a, double b, double t);

gboolean
brk_get_enable_animations(GtkWidget *widget);

G_END_DECLS
