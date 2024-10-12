/* GTK - The GIMP Toolkit
 * Copyright (C) 1995-1997 Peter Mattis, Spencer Kimball and Josh MacDonald
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.> See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

#if !defined(_BRICKS_INSIDE) && !defined(BRICKS_COMPILATION)
#error "Only <bricks.h> can be included directly."
#endif

#include <gdk/gdk.h>
#include <glib.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS

#define BRK_CRITICAL_CANNOT_REMOVE_CHILD(parent, child)                                     \
    G_STMT_START {                                                                          \
        g_critical(                                                                         \
            "%s:%d: tried to remove non-child %p of type '%s' from %p of "                  \
            "type '%s'",                                                                    \
            __FILE__, __LINE__, (child), G_OBJECT_TYPE_NAME((GObject *) (child)), (parent), \
            G_OBJECT_TYPE_NAME((GObject *) (parent))                                        \
        );                                                                                  \
    }                                                                                       \
    G_STMT_END

gboolean
brk_widget_focus_child(GtkWidget *widget, GtkDirectionType direction);

gboolean
brk_widget_grab_focus_child(GtkWidget *widget);

void
brk_widget_compute_expand(GtkWidget *widget, gboolean *hexpand_p, gboolean *vexpand_p);

GtkSizeRequestMode
brk_widget_get_request_mode(GtkWidget *widget);

G_END_DECLS
