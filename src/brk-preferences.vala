/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Brk.PreferencesRow : Gtk.ListBoxRow {
    public string title { get; set; default = ""; }
    public bool title_selectable { get; set; }
    public bool use_markup { get; set; default = true; }
    public bool use_underline { get; set; }
}

public class Brk.ActionRow : Brk.PreferencesRow {
    private Gtk.Box prefixes;
    private Gtk.Label title_label;
    private Gtk.Label subtitle_label;
    private Gtk.Box suffixes;

    private Gtk.Widget? previous_parent = null;

    public string subtitle { get; set; default = ""; }

    private Gtk.Widget? _activatable_widget = null;
    private GLib.Binding? activatable_binding = null;

    public Gtk.Widget? activatable_widget {
        get { return this._activatable_widget; }
        set {
            if (this._activatable_widget == value)
                return;

            if (this.activatable_binding != null) {
                this.activatable_binding.unbind();
                this.activatable_binding = null;
            }

            this._activatable_widget = value;

            if (this._activatable_widget != null) {
                this.set_activatable(true);
                this.activatable_binding = this._activatable_widget.bind_property(
                    "sensitive", this, "sensitive", SYNC_CREATE
                );
            }

            this.notify_property("activatable-widget");
        }
    }

    public signal void activated();

    private void
    update_title_visibility() {
        this.title_label.visible = this.title != null && this.title != "";
    }

    private void
    update_subtitle_visibility() {
        this.subtitle_label.visible = this.subtitle != null && this.subtitle != "";
    }

    private void
    on_row_activated(Gtk.ListBoxRow row) {
        if (row == this) {
            this.do_activate();
        }
    }

    private void
    on_parent_changed() {
        if (this.previous_parent != null) {
            (this.previous_parent as Gtk.ListBox).row_activated.disconnect(this.on_row_activated);
            this.previous_parent = null;
        }

        var parent = this.get_parent();
        if (parent == null || !(parent is Gtk.ListBox))
            return;

        this.previous_parent = parent;
        (parent as Gtk.ListBox).row_activated.connect(this.on_row_activated);
    }

    private void
    do_activate() {
        if (this._activatable_widget != null) {
            this._activatable_widget.mnemonic_activate(false);
        }
        this.activated();
    }

    construct {
        var header = new Gtk.Box(HORIZONTAL, 0);
        header.valign = CENTER;
        header.add_css_class("header");

        this.prefixes = new Gtk.Box(HORIZONTAL, 0);
        this.prefixes.visible = false;
        this.prefixes.add_css_class("prefixes");
        header.append(this.prefixes);

        var title_box = new Gtk.Box(VERTICAL, 0);
        title_box.valign = CENTER;
        title_box.hexpand = true;
        title_box.add_css_class("title");

        this.title_label = new Gtk.Label(null);
        this.title_label.visible = false;
        this.title_label.xalign = 0;
        this.title_label.wrap = true;
        this.title_label.wrap_mode = WORD_CHAR;
        this.title_label.add_css_class("title");
        title_box.append(this.title_label);

        this.subtitle_label = new Gtk.Label(null);
        this.subtitle_label.visible = false;
        this.subtitle_label.xalign = 0;
        this.subtitle_label.wrap = true;
        this.subtitle_label.wrap_mode = WORD_CHAR;
        this.subtitle_label.add_css_class("subtitle");
        title_box.append(this.subtitle_label);

        header.append(title_box);

        this.suffixes = new Gtk.Box(HORIZONTAL, 0);
        this.suffixes.visible = false;
        this.suffixes.add_css_class("suffixes");
        header.append(this.suffixes);

        this.child = header;

        this.bind_property("title", this.title_label, "label", SYNC_CREATE);
        this.notify["title"].connect(this.update_title_visibility);
        this.bind_property("subtitle", this.subtitle_label, "label", SYNC_CREATE);
        this.notify["subtitle"].connect(this.update_subtitle_visibility);
        this.bind_property("use-markup", this.title_label, "use-markup", SYNC_CREATE);
        this.bind_property("use-markup", this.subtitle_label, "use-markup", SYNC_CREATE);
        this.bind_property("use-underline", this.title_label, "use-underline", SYNC_CREATE);
        this.bind_property("title-selectable", this.title_label, "selectable", SYNC_CREATE);

        this.update_title_visibility();
        this.update_subtitle_visibility();

        this.notify["parent"].connect(this.on_parent_changed);
    }

    public void
    add_prefix(Gtk.Widget widget) {
        this.prefixes.prepend(widget);
        this.prefixes.visible = true;
    }

