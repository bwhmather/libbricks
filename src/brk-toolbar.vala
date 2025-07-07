/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Brk.Toolbar : Gtk.Widget {
    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("toolbar");
        set_accessible_role(GROUP);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.HORIZONTAL, -1);
        this.add_css_class("toolbar");
    }

    public override void
    dispose() {
        while (this.get_last_child() != null) {
            this.get_last_child().unparent();
        }
        base.dispose();
    }

    public void
    append(Gtk.Widget child) {
        return_if_fail(child.parent == null);
        this.insert_before(child, null);
    }

    public void
    prepend(Gtk.Widget child) {
        return_if_fail(child.parent == null);
        this.insert_after(child, null);
    }

    public void
    remove(Gtk.Widget child) {
        return_if_fail(child.parent != this);
        child.unparent();
    }
}
