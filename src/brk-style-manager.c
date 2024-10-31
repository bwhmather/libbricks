#include <config.h>

#include <gdk/gdk.h>
#include <gio/gio.h>
#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>
#include <stddef.h>
#include <string.h>

#include "brk-style-manager-private.h"
#include "brk-version.h"

struct _BrkStyleManager {
    GObject parent_instance;
    GdkDisplay *display;

    GtkCssProvider *provider;
};

G_DEFINE_FINAL_TYPE(BrkStyleManager, brk_style_manager, G_TYPE_OBJECT);

enum {
    PROP_0,
    PROP_DISPLAY,
    NUM_PROPS,
};

static GParamSpec *props[NUM_PROPS];

// Based on equivalent from `gtkcssprovider.c`.  Should be kept in sync to
// prevent GTK and libbricks loading different themes.
static char *
brk_get_theme_dir(void) {
    const char *var;

    var = g_getenv("BRK_DATA_PREFIX");
    if (var == NULL) {
        var = BRK_DATA_PREFIX;
    }

    return g_build_filename(var, "share", "themes", NULL);
}

// Based on equivalent from `gtkcssprovider.c`.  Should be kept in sync to
// prevent GTK and libbricks loading different themes.
static char *
brk_css_find_theme_dir(char const *dir, char const *subdir, char const *name, char const *file) {
    char *base;
    gint i;
    char *subsubdir;
    char *path;

    if (subdir) {
        base = g_build_filename(dir, subdir, name, NULL);
    } else {
        base = g_build_filename(dir, name, NULL);
    }

    if (!g_file_test(base, G_FILE_TEST_IS_DIR)) {
        g_free(base);
        return NULL;
    }

    path = NULL;
    for (i = BRK_MINOR_VERSION; i >= 0; i--) {
        subsubdir = g_strdup_printf("brk-%d.%d", BRK_MAJOR_VERSION, BRK_MINOR_VERSION);
        path = g_build_filename(base, subsubdir, file, NULL);

        if (g_file_test(path, G_FILE_TEST_EXISTS)) {
            break;
        }

        g_clear_pointer(&path, g_free);
        g_free(subsubdir);
    }

    g_free(base);

    return path;
}

// Based on equivalent from `gtkcssprovider.c`.  Should be kept in sync to
// prevent GTK and libbricks loading different themes.
static char *
brk_css_find_theme(char const *name, char const *variant) {
    size_t i;
    char *file;
    char *path;
    char const *const *dirs;
    char *dir;

    g_return_val_if_fail(name != NULL, NULL);

    if (variant) {
        file = g_strdup_printf("brk-%s.css", variant);
    } else {
        file = g_strdup("gtk.css");
    }

    // First look in the user's data directory.
    path = brk_css_find_theme_dir(g_get_user_data_dir(), "themes", name, file);
    if (path != NULL) {
        g_free(file);
        return path;
    }

    // Next look in the user's home directory.
    path = brk_css_find_theme_dir(g_get_home_dir(), ".themes", name, file);
    if (path != NULL) {
        g_free(file);
        return path;
    }

    // Look in system data directories.
    dirs = g_get_system_data_dirs();
    for (i = 0; dirs[i] != NULL; i++) {
        path = brk_css_find_theme_dir(dirs[i], "themes", name, file);
        if (path != NULL) {
            g_free(file);
            return path;
        }
    }

    // Finally, try in the default theme directory.
    dir = brk_get_theme_dir();
    path = brk_css_find_theme_dir(dir, NULL, name, file);
    g_free(dir);
    g_free(file);

    return path;
}

// Based on equivalent from `gtk_css_provider_load_named`.  Should be kept in
// sync to prevent GTK and libbricks loading different themes.
static void
brk_style_manager_load_named(BrkStyleManager *self, char const *name, char const *variant) {
    char *path;
    char *resource_path;

    g_return_if_fail(BRK_IS_STYLE_MANAGER(self));
    g_return_if_fail(name != NULL);

    // Try to load from the set of built-in themes.
    if (variant != NULL) {
        resource_path = g_strdup_printf("/com/bwhmather/Bricks/theme/%s/brk-%s.css", name, variant);
    } else {
        resource_path = g_strdup_printf("/com/bwhmather/Bricks/theme/%s/brk.css", name);
    }
    if (g_resources_get_info(resource_path, 0, NULL, NULL, NULL)) {
        gtk_css_provider_load_from_resource(self->provider, resource_path);
        g_free(resource_path);
        return;
    }
    g_free(resource_path);

    // Next look for files in the various theme directories.
    path = brk_css_find_theme(name, variant);
    if (path != NULL) {
        gtk_css_provider_load_from_path(self->provider, path);

        g_free(path);
        return;
    }

    // Things failed! Fall back!
    //
    // To match GTK, we accept the names HighContrast, HighContrastInverse,
    // Adwaita and Adwaita-dark as aliases for the variants of the Default
    // them.
    if (strcmp(name, "HighContrast") == 0) {
        if (g_strcmp0(variant, "dark") == 0) {
            brk_style_manager_load_named(self, "Default", "hc-dark");
        } else {
            brk_style_manager_load_named(self, "Default", "hc");
        }
        return;
    }

    if (strcmp(name, "HighContrastInverse") == 0) {
        brk_style_manager_load_named(self, "Default", "hc-dark");
        return;
    }

    if (strcmp(name, "Adwaita-dark") == 0) {
        brk_style_manager_load_named(self, "Default", "dark");
        return;
    }

    // At this point we diverge from GTK.  GTK falls back to "Default" for all
    // other requests.  We only fallback for "Adwaita" and assume other themes
    // won't be loaded unless they have a libbricks variant.
    if (strcmp(name, "Adwaita") == 0) {
        brk_style_manager_load_named(self, "Default", NULL);
        return;
    }

    brk_style_manager_load_named(self, "Empty", NULL);
}

