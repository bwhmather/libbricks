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

#include <gdk/gdk.h>
#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-animation-private.h"
#include "brk-animation-target-private.h"
#include "brk-easing-private.h"

G_BEGIN_DECLS

#define BRK_TYPE_TIMED_ANIMATION (brk_timed_animation_get_type())

GDK_DECLARE_INTERNAL_TYPE(
    BrkTimedAnimation, brk_timed_animation, BRK, TIMED_ANIMATION, BrkAnimation
)

BrkAnimation *
brk_timed_animation_new(
    GtkWidget *widget, double from, double to, guint duration, BrkAnimationTarget *target
) G_GNUC_WARN_UNUSED_RESULT;

double
brk_timed_animation_get_value_from(BrkTimedAnimation *self);
void
brk_timed_animation_set_value_from(BrkTimedAnimation *self, double value);

double
brk_timed_animation_get_value_to(BrkTimedAnimation *self);
void
brk_timed_animation_set_value_to(BrkTimedAnimation *self, double value);

guint
brk_timed_animation_get_duration(BrkTimedAnimation *self);
void
brk_timed_animation_set_duration(BrkTimedAnimation *self, guint duration);

BrkEasing
brk_timed_animation_get_easing(BrkTimedAnimation *self);
void
brk_timed_animation_set_easing(BrkTimedAnimation *self, BrkEasing easing);

guint
brk_timed_animation_get_repeat_count(BrkTimedAnimation *self);
void
brk_timed_animation_set_repeat_count(BrkTimedAnimation *self, guint repeat_count);

gboolean
brk_timed_animation_get_reverse(BrkTimedAnimation *self);
void
brk_timed_animation_set_reverse(BrkTimedAnimation *self, gboolean reverse);

gboolean
brk_timed_animation_get_alternate(BrkTimedAnimation *self);
void
brk_timed_animation_set_alternate(BrkTimedAnimation *self, gboolean alternate);

G_END_DECLS
