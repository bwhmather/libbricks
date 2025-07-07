/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

/**
 * A statusbar widget is usually placed along the bottom of an application's
 * main window.
 *
 * Unlike the deprecated GtkStatusbar class, BrkStatusbar is intended as a
 * literal bar that covers the whole of the bottom of the window and explicitly
 * supports having child widgets added to its end.
 */
private struct Brk.StatusbarMessage {
    uint context_id;
    uint message_id;
    string text;

    Brk.StatusbarMessage? next;
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-statusbar.ui")]
public sealed class Brk.Statusbar : Gtk.Widget {
    private uint next_context_id = 1;
    private uint next_message_id = 1;

    private Brk.StatusbarMessage? messages;

    [GtkChild]
    private unowned Gtk.Label label;

    static construct {
        set_layout_manager_type(typeof(Gtk.BoxLayout));
        set_css_name("statusbar");
        set_accessible_role(GROUP);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.HORIZONTAL, -1);
        this.add_css_class("statusbar");
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.Statusbar));
        base.dispose();
    }

    /**
     * Returns a new context id that can be used for managing messages.
     */
    public uint
    new_context_id() {
        uint context_id = this.next_context_id;
        this.next_context_id += 1;

        return context_id;
    }

    /**
     * Pushes a new message onto the statusbar's stack.
     *
     * Returns a message id that can be passed to remove() to remove the
     * message.
     */
    public uint
    push(uint context_id, string text) {
        return_val_if_fail(context_id > 0, 0);
        return_val_if_fail(context_id < this.next_context_id, 0);

        uint message_id = this.next_message_id;
        this.next_message_id += 1;

        Brk.StatusbarMessage? message = Brk.StatusbarMessage() {
            context_id = context_id,
            message_id = message_id,
            text = text,
            next = (owned) this.messages,
        };
        this.messages = message;

        this.label.set_text(this.messages == null ? "" : this.messages.text);

        return message_id;
    }

    /**
     * Removes the first message in the statusbar's stack with the given
     * context id.
     *
     * Note that this will not change the displayed message if the message at
     * the top of the stack has a different context id.
     */
    public void
    pop(uint context_id) {
        return_if_fail(context_id > 0);
        return_if_fail(context_id < this.next_context_id);

        unowned Brk.StatusbarMessage? prev = null;
        unowned Brk.StatusbarMessage? curr = null;

        for (curr = this.messages; curr != null; curr = curr.next) {
            if (curr.context_id != context_id) {
                prev = curr;
                continue;
            }

            if (prev == null) {
                this.messages = (owned) curr.next;
            } else {
                prev.next = (owned) curr.next;
            }

            this.label.set_text(this.messages == null ? "" : this.messages.text);
            return;
        }

        return_if_reached();
    }

    /**
     * Forces the removal of a message from the statusbar's stack.
     * The exact context id and message id must be specified.
     */
    public void
    remove(uint context_id, uint message_id) {
        return_if_fail(context_id > 0);
        return_if_fail(context_id < this.next_context_id);

        unowned Brk.StatusbarMessage? prev = null;
        unowned Brk.StatusbarMessage? curr = null;

        for (curr = this.messages; curr != null; curr = curr.next) {
            if (curr.context_id != context_id && curr.message_id != message_id) {
                prev = curr;
                continue;
            }

            if (prev == null) {
                this.messages = (owned) curr.next;
            } else {
                prev.next = (owned) curr.next;
            }

            this.label.set_text(this.messages == null ? "" : this.messages.text);
            return;
        }

        return_if_reached();
    }

    /**
     * Forces the removal of all messages from the statusbar's stack with
     * the exact context id.
     */
    public void
    remove_all(uint context_id) {

        return_if_fail(context_id > 0);
        return_if_fail(context_id < this.next_context_id);

        unowned Brk.StatusbarMessage? prev = null;
        unowned Brk.StatusbarMessage? curr = this.messages;

        while (curr != null) {
            if (curr.context_id != context_id) {
                prev = curr;
                curr = prev.next;
                continue;
            }

            if (prev == null) {
                this.messages = (owned) curr.next;
                curr = this.messages;
            } else {
                prev.next = (owned) curr.next;
                curr = prev.next;
            }
        }

        this.label.set_text(this.messages == null ? "" : this.messages.text);
    }

    /**
     */

    public void
    append_child(Gtk.Widget child) {
        return_if_fail(child.parent == null);
        this.insert_before(child, null);
    }

    public void
    remove_child(Gtk.Widget child) {
        return_if_fail(child.parent != this);
        child.unparent();
    }
}

