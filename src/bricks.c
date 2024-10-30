
#include <config.h>

#include "bricks.h"

#include <glib/gi18n-lib.h>
#include <gtk/gtk.h>

#include "brk-style-manager-private.h"

static int brk_initialized = FALSE;

static GHashTable *brk_display_style_managers = NULL;

static void
brk_unregister_display(GdkDisplay *display) {
    g_return_if_fail(g_hash_table_contains(brk_display_style_managers, display));

    g_hash_table_remove(brk_display_style_managers, display);
}

static void
brk_on_display_closed(GdkDisplay *display, gboolean is_error, gpointer user_data) {
    (void) is_error;
    (void) user_data;

    brk_unregister_display(display);
}

static void
brk_register_display(GdkDisplay *display) {
    BrkStyleManager *style_manager;

    g_return_if_fail(!g_hash_table_contains(brk_display_style_managers, display));

    style_manager = brk_style_manager_new(display);

    g_hash_table_insert(brk_display_style_managers, display, style_manager);
    g_signal_connect(display, "closed", G_CALLBACK(brk_on_display_closed), NULL);
}

static void
brk_on_display_manager_display_opened(GdkDisplayManager *display_manager, GdkDisplay *display, gpointer user_data) {
    (void) display_manager;
    (void) user_data;

    brk_register_display(display);
}

void
brk_init(void) {
    GdkDisplayManager *display_manager;
    GSList *displays;
    GSList *l;

    if (brk_initialized) {
        return;
    }

    gtk_init();

    // Internationalization.
    bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8");
    bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR);

    // Themeing.
    brk_display_style_managers = g_hash_table_new_full(g_direct_hash, g_direct_equal, NULL, g_object_unref);

    display_manager = gdk_display_manager_get();
    displays = gdk_display_manager_list_displays(display_manager);
    for (l = displays; l != NULL; l = l->next) {
        brk_register_display(GDK_DISPLAY(l->data));
    }
    g_slist_free(displays);

    g_signal_connect(
        display_manager, "display-opened",
        G_CALLBACK(brk_on_display_manager_display_opened), NULL
    );

    brk_initialized = TRUE;
}

gboolean
brk_is_initialized(void) {
    return brk_initialized;
}
