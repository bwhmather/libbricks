/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-quick-open-entry.ui")]
internal sealed class Brk.QuickOpenEntry : Gtk.Widget {

    /* === State ============================================================ */

    public GLib.File? root_directory { get; set; default = null; }
    public bool show_binary { get; set; }
    public bool show_hidden { get; set; }

    public bool loading { get { return this.filter_view.loading; } }
    public GLib.FileInfo? selection { get; set; }

    public string text { get; set; default = ""; }

    /* === Text Entry ======================================================= */

    [GtkChild]
    private unowned Gtk.Text text_input;

    public unowned Gtk.Widget get_delegate() {
        return this.text_input;
    }

    public bool grab_focus_without_selecting() {
        return this.text_input.grab_focus_without_selecting();
    }

    // Keyboard input on the text entry can be handled asnychronously if the
    // view is still catching up.  Navigation (using up and down keys  before
    // the entry is submitted is buffered manually here.  Everything after the
    // entry is submitted is buffered using a Gtk.EventControllerBuffer.  Input
    // anywhere else is handled synchronously and ignores these two mechanisms.
    private int[] navigate = null;
    private bool submit = false;

    private void
    clear_commands() {
        this.navigate = null;
        this.submit = false;
    }

    private void
    play_commands() {
        if (this.filter_view.loading) {
            return;
        }

        foreach (int step in this.navigate) {
            while (step < 0) {
                this.filter_view.select_prev();
                step += 1;
            }
            while (step > 0) {
                this.filter_view.select_next();
                step -= 1;
            }
        }
        if (this.submit) {
            var fileinfo = this.filter_view.selection;
            if (fileinfo != null) {
                this.file_activated(fileinfo);
            }
        }

        this.navigate = null;
        this.submit = false;
    }

    private void
    text_input_init() {
        var buffer_controller = new Gtk.EventControllerBuffer();
        buffer_controller.propagation_phase = CAPTURE;
        buffer_controller.discarded.connect(() => {
            // Queued commands are effectively the same as buffered input.
            // If we lose the input buffer then commands should also be dropped.
            this.clear_commands();
        });

        var cancel_controller = new Gtk.ShortcutController();
        cancel_controller.propagation_phase = CAPTURE;
        cancel_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Escape"),
            new Gtk.CallbackAction(() => {
                // This shortcut controller is only installed so that we can
                // bypass the keyboard buffer and cancel a long running query
                // without having to wait until it finishes.  Usually we want
                // to wait until BUBBLE so that the input method can get a
                // chance to consume it first.
                if (buffer_controller.enabled) {
                    this.text = "";
                    return true;
                }
                return false;
            })
        ));

        var shortcut_controller = new Gtk.ShortcutController();
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Up"),
            new Gtk.CallbackAction(() => {
                return_val_if_fail(!this.submit, false);  // Should be caught by buffer.
                this.navigate += -1;
                this.play_commands();
                return true;
            })
        ));
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Down"),
            new Gtk.CallbackAction(() => {
                return_val_if_fail(!this.submit, false);  // Should be caught by buffer.
                this.navigate += 1;
                this.play_commands();
                return true;
            })
        ));

        // The order here is important.  The cancel controller must be able to
        // intercept events before they are buffered.  The shortcut controller
        // must not receive events until after they are released.
        this.text_input.add_controller(cancel_controller);
        this.text_input.add_controller(buffer_controller);
        this.text_input.add_controller(shortcut_controller);

        this.filter_view.notify["loading"].connect((_, pspec) => {
            this.notify_property("loading");
            if (!this.filter_view.loading) {
                this.play_commands();
                buffer_controller.replay();
            }
        });

        this.text_input.activate.connect(() => {
            return_if_fail(!this.submit);  // Should be caught by buffer.
            buffer_controller.enable();
            this.submit = true;
            this.play_commands();
        });

        this.bind_property("text", this.text_input, "text", SYNC_CREATE | BIDIRECTIONAL);
        this.text_input.notify["text"].connect((fe, pspec) => {
            // Buffered keyboard events will have happened before whatever
            // changed the entry (for example, a careful middle click paste)
            // and so can't be replayed after.
            buffer_controller.discard();
        });
        this.text_input.notify["cursor-position"].connect((_, pspec) => {
            // Likewise, replaying events after moving the cursor would cause
            // text to be entered in the wrong place.
            buffer_controller.discard();
        });
    }

    /* === Popover ========================================================== */

    [GtkChild]
    private unowned Gtk.Popover popover;

    [GtkChild]
    private unowned Brk.FileDialogFilterView filter_view;

    public signal void file_activated(GLib.FileInfo fileinfo);

    private void
    popover_init() {
        this.bind_property("text", this.filter_view, "query", SYNC_CREATE);
        this.bind_property("root-directory", this.filter_view, "root-directory", SYNC_CREATE);
        this.bind_property("show-binary", this.filter_view, "show-binary", SYNC_CREATE);
        this.bind_property("show-hidden", this.filter_view, "show-hidden", SYNC_CREATE);

        this.filter_view.bind_property("selection", this, "selection", SYNC_CREATE);

        this.notify["text"].connect((_, pspec) => {
            if (this.text != "") {
                this.popover.popup();
            } else {
                this.popover.popdown();
            }
        });

        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.enter.connect(() => {
            if (this.text != "") {
                this.popover.popup();
            }
        });
        focus_controller.leave.connect(() => {
            this.popover.popdown();
        });
        this.add_controller(focus_controller);

        var key_controller = new Gtk.EventControllerKey();
        key_controller.propagation_phase = BUBBLE;
        key_controller.key_pressed.connect((controller, keyval, keycode, modifiers) => {
            return key_controller.forward(this.text_input);
        });
        ((Gtk.Widget) this.popover).add_controller(key_controller);
    }

    /* === Lifecycle ======================================================== */

    class construct {
        typeof (Brk.FileDialogFilterView).ensure();
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("entry");
    }

    construct {
        this.text_input_init();
        this.popover_init();
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.QuickOpenEntry));
        base.dispose();
    }

    public void
    select_prev() {
        this.filter_view.select_prev();
    }

    public void
    select_next() {
        this.filter_view.select_next();
    }
}
