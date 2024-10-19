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

#include <glib-object.h>
#include <glib.h>

#include "brk-animation.h"

G_BEGIN_DECLS

struct _BrkAnimationClass {
    GObjectClass parent_class;

    guint (*estimate_duration)(BrkAnimation *self);

    double (*calculate_value)(BrkAnimation *self, guint t);
};

G_END_DECLS
