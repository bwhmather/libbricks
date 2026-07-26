/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */


internal sealed class Brk.FileThumbnail : Gtk.Widget {
    public GLib.FileInfo? fileinfo { get; set; }

    public int thumbnail_size { get; set; default = 16; }

    private Gtk.Image image;

    class construct {
        set_layout_manager_type(typeof (Gtk.BinLayout));
    }

    private void
    update_image() {
        if (this.fileinfo == null) {
            this.image.clear();
            return;
        }

        if (this.thumbnail_size >= 32) {
            var path = this.fileinfo.get_attribute_byte_string("thumbnail::path");
            if (path != null && this.fileinfo.get_attribute_boolean("thumbnail::is-valid")) {
                this.image.set_from_file(path);
                return;
            }
        }

        var icon_theme = Gtk.IconTheme.get_for_display(this.get_display());
        var icon = this.fileinfo.get_icon();
        if (icon == null || !icon_theme.has_gicon(icon)) {
          icon = new GLib.ThemedIcon("text-x-generic");
        }
        this.image.set_from_gicon(icon);
    }

    construct {
        this.image = new Gtk.Image();
        image.set_parent(this);
        this.bind_property("thumbnail-size", this.image, "pixel-size", SYNC_CREATE);

        this.notify["fileinfo"].connect(this.update_image);
        this.notify["thumbnail-size"].connect(this.update_image);
    }

    public override void
    dispose() {
        this.image.unparent();
        base.dispose();
    }
}
