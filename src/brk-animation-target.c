/*
 * Copyright (c) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * Based on libadwaita:
 * Copyright (C) 2021 Manuel Genovés <manuel.genoves@gmail.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <config.h>

#include <glib-object.h>
#include <glib.h>

#include "brk-animation-target-private.h"
/**
 * BrkAnimationTarget:
 *
 * Represents a value [class@Animation] can animate.
 */

/**
 * BrkCallbackAnimationTarget:
 *
 * An [class@AnimationTarget] that calls a given callback during the
 * animation.
 */

struct _BrkAnimationTarget {
    GObject parent_instance;
};

struct _BrkAnimationTargetClass {
    GObjectClass parent_class;

    void (*set_value)(BrkAnimationTarget *self, double value);
};

G_DEFINE_ABSTRACT_TYPE(BrkAnimationTarget, brk_animation_target, G_TYPE_OBJECT)

static void
brk_animation_target_class_init(BrkAnimationTargetClass *klass) {}

static void
brk_animation_target_init(BrkAnimationTarget *self) {}

void
brk_animation_target_set_value(BrkAnimationTarget *self, double value) {
    g_return_if_fail(BRK_IS_ANIMATION_TARGET(self));

    BRK_ANIMATION_TARGET_GET_CLASS(self)->set_value(self, value);
}

struct _BrkCallbackAnimationTarget {
    BrkAnimationTarget parent_instance;

    BrkAnimationTargetFunc callback;
    gpointer user_data;
    GDestroyNotify destroy_notify;
};

struct _BrkCallbackAnimationTargetClass {
    BrkAnimationTargetClass parent_class;
};

G_DEFINE_FINAL_TYPE(
    BrkCallbackAnimationTarget, brk_callback_animation_target, BRK_TYPE_ANIMATION_TARGET
)

static void
brk_callback_animation_target_set_value(BrkAnimationTarget *target, double value) {
    BrkCallbackAnimationTarget *self = BRK_CALLBACK_ANIMATION_TARGET(target);

    self->callback(value, self->user_data);
}

static void
brk_callback_animation_finalize(GObject *object) {
    BrkCallbackAnimationTarget *self = BRK_CALLBACK_ANIMATION_TARGET(object);

    if (self->destroy_notify) {
        self->destroy_notify(self->user_data);
    }

    G_OBJECT_CLASS(brk_callback_animation_target_parent_class)->finalize(object);
}

static void
brk_callback_animation_target_class_init(BrkCallbackAnimationTargetClass *klass) {
    GObjectClass *object_class = G_OBJECT_CLASS(klass);
    BrkAnimationTargetClass *target_class = BRK_ANIMATION_TARGET_CLASS(klass);

    object_class->finalize = brk_callback_animation_finalize;

    target_class->set_value = brk_callback_animation_target_set_value;
}

static void
brk_callback_animation_target_init(BrkCallbackAnimationTarget *self) {}

/**
 * brk_callback_animation_target_new:
 * @callback: (scope notified) (not nullable): the callback to call
 * @user_data: (closure callback): the data to be passed to @callback
 * @destroy: (destroy user_data): the function to be called when the
 *   callback action is finalized
 *
 * Creates a new `BrkAnimationTarget` that calls the given @callback during
 * the animation.
 *
 * Returns: the newly created callback target
 */
BrkAnimationTarget *
brk_callback_animation_target_new(
    BrkAnimationTargetFunc callback, gpointer user_data, GDestroyNotify destroy
) {
    BrkCallbackAnimationTarget *self;

    g_return_val_if_fail(callback != NULL, NULL);

    self = g_object_new(BRK_TYPE_CALLBACK_ANIMATION_TARGET, NULL);

    self->callback = callback;
    self->user_data = user_data;
    self->destroy_notify = destroy;

    return BRK_ANIMATION_TARGET(self);
}