// Based on `get_theme_name` from `gtksettings.c`.  Should be kept in sync to
// prevent GTK and libbricks loading different themes.
static void
brk_style_manager_get_theme_name(BrkStyleManager *self, char **theme_name, char **theme_variant) {
    GtkSettings *gtk_settings;
    gboolean prefer_dark;
    char *p;

    g_return_if_fail(theme_name != NULL);
    *theme_name = NULL;

    g_return_if_fail(theme_variant != NULL);
    *theme_variant = NULL;

    g_return_if_fail(BRK_IS_STYLE_MANAGER(self));

    gtk_settings = gtk_settings_get_for_display(self->display);

    if (g_getenv("GTK_THEME")) {
        *theme_name = g_strdup(g_getenv("GTK_THEME"));
    }
    if (*theme_name != NULL) {
        p = strrchr(*theme_name, ':');
        if (p) {
            *p = '\0';
            p++;
            *theme_variant = g_strdup(p);
        }

        return;
    }

    g_object_get(
        gtk_settings,
        "gtk-theme-name", theme_name,
        "gtk-application-prefer-dark-theme", &prefer_dark,
        NULL
    );
    if (prefer_dark) {
        *theme_variant = g_strdup("dark");
    }
    if (*theme_name != NULL) {
        return;
    }

    *theme_name = g_strdup("Default");
}

static void
brk_style_manager_update_stylesheet(BrkStyleManager *self) {
    char *theme_name;
    char *theme_variant;

    g_return_if_fail(BRK_IS_STYLE_MANAGER(self));
    g_return_if_fail(GDK_IS_DISPLAY(self->display));

    brk_style_manager_get_theme_name(self, &theme_name, &theme_variant);
    brk_style_manager_load_named(self, theme_name, theme_variant);
}

static void
brk_style_manager_on_settings_theme_name_changed(GtkSettings *settings, GParamSpec *pspec, gpointer user_data) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(user_data);

    (void) settings;
    (void) pspec;

    brk_style_manager_update_stylesheet(self);
}

static void
brk_style_manager_on_settings_prefer_dark_theme_changed(GtkSettings *settings, GParamSpec *pspec, gpointer user_data) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(user_data);

    (void) settings;
    (void) pspec;

    brk_style_manager_update_stylesheet(self);
}

static void
brk_style_manager_constructed(GObject *object) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(object);
    GtkSettings *gtk_settings;

    G_OBJECT_CLASS(brk_style_manager_parent_class)->constructed(object);

    g_return_if_fail(GDK_IS_DISPLAY(self->display));

    gtk_settings = gtk_settings_get_for_display(self->display);
    g_signal_connect_object(
        gtk_settings, "notify::gtk-theme-name",
        G_CALLBACK(brk_style_manager_on_settings_theme_name_changed), self, G_CONNECT_DEFAULT
    );
    g_signal_connect_object(
        gtk_settings, "notify::gtk-application-prefer-dark-theme",
        G_CALLBACK(brk_style_manager_on_settings_prefer_dark_theme_changed), self, G_CONNECT_DEFAULT
    );

    gtk_style_context_add_provider_for_display(
        self->display,
        GTK_STYLE_PROVIDER(self->provider),
        GTK_STYLE_PROVIDER_PRIORITY_THEME
    );

    brk_style_manager_update_stylesheet(self);
}

static void
brk_style_manager_dispose(GObject *object) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(object);

    g_clear_object(&self->display);
    g_clear_object(&self->provider);

    G_OBJECT_CLASS(brk_style_manager_parent_class)->dispose(object);
}

static void
brk_style_manager_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(object);

    switch (prop_id) {
    case PROP_DISPLAY:
        g_value_set_object(value, brk_style_manager_get_display(self));
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_style_manager_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(object);

    switch (prop_id) {
    case PROP_DISPLAY:
        self->display = g_value_get_object(value);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_style_manager_class_init(BrkStyleManagerClass *class) {
    GObjectClass *object_class = G_OBJECT_CLASS(class);

    object_class->constructed = brk_style_manager_constructed;
    object_class->dispose = brk_style_manager_dispose;
    object_class->get_property = brk_style_manager_get_property;
    object_class->set_property = brk_style_manager_set_property;

    props[PROP_DISPLAY] = g_param_spec_object(
        "display", NULL, NULL, GDK_TYPE_DISPLAY,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS
    );

    g_object_class_install_properties(object_class, NUM_PROPS, props);
}

static void
brk_style_manager_init(BrkStyleManager *self) {
    self->provider = gtk_css_provider_new();
}

BrkStyleManager *
brk_style_manager_new(GdkDisplay *display) {
    BrkStyleManager *style_manager;

    g_return_val_if_fail(GDK_IS_DISPLAY(display), NULL);

    style_manager = g_object_new(
        BRK_TYPE_STYLE_MANAGER,
        "display", display,
        NULL
    );

    return style_manager;
}

GdkDisplay *
brk_style_manager_get_display(BrkStyleManager *self) {
    g_return_val_if_fail(BRK_IS_STYLE_MANAGER(self), NULL);
    return self->display;
}