    public void
    add_suffix(Gtk.Widget widget) {
        this.suffixes.append(widget);
        this.suffixes.visible = true;
    }

    public void
    remove(Gtk.Widget widget) {
        var parent = widget.get_parent();
        if (parent == this.prefixes || parent == this.suffixes) {
            (parent as Gtk.Box).remove(widget);
            parent.visible = parent.get_first_child() != null;
        }
    }

    public override void
    dispose() {
        if (this.previous_parent != null) {
            (this.previous_parent as Gtk.ListBox).row_activated.disconnect(this.on_row_activated);
            this.previous_parent = null;
        }
        this.activatable_widget = null;
        base.dispose();
    }
}

public sealed class Brk.ButtonRow : Brk.PreferencesRow {

}

public sealed class Brk.ComboRow : Brk.PreferencesRow {

}

public sealed class Brk.EntryRow : Brk.PreferencesRow {

}

public sealed class Brk.ExpanderRow : Brk.PreferencesRow {

}

public sealed class Brk.SpinRow : Brk.ActionRow {
    private Gtk.SpinButton spin_button;

    public Gtk.Adjustment adjustment {
        get { return this.spin_button.adjustment; }
        set { this.spin_button.adjustment = value; }
    }
    public double climb_rate { get; set; default = 0.0; }
    public uint digits { get; set; default = 0; }
    public bool snap_to_ticks { get; set; default = false; }
    public Gtk.SpinButtonUpdatePolicy update_policy { get; set; default = ALWAYS; }
    public double value { get; set; default = 0.0; }
    public bool wrap { get; set; default = false; }

    construct {
        this.spin_button = new Gtk.SpinButton(null, 1.0, 0);
        this.spin_button.valign = CENTER;
        this.spin_button.focusable = false;
        this.add_suffix(this.spin_button);
        this.activatable_widget = this.spin_button;

        this.spin_button.notify["adjustment"].connect(() => { this.notify_property("adjustment"); });
        this.bind_property("climb-rate", this.spin_button, "climb-rate", SYNC_CREATE | BIDIRECTIONAL);
        this.bind_property("digits", this.spin_button, "digits", SYNC_CREATE | BIDIRECTIONAL);
        this.bind_property("snap-to-ticks", this.spin_button, "snap-to-ticks", SYNC_CREATE | BIDIRECTIONAL);
        this.bind_property("update-policy", this.spin_button, "update-policy", SYNC_CREATE | BIDIRECTIONAL);
        this.bind_property("value", this.spin_button, "value", SYNC_CREATE | BIDIRECTIONAL);
        this.bind_property("wrap", this.spin_button, "wrap", SYNC_CREATE | BIDIRECTIONAL);
    }

    public void configure(Gtk.Adjustment? adjustment, double climb_rate, uint digits) {
        this.adjustment = adjustment;
        this.climb_rate = climb_rate;
        this.digits = digits;
    }
}

public sealed class Brk.SwitchRow : Brk.ActionRow {
    private Gtk.Switch slider;

    public bool active {
        get { return this.slider.active; }
        set { this.slider.active = value; }
    }

    static construct {
        set_accessible_role(SWITCH);
    }

    construct {
        this.slider = new Gtk.Switch();
        this.slider.valign = CENTER;
        this.slider.focusable = false;
        this.set_activatable(true);
        this.add_suffix(this.slider);
        this.activatable_widget = this.slider;

        this.bind_property("action-name", this.slider, "action-name", SYNC_CREATE);
        this.bind_property("action-target", this.slider, "action-target", SYNC_CREATE);

        this.slider.notify["active"].connect(() => {
            this.notify_property("active");
        });
    }
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-preferences-group.ui")]
public sealed class Brk.PreferencesGroup : Gtk.Widget, Gtk.Buildable {
    private GLib.ListModel rows;

    [GtkChild]
    private unowned Gtk.Box header_box;
    [GtkChild]
    private unowned Gtk.Label title_label;
    [GtkChild]
    private unowned Gtk.Label description_label;
    [GtkChild]
    private unowned Gtk.ListBox listbox;

    public string title { get; set; default = ""; }
    public string description { get; set; default = ""; }

    private Gtk.Widget? _header_suffix = null;

    public Gtk.Widget? header_suffix {
        get { return this._header_suffix; }
        set {
            if (this._header_suffix != null) {
                this.header_box.remove(this._header_suffix);
            }
            this._header_suffix = value;
            if (this._header_suffix != null) {
                this.header_box.append(this._header_suffix);
            }
            this.update_header_visibility();
            this.notify_property("header-suffix");
        }
    }

