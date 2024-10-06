/*
 * Copyright (C) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <config.h>

#include "brk-toolbar.h"

#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

/**
 * BrkToolbar:
 *
 * A widget for containing rows of buttons and other widgets.
 *
 * <picture>
 *   <source srcset="toolbar-dark.png" media="(prefers-color-scheme: dark)">
 *   <img src="toolbar.png" alt="toolbar">
 * </picture>
 *
 * ## CSS nodes
 *
 * `BrkToolbar` has a single CSS node with name `toolbar`.
 */

struct _BrkToolbar {
    GtkWidget parent_instance;
};

static void
brk_toolbar_buildable_init(GtkBuildableIface *iface);

G_DEFINE_FINAL_TYPE_WITH_CODE(
    BrkToolbar, brk_toolbar, GTK_TYPE_WIDGET,
    G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, brk_toolbar_buildable_init)
)

static GtkBuildableIface *parent_buildable_iface;

enum {
    PROP_0,
    LAST_PROP
};

// static GParamSpec *props[LAST_PROP];

static void
brk_toolbar_dispose(GObject *object) {
    BrkToolbar *self = BRK_TOOLBAR(object);
    GtkWidget *child;

    while ((child = gtk_widget_get_first_child(GTK_WIDGET(self)))) {
        gtk_widget_unparent(child);
    }
    G_OBJECT_CLASS(brk_toolbar_parent_class)->dispose(object);
}

static void
brk_toolbar_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec) {
    //    BrkToolbar *self = BRK_TOOLBAR(object);

    switch (prop_id) {
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_toolbar_set_property(GObject *object, guint prop_id, GValue const *value, GParamSpec *pspec) {
    //     BrkToolbar *self = BRK_TOOLBAR(object);

    switch (prop_id) {
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_toolbar_class_init(BrkToolbarClass *class) {
    GObjectClass *object_class = G_OBJECT_CLASS(class);
    GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(class);

    object_class->dispose = brk_toolbar_dispose;
    object_class->get_property = brk_toolbar_get_property;
    object_class->set_property = brk_toolbar_set_property;

    gtk_widget_class_set_layout_manager_type(widget_class, GTK_TYPE_BOX_LAYOUT);
    gtk_widget_class_set_css_name(widget_class, "toolbar");
    gtk_widget_class_set_accessible_role(widget_class, GTK_ACCESSIBLE_ROLE_GROUP);
}

static void
brk_toolbar_init(BrkToolbar *self) {
    gtk_accessible_update_property(
        GTK_ACCESSIBLE(self),
        GTK_ACCESSIBLE_PROPERTY_ORIENTATION, GTK_ORIENTATION_HORIZONTAL,
        -1
    );

    gtk_widget_add_css_class(GTK_WIDGET(self), "toolbar"); // TODO remove after moving to custom css.
}

static void
brk_toolbar_buildable_add_child(
    GtkBuildable *buildable, GtkBuilder *builder, GObject *child, const char *type
) {
    if (GTK_IS_WIDGET(child)) {
        brk_toolbar_append(BRK_TOOLBAR(buildable), GTK_WIDGET(child));
    } else {
        parent_buildable_iface->add_child(buildable, builder, child, type);
    }
}

static void
brk_toolbar_buildable_init(GtkBuildableIface *iface) {
    parent_buildable_iface = g_type_interface_peek_parent(iface);

    iface->add_child = brk_toolbar_buildable_add_child;
}

GtkWidget *
brk_toolbar_new(void) {
    return g_object_new(BRK_TYPE_TOOLBAR, NULL);
}

void
brk_toolbar_append(BrkToolbar *self, GtkWidget *child) {
    g_return_if_fail(BRK_IS_TOOLBAR(self));
    g_return_if_fail(GTK_IS_WIDGET(child));
    g_return_if_fail(gtk_widget_get_parent(child) == NULL);

    gtk_widget_insert_before(child, GTK_WIDGET(self), NULL);
}

void
brk_toolbar_prepend(BrkToolbar *self, GtkWidget *child) {
    g_return_if_fail(BRK_IS_TOOLBAR(self));
    g_return_if_fail(GTK_IS_WIDGET(child));
    g_return_if_fail(gtk_widget_get_parent(child) == NULL);

    gtk_widget_insert_after(child, GTK_WIDGET(self), NULL);
}

void
brk_toolbar_remove(BrkToolbar *self, GtkWidget *child) {
    g_return_if_fail(BRK_IS_TOOLBAR(self));
    g_return_if_fail(GTK_IS_WIDGET(child));
    g_return_if_fail(gtk_widget_get_parent(child) == GTK_WIDGET(self));

    gtk_widget_unparent(child);
}
