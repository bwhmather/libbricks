namespace Brk {

private string
get_theme_dir() {
    string? var = Environment.get_variable("BRK_DATA_PREFIX");
    if (var == null) {
        var = BRK_DATA_PREFIX;
    }

    return Path.build_filename(var, "share", "themes");
}

private string?
css_find_theme_dir(string dir, string? subdir, string name, string file) {
    string base;
    string? path = null;

    if (subdir != null) {
        base = Path.build_filename(dir, subdir, name);
    } else {
        base = Path.build_filename(dir, name);
    }

    if (!FileUtils.test(base, FileTest.IS_DIR)) {
        return null;
    }

    for (int i = BRK_MINOR_VERSION; i >= 0; i--) {
        string subsubdir = "brk-%d.%d".printf(BRK_MAJOR_VERSION, i);
        path = Path.build_filename(base, subsubdir, file);

        if (FileUtils.test(path, FileTest.EXISTS)) {
            break;
        }

        path = null;
    }

    return path;
}

private string?
css_find_theme(string name, string? variant) {
    string file;
    string? path;
    string[] dirs = FileUtils.get_system_data_dirs();

    assert(name != null);

    if (variant != null) {
        file = "brk-%s.css".printf(variant);
    } else {
        file = "gtk.css";
    }

    path = css_find_theme_dir(Environment.get_user_data_dir(), "themes", name, file);
    if (path != null) {
        return path;
    }

    path = css_find_theme_dir(Environment.get_home_dir(), ".themes", name, file);
    if (path != null) {
        return path;
    }

    foreach (string dir in dirs) {
        path = css_find_theme_dir(dir, "themes", name, file);
        if (path != null) {
            return path;
        }
    }

    string dir = get_theme_dir();
    path = css_find_theme_dir(dir, null, name, file);

    return path;
}

internal sealed class Brk.StyleManager : GLib.Object {
    public Gdk.Display display { get; construct; }

    public StyleManager(Gdk.Display display) {
        Object(display: display);
    }
}

}
