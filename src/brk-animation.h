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

#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-animation-target.h"
#include "brk-version.h"

G_BEGIN_DECLS

/**
 * BRK_DURATION_INFINITE:
 *
 * Indicates an [class@Animation] with an infinite duration.
 *
 * This value is mostly used internally.
 */

#define BRK_DURATION_INFINITE ((guint) 0xffffffff)

#define BRK_TYPE_ANIMATION (brk_animation_get_type())

BRK_AVAILABLE_IN_ALL
G_DECLARE_DERIVABLE_TYPE(BrkAnimation, brk_animation, BRK, ANIMATION, GObject)

typedef enum {
    BRK_ANIMATION_IDLE,
    BRK_ANIMATION_PAUSED,
    BRK_ANIMATION_PLAYING,
    BRK_ANIMATION_FINISHED,
} BrkAnimationState;

BRK_AVAILABLE_IN_ALL
GtkWidget *
brk_animation_get_widget(BrkAnimation *self);

BRK_AVAILABLE_IN_ALL
BrkAnimationTarget *
brk_animation_get_target(BrkAnimation *self);
BRK_AVAILABLE_IN_ALL
void
brk_animation_set_target(BrkAnimation *self, BrkAnimationTarget *target);

BRK_AVAILABLE_IN_ALL
double
brk_animation_get_value(BrkAnimation *self);

BRK_AVAILABLE_IN_ALL
BrkAnimationState
brk_animation_get_state(BrkAnimation *self);

BRK_AVAILABLE_IN_ALL
void
brk_animation_play(BrkAnimation *self);
BRK_AVAILABLE_IN_ALL
void
brk_animation_pause(BrkAnimation *self);
BRK_AVAILABLE_IN_ALL
void
brk_animation_resume(BrkAnimation *self);
BRK_AVAILABLE_IN_ALL
void
brk_animation_reset(BrkAnimation *self);
BRK_AVAILABLE_IN_ALL
void
brk_animation_skip(BrkAnimation *self);

BRK_AVAILABLE_IN_ALL
gboolean
brk_animation_get_follow_enable_animations_setting(BrkAnimation *self);
BRK_AVAILABLE_IN_ALL
void
brk_animation_set_follow_enable_animations_setting(BrkAnimation *self, gboolean setting);

G_END_DECLS