    private void
    update_title_visibility() {
        this.title_label.visible = this.title != null && this.title != "";
        this.update_header_visibility();
    }

    private void
    update_description_visibility() {
        this.description_label.visible = this.description != null && this.description != "";
        this.update_header_visibility();
    }

    private void
    on_rows_changed(uint pos, uint removed, uint added) {
        this.listbox.visible = this.rows.get_n_items() > 0;
    }

    private void
    update_header_visibility() {
        this.header_box.visible =
            this.title_label.visible ||
            this.description_label.visible ||
            this._header_suffix != null;
    }

    static construct {
        set_layout_manager_type(typeof(Gtk.BoxLayout));
        set_css_name("preferencesgroup");
        set_accessible_role(GROUP);
    }

    construct {
        (this.get_layout_manager() as Gtk.BoxLayout).orientation = VERTICAL;
        this.hexpand = true;

        this.bind_property("title", this.title_label, "label", SYNC_CREATE);
        this.bind_property("description", this.description_label, "label", SYNC_CREATE);

        this.notify["title"].connect(this.update_title_visibility);
        this.notify["description"].connect(this.update_description_visibility);

        this.rows = this.listbox.observe_children();
        this.rows.items_changed.connect(this.on_rows_changed);

        this.update_title_visibility();
        this.update_description_visibility();
        this.update_header_visibility();
        this.listbox.visible = this.rows.get_n_items() > 0;
    }

    public override void
    dispose() {
        if (this.rows != null) {
            this.rows.items_changed.disconnect(this.on_rows_changed);
            this.rows = null;
        }
        if (this.header_box != null)
            this.header_box.unparent();
        if (this.listbox != null)
            this.listbox.unparent();
        this.dispose_template(typeof(Brk.PreferencesGroup));
        base.dispose();
    }

    public void
    add(Gtk.Widget child) {
        if (child is Gtk.ListBoxRow) {
            this.listbox.append(child);
        } else {
            child.insert_before(this, null);
        }
    }

    public void
    remove(Gtk.Widget child) {
        var parent = child.get_parent();
        if (parent == this.listbox) {
            this.listbox.remove(child);
        } else if (parent == this) {
            child.unparent();
        }
    }

    public new void
    add_child(Gtk.Builder builder, GLib.Object child, string? type) {
        if (type == "header-suffix" && child is Gtk.Widget) {
            this.header_suffix = child as Gtk.Widget;
            return;
        }
        if (this.listbox != null && child is Gtk.Widget) {
            this.add(child as Gtk.Widget);
            return;
        }
        base.add_child(builder, child, type);
    }
}

public sealed class Brk.PreferencesPage : Gtk.Widget, Gtk.Buildable {
    public string title { get; set; }
    public string icon_name { get; set; }
    public bool use_underline { get; set; }

    private Gtk.ScrolledWindow scroll_window;
    private Gtk.Box box;

    static construct {
        set_layout_manager_type(typeof(Gtk.BinLayout));
        set_css_name("preferencespage");
        set_accessible_role(GROUP);
    }

    construct {
        this.scroll_window = new Gtk.ScrolledWindow();
        this.scroll_window.hscrollbar_policy = NEVER;
        this.scroll_window.vexpand = true;
        this.scroll_window.insert_before(this, null);

        this.box = new Gtk.Box(VERTICAL, 0);
        this.box.hexpand = true;
        this.box.add_css_class("content");
        this.scroll_window.child = this.box;
    }

    public override void
    dispose() {
        this.scroll_window.unparent();
        base.dispose();
    }

    public void
    add(Brk.PreferencesGroup group) {
        this.box.append(group);
    }

    public new void
    add_child(Gtk.Builder builder, GLib.Object child, string? type) {
        if (child is Brk.PreferencesGroup) {
            this.add(child as Brk.PreferencesGroup);
            return;
        }
        base.add_child(builder, child, type);
    }
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-preferences-window.ui")]
public class Brk.PreferencesWindow : Gtk.Window, Gtk.Buildable {
    public bool search_enabled { get; set; }

    private Brk.PreferencesPage _visible_page;

    public Brk.PreferencesPage visible_page {
        get { return this._visible_page; }
        set {
            this._visible_page = value;
            if (value != null) {
                this.stack.set_visible_child(value);
            }
            this.notify_property("visible-page");
        }
    }

    [GtkChild]
    private unowned Gtk.Stack stack;

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.PreferencesWindow));
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
