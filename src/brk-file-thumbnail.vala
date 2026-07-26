/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */


internal sealed class Brk.FileThumbnail : Gtk.Widget {
    public GLib.FileInfo? fileinfo { get; set; }

    public int thumbnail_size { get; set; default = 16; }

    private Gtk.Image image;
    private GLib.Cancellable? cancellable;

    class construct {
        set_layout_manager_type(typeof (Gtk.BinLayout));
    }

    private async void
    update_image() {
        if (this.cancellable != null) {
            this.cancellable.cancel();
            this.cancellable = null;
        }

        if (this.fileinfo == null) {
            this.image.clear();
            return;
        }

        // Show the icon for the file type first.  It gets replaced if and when
        // a thumbnail finishes loading.
        var icon_theme = Gtk.IconTheme.get_for_display(this.get_display());
        var icon = this.fileinfo.get_icon();
        if (icon == null || !icon_theme.has_gicon(icon)) {
          icon = new GLib.ThemedIcon("text-x-generic");
        }
        this.image.set_from_gicon(icon);

        if (this.thumbnail_size < 32) {
            // Don't bother with proper thumbnails if not enough space.
            return;
        }

        var path = this.fileinfo.get_attribute_byte_string("thumbnail::path");
        if (path == null) {
            return;
        }

        var cancellable = new GLib.Cancellable();
        this.cancellable = cancellable;

        var size = this.thumbnail_size * this.scale_factor;
        try {
            var stream = yield GLib.File.new_for_path(path).read_async(
                GLib.Priority.LOW, cancellable
            );
            var pixbuf = yield new Gdk.Pixbuf.from_stream_at_scale_async(
                stream, size, size, true, cancellable
            );
            this.image.set_from_paintable(Gdk.Texture.for_pixbuf(pixbuf));
        } catch (GLib.Error error) {
            return;
        }
    }

    construct {
        this.image = new Gtk.Image();
        image.set_parent(this);
        this.bind_property("thumbnail-size", this.image, "pixel-size", SYNC_CREATE);

        this.notify["fileinfo"].connect(() => {
            this.update_image.begin();
        });
        this.notify["thumbnail-size"].connect(() => {
            this.update_image.begin();
        });
    }

    public override void
    dispose() {
        if (this.cancellable != null) {
            this.cancellable.cancel();
            this.cancellable = null;
        }
        this.image.unparent();
        base.dispose();
    }
}
