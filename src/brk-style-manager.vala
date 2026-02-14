/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

internal sealed class Brk.StyleManager : GLib.Object {
    public Gdk.Display display { get; construct; }
    private Gtk.CssProvider provider = new Gtk.CssProvider();

    // Based on `_gtk_get_theme_dir` from `gtkcssprovider.c`.  Should be kept in
    // sync to prevent GTK and libbricks loading different themes.
    private static string
    theme_dir() {
        string? data_prefix = Environment.get_variable("BRK_DATA_PREFIX");
        if (data_prefix == null) {
            data_prefix = Config.BRK_DATA_PREFIX;
        }

        return Path.build_filename(data_prefix, "share", "themes");
    }

    // Based on `_gtk_css_find_theme_dir` from `gtkcssprovider.c`.  Should be
    // kept in sync to prevent GTK and libbricks loading different themes.
    private static string?
    find_theme_dir(string dir, string? subdir, string name, string file) {
        string basedir;
        if (subdir != null) {
            basedir = Path.build_filename(dir, subdir, name);
        } else {
            basedir = Path.build_filename(dir, name);
        }

        if (!FileUtils.test(basedir, FileTest.IS_DIR)) {
            return null;
        }

        string? path = null;
        for (int i = Config.BRK_VERSION_MINOR; i >= 0; i--) {
            string subsubdir = "brk-%d.%d".printf(Config.BRK_VERSION_MAJOR, i);
            path = Path.build_filename(basedir, subsubdir, file);

            if (FileUtils.test(path, FileTest.EXISTS)) {
                break;
            }

            path = null;
        }

        return path;
    }

    // Based on `_gtk_css_find_theme` from `gtkcssprovider.c`.  Should be kept
    // in sync to prevent GTK and libbricks loading different themes.
    private static string?
    find_theme(string name, string? variant) {
        string? path;
        var dirs = Environment.get_system_data_dirs();

        string file;
        if (variant != null) {
            file = "brk-%s.css".printf(variant);
        } else {
            file = "gtk.css";
        }

        // First look in the user's data directory.
        path = find_theme_dir(Environment.get_user_data_dir(), "themes", name, file);
        if (path != null) {
            return path;
        }

        // Next look in the user's home directory.
        path = find_theme_dir(Environment.get_home_dir(), ".themes", name, file);
        if (path != null) {
            return path;
        }

        // Look in system data directories.
        foreach (string dir in dirs) {
            path = find_theme_dir(dir, "themes", name, file);
            if (path != null) {
                return path;
            }
        }

        // Finally, try in the default theme directory.
        string dir = theme_dir();
        path = find_theme_dir(dir, null, name, file);

        return path;
    }

    private void
    load_named(string name, string? variant) {
        return_if_fail(name != null);

        // Try to load from the set of built-in themes.
        string resource_path;
        if (variant != null) {
            resource_path = "/com/bwhmather/Bricks/theme/%s/brk-%s.css".printf(name, variant);
        } else {
            resource_path = "/com/bwhmather/Bricks/theme/%s/brk.css".printf(name);
        }

        try {
            GLib.resources_get_info(resource_path, 0, null, null);
            this.provider.load_from_resource(resource_path);
            return;
        } catch {}

        // Next look for files in the various theme directories.
        string? path = find_theme(name, variant);
        if (path != null) {
            this.provider.load_from_path(path);
            return;
        }

        // Things failed! Fall back!
        //
        // To match GTK, we accept the names HighContrast, HighContrastInverse,
        // Adwaita and Adwaita-dark as aliases for the variants of the Default
        // theme.
        if (name == "HighContrast") {
            if (variant == "dark") {
                this.load_named("Default", "hc-dark");
            } else {
                this.load_named("Default", "hc");
            }
            return;
        }

        if (name == "HighContrastInverse") {
            this.load_named("Default", "hc-dark");
            return;
        }

        if (name == "Adwaita-dark") {
            this.load_named("Default", "dark");
            return;
        }

        // At this point we diverge from GTK.  GTK falls back to "Default" for
        // all other requests.  We only fallback for "Adwaita" and assume other
        // themes won't be loaded unless they have a libbricks variant.
        if (name == "Adwaita") {
            this.load_named("Default", null);
            return;
        }

        this.load_named("Empty", null);
    }

    // Based on `get_theme_name` from `gtksettings.c`.  Should be kept in sync
    // to prevent GTK and libbricks loading different themes.
    private void
    get_theme_name(out string? theme_name, out string? theme_variant) {
        theme_name = null;
        theme_variant = null;

        var gtk_settings = Gtk.Settings.get_for_display(this.display);

        var gtk_theme_env = Environment.get_variable("GTK_THEME");
        if (gtk_theme_env != null) {
            theme_name = gtk_theme_env;
            int index = theme_name.last_index_of(":");
            if (index != -1) {
                theme_variant = theme_name.substring(index + 1);
                theme_name = theme_name.substring(0, index);
            }
            return;
        }

        theme_name = gtk_settings.gtk_theme_name;

        if (gtk_settings.gtk_application_prefer_dark_theme) {
            theme_variant = "dark";
        }
        if (theme_name != null) {
            return;
        }

        theme_name = "Default";
    }

    private void
    update_stylesheet() {
        string theme_name;
        string theme_variant;
        this.get_theme_name(out theme_name, out theme_variant);
        this.load_named(theme_name, theme_variant);
    }

    construct {
        var gtk_settings = Gtk.Settings.get_for_display(this.display);
        gtk_settings.notify["gtk-theme-name"].connect((s, pspec) => {
            this.update_stylesheet();
        });
        gtk_settings.notify["gtk-application-prefer-dark-theme"].connect((s, pspec) => {
            this.update_stylesheet();
        });

        var priority = (
            Gtk.STYLE_PROVIDER_PRIORITY_THEME +
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            ) / 2;
        Gtk.StyleContext.add_provider_for_display(this.display, this.provider, priority);

        this.update_stylesheet();
    }

    public StyleManager(Gdk.Display display) {
        Object(display: display);
    }
}
