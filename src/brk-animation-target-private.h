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

G_BEGIN_DECLS

#define BRK_TYPE_ANIMATION_TARGET (brk_animation_target_get_type())

GDK_DECLARE_INTERNAL_TYPE(BrkAnimationTarget, brk_animation_target, BRK, ANIMATION_TARGET, GObject)

/**
 * BrkAnimationTargetFunc:
 * @value: The animation value
 * @user_data: (nullable): The user data provided when creating the target
 *
 * Prototype for animation targets based on user callbacks.
 */
typedef void (*BrkAnimationTargetFunc)(double value, gpointer user_data);

#define BRK_TYPE_CALLBACK_ANIMATION_TARGET (brk_callback_animation_target_get_type())

GDK_DECLARE_INTERNAL_TYPE(
    BrkCallbackAnimationTarget, brk_callback_animation_target, BRK, CALLBACK_ANIMATION_TARGET,
    BrkAnimationTarget
)

BrkAnimationTarget *
brk_callback_animation_target_new(
    BrkAnimationTargetFunc callback, gpointer user_data, GDestroyNotify destroy
) G_GNUC_WARN_UNUSED_RESULT;

void
brk_animation_target_set_value(BrkAnimationTarget *self, double value);

G_END_DECLS
