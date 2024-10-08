

#pragma once

#if !defined(_BRICKS_INSIDE) && !defined(BRICKS_COMPILATION)
#error "Only <bricks.h> can be included directly."
#endif

#include <gio/gio.h>
#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-version.h"

G_BEGIN_DECLS

#define BRK_TYPE_TAB_PAGE (brk_tab_page_get_type())

BRK_AVAILABLE_IN_ALL
G_DECLARE_FINAL_TYPE(BrkTabPage, brk_tab_page, BRK, TAB_PAGE, GObject)

BRK_AVAILABLE_IN_ALL
GtkWidget *
brk_tab_page_get_child(BrkTabPage *self);

BRK_AVAILABLE_IN_ALL
BrkTabPage *
brk_tab_page_get_parent(BrkTabPage *self);

BRK_AVAILABLE_IN_ALL
gboolean
brk_tab_page_get_selected(BrkTabPage *self);

BRK_AVAILABLE_IN_ALL
const char *
brk_tab_page_get_title(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_title(BrkTabPage *self, const char *title);

BRK_AVAILABLE_IN_ALL
const char *
brk_tab_page_get_tooltip(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_tooltip(BrkTabPage *self, const char *tooltip);

BRK_AVAILABLE_IN_ALL
GIcon *
brk_tab_page_get_icon(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_icon(BrkTabPage *self, GIcon *icon);

BRK_AVAILABLE_IN_ALL
gboolean
brk_tab_page_get_loading(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_loading(BrkTabPage *self, gboolean loading);

BRK_AVAILABLE_IN_ALL
GIcon *
brk_tab_page_get_indicator_icon(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_indicator_icon(BrkTabPage *self, GIcon *indicator_icon);

BRK_AVAILABLE_IN_ALL
const char *
brk_tab_page_get_indicator_tooltip(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_indicator_tooltip(BrkTabPage *self, const char *tooltip);

BRK_AVAILABLE_IN_ALL
gboolean
brk_tab_page_get_indicator_activatable(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_indicator_activatable(BrkTabPage *self, gboolean activatable);

BRK_AVAILABLE_IN_ALL
gboolean
brk_tab_page_get_needs_attention(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_needs_attention(BrkTabPage *self, gboolean needs_attention);

BRK_AVAILABLE_IN_ALL
const char *
brk_tab_page_get_keyword(BrkTabPage *self);
BRK_AVAILABLE_IN_ALL
void
brk_tab_page_set_keyword(BrkTabPage *self, const char *keyword);

G_END_DECLS
