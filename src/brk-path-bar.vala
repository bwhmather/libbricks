/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

private sealed class Brk.FileDialogPathBar : Gtk.Widget {
    public GLib.File root_directory { get; set; }

    private Gtk.ToggleButton edit_toggle;
    private Gtk.Entry edit_entry;

    private void
    update_segments() {
        while (this.get_first_child() != this.edit_entry) {
           this.get_first_child().unparent();
        }
        for (var file = this.root_directory; file != null; file = file.get_parent()) {
            var button = new Gtk.Button();
            button.label = file.get_basename();
            var target = file;
            button.clicked.connect(() => {
                this.root_directory = target;
            });
            button.insert_before(this, this.get_first_child());
        }
        this.update_visible();
    }

    private void
    update_visible() {
        bool editting = edit_toggle.active;
        this.edit_entry.visible = editting;
        for (
            var segment = this.get_first_child();
            segment != this.edit_entry;
            segment = segment.get_next_sibling()
        ) {
            segment.visible = !editting;
        }
    }

    class construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("path-bar");
    }

    construct {
        this.add_css_class("linked");

        this.edit_toggle = new Gtk.ToggleButton();
        this.edit_toggle.set_icon_name("document-edit");
        edit_toggle.set_parent(this);

        this.edit_entry = new Gtk.Entry();
        this.edit_entry.hexpand = true;
        edit_entry.insert_before(this, this.edit_toggle);

        this.edit_toggle.notify["active"].connect(this.update_visible);
        this.notify["root-directory"].connect(this.update_segments);
        this.update_segments();
    }

    public override void
    dispose() {
        while (this.get_last_child() != null) {
            this.get_last_child().unparent();
        }
        base.dispose();
    }
}
