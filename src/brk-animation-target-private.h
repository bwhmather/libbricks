/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * Based on libadwaita:
 * Copyright (C) 2021 Manuel Genovés <manuel.genoves@gmail.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#pragma once

#if !defined(BRICKS_COMPILATION)
#error "Private headers can only be included when building libbricks."
#endif

#include <glib.h>

#include "brk-animation-target.h"

G_BEGIN_DECLS

void
brk_animation_target_set_value(BrkAnimationTarget *self, double value);

G_END_DECLS
