/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public class Brk.ButtonGroup : Gtk.Widget {
    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("button-group");
        set_accessible_role(GROUP);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.HORIZONTAL, -1);
        this.add_css_class("linked");
    }

    public override void
    dispose() {
        while (this.get_last_child() != null) {
            this.get_last_child().unparent();
        }
        base.dispose();
    }
}
