/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Brk.PreferencesRow : Gtk.ListBoxRow {
    public string title { get; set; }
    public bool title_selectable { get; set; }
    public bool use_markup { get; set; }
    public bool use_underline { get; set; }
}

public sealed class Brk.ActionRow : Brk.PreferencesRow {

}

public sealed class Brk.ButtonRow : Brk.PreferencesRow {

}

public sealed class Brk.ComboRow : Brk.PreferencesRow {

}

public sealed class Brk.EntryRow : Brk.PreferencesRow {

}

public sealed class Brk.ExpanderRow : Brk.PreferencesRow {

}

public sealed class Brk.SpinRow : Brk.PreferencesRow {

}

public sealed class Brk.SwitchRow : Brk.PreferencesRow {

}


[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-preferences-group.ui")]
public sealed class Brk.PreferencesGroup : Gtk.Widget {
    public string title { get; set; }
    public string description { get; set; }
    public Gtk.Widget? header_suffix { get; set; }
    public bool separate_rows { get; set; }

    [GtkChild]
    private unowned Gtk.Label title_label;
    [GtkChild]
    private unowned Gtk.Label description_label;

    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("preferencesgroups");
        set_accessible_role(GROUP);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.VERTICAL, -1);
        var layout_manager = this.layout_manager as Gtk.BoxLayout;
        layout_manager.orientation = VERTICAL;

        this.bind_property("title", title_label, "label", SYNC_CREATE);
        this.bind_property("description", description_label, "label", SYNC_CREATE);
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.PreferencesGroup));
    }
}

public sealed class Brk.PreferencesPage : Gtk.Widget {
    public string title { get; set; }
    public string icon_name { get; set; }
    public bool use_underline { get; set; }

    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("preferencespage");
        set_accessible_role(GROUP);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.VERTICAL, -1);
        var layout_manager = this.layout_manager as Gtk.BoxLayout;
        layout_manager.orientation = VERTICAL;
    }

    public override void
    dispose() {
        while (this.get_last_child() != null) {
            this.get_last_child().unparent();
        }
        base.dispose();
    }

    public void
    add(Brk.PreferencesGroup group) {
        group.insert_before(this, null);
    }
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-preferences-dialog.ui")]
public class Brk.PreferencesDialog : Gtk.Window, Gtk.Buildable {
    public bool search_enabled { get; set; }
    public Brk.PreferencesPage visible_page { get; set; }

    [GtkChild]
    private unowned Gtk.Stack stack;

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.PreferencesDialog));
        base.dispose();
    }

    public void
    add_child(Gtk.Builder builder, GLib.Object child, string? type) {
        if (type == null && child is Brk.PreferencesPage) {
            this.add(child as Brk.PreferencesPage);
            return;
        }
        base.add_child(builder, child, type);
    }

    public void
    add(Brk.PreferencesPage page) {
        var stack_page = this.stack.add_named(page, page.name);

        page.bind_property("icon-name", stack_page, "icon-name", SYNC_CREATE);
        page.bind_property("title", stack_page, "title", SYNC_CREATE);
        page.bind_property("use-underline", stack_page, "use-underline", SYNC_CREATE);
        page.bind_property("name", stack_page, "name", SYNC_CREATE);
    }

    public void
    remove(Brk.PreferencesPage page) {
        this.stack.remove(page);
    }
}
