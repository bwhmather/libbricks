/*
 * Copyright (C) 2024 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

#include <config.h>

#include "brk-button-group.h"

#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-main.h"

/**
 * BrkButtonGroup:
 *
 * A widget for grouping together buttons and other widgets.
 *
 * ## CSS nodes
 *
 * `BrkButtonGroup` has a single CSS node with name `button-group` and class `linked`.
 */

struct _BrkButtonGroup {
    GtkWidget parent_instance;
};

static void
brk_button_group_buildable_init(GtkBuildableIface *iface);

G_DEFINE_FINAL_TYPE_WITH_CODE(
    BrkButtonGroup, brk_button_group, GTK_TYPE_WIDGET,
    G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, brk_button_group_buildable_init)
)

static GtkBuildableIface *parent_buildable_iface;

static void
brk_button_group_dispose(GObject *object) {
    BrkButtonGroup *self = BRK_BUTTON_GROUP(object);
    GtkWidget *child;

    while ((child = gtk_widget_get_first_child(GTK_WIDGET(self)))) {
        gtk_widget_unparent(child);
    }
    G_OBJECT_CLASS(brk_button_group_parent_class)->dispose(object);
}

static void
brk_button_group_class_init(BrkButtonGroupClass *class) {
    GObjectClass *object_class = G_OBJECT_CLASS(class);
    GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(class);

    object_class->dispose = brk_button_group_dispose;

    gtk_widget_class_set_layout_manager_type(widget_class, GTK_TYPE_BOX_LAYOUT);
    gtk_widget_class_set_css_name(widget_class, "button-group");
    gtk_widget_class_set_accessible_role(widget_class, GTK_ACCESSIBLE_ROLE_GROUP);
}

static void
brk_button_group_init(BrkButtonGroup *self) {
    g_warn_if_fail(brk_is_initialized());

    gtk_accessible_update_property(
        GTK_ACCESSIBLE(self),
        GTK_ACCESSIBLE_PROPERTY_ORIENTATION, GTK_ORIENTATION_HORIZONTAL,
        -1
    );

    gtk_widget_add_css_class(GTK_WIDGET(self), "linked");
}

static void
brk_button_group_buildable_add_child(
    GtkBuildable *buildable, GtkBuilder *builder, GObject *child, const char *type
) {
    if (GTK_IS_WIDGET(child)) {
        gtk_widget_insert_before(GTK_WIDGET(child), GTK_WIDGET(buildable), NULL);
    } else {
        parent_buildable_iface->add_child(buildable, builder, child, type);
    }
}

static void
brk_button_group_buildable_init(GtkBuildableIface *iface) {
    parent_buildable_iface = g_type_interface_peek_parent(iface);

    iface->add_child = brk_button_group_buildable_add_child;
}

GtkWidget *
brk_button_group_new(void) {
    return g_object_new(BRK_TYPE_BUTTON_GROUP, NULL);
}
