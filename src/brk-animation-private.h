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
#include <gtk/gtk.h>

#include "brk-animation-target-private.h"

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

G_DECLARE_DERIVABLE_TYPE(BrkAnimation, brk_animation, BRK, ANIMATION, GObject)

struct _BrkAnimationClass {
    GObjectClass parent_class;

    guint (*estimate_duration)(BrkAnimation *self);

    double (*calculate_value)(BrkAnimation *self, guint t);
};

typedef enum {
    BRK_ANIMATION_IDLE,
    BRK_ANIMATION_PAUSED,
    BRK_ANIMATION_PLAYING,
    BRK_ANIMATION_FINISHED,
} BrkAnimationState;

GtkWidget *
brk_animation_get_widget(BrkAnimation *self);

BrkAnimationTarget *
brk_animation_get_target(BrkAnimation *self);
void
brk_animation_set_target(BrkAnimation *self, BrkAnimationTarget *target);

double
brk_animation_get_value(BrkAnimation *self);

BrkAnimationState
brk_animation_get_state(BrkAnimation *self);

void
brk_animation_play(BrkAnimation *self);
void
brk_animation_pause(BrkAnimation *self);
void
brk_animation_resume(BrkAnimation *self);
void
brk_animation_reset(BrkAnimation *self);
void
brk_animation_skip(BrkAnimation *self);

gboolean
brk_animation_get_follow_enable_animations_setting(BrkAnimation *self);
void
brk_animation_set_follow_enable_animations_setting(BrkAnimation *self, gboolean setting);

G_END_DECLS
