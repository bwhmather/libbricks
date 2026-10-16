/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public sealed class Brk.Entry : Gtk.Widget, Gtk.Editable {

    /* === State ============================================================ */

    public string text { get; set; default = ""; }


    /* === Completion ======================================================= */

    private bool completion_enabled = false;

    /**
     * An optional list model containing possible values for the entry.
     *
     * Need not be exhaustive.
     *
     * If set to a Brk.SearchModel instance then will be passed the current
     * query.
     */
    public GLib.ListModel completion_model { get; set; }

    /**
     * Used to construct rows to appear in the completion popover.
     */
    public Gtk.ListItemFactory completion_factory { get; set; }

    /**
     * Used to convert completions to text for filtering (if completion_model is
     * not a Brk.SearchModel) finding common prefixes, replacing the entry text
     * if a completion is selected.
     */
    public Gtk.Expression completion_expression { get; set; }

    /**
     * If set, selecting a completion will immediately activate the entry.
     * This is the behaviour of most browser address bars.  Normally selecting a
     * completion will just update the entry.
     */
    public bool completion_activate { get; set; }

    private Brk.SearchModel completion_search_model;
    private Gtk.SingleSelection completion_selection_model;

    private bool completion_submit;

    private Gtk.Popover completion_popover;
    private Gtk.ListView completion_list_view;

    private void
    completion_rebuild() {
        // Tear down previous completion setups.


        // Early return if anything missing.


        // Setup fixed stuff: the popover, list view, etc.
        if (this.completion_popover == null) {
            this.completion_popover = new Gtk.Popover();
            this.completion_popover.halign = START;
            this.completion_popover.position = BOTTOM;
            this.completion_popover.has_arrow = false;
            this.completion_popover.autohide = false;
            this.completion_popover.width_request = 400;
            this.completion_popover.height_request = 300;
            this.completion_popover.set_parent(this);

            var scrolled_window = new Gtk.ScrolledWindow();
            scrolled_window.hexpand = true;
            scrolled_window.vexpand = true;
            this.completion_popover.child = scrolled_window;

            this.completion_list_view = new Gtk.ListView(null, null);
            this.completion_list_view.tab_behavior = ITEM;
            this.completion_list_view.add_css_class("data-table");
            scrolled_window.child = this.completion_list_view;
        }

        // Bind new models and factories.
        Brk.SearchModel search_model;
        // TODO construct from completion factory if not search model.
        search_model = (Brk.SearchModel) this.completion_model;

        this.bind_property("text", search_model, "search", SYNC_CREATE);

        this.completion_search_model = search_model;
        this.completion_selection_model.model = (GLib.ListModel) search_model;

        this.completion_list_view.model = this.completion_selection_model;
        this.completion_list_view.factory = this.completion_factory;
    }

    private void
    completion_clear() {
        this.completion_search_model.search = "";
        this.completion_popover.popdown();
    }

    private void
    completion_accept() {
        // If selection:  use it.

        // Otherwise use common prefix.

        // Close the popover.

        // Activate (if configured)
    }

    private void
    completion_init() {
        this.notify["completion-model"].connect(this.completion_rebuild);
        this.notify["completion-factory"].connect(this.completion_rebuild);
        this.notify["completion-expression"].connect(this.completion_rebuild);

        var buffer_controller = new Gtk.EventControllerBuffer();
        buffer_controller.propagation_phase = CAPTURE;
        buffer_controller.discarded.connect(() => {
            // Queued commands are effectively the same as buffered input.
            // If we lose the input buffer then commands should also be dropped.
            this.completion_clear();
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
                    buffer_controller.discard();
                    return true;
                }
                return false;
            })
        ));

        this.add_controller(cancel_controller);
        this.add_controller(buffer_controller);

        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.notify["contains-focus"].connect(() => {
            if (!this.completion_popover.contains_focus) {
                return;
            }

            if (!this.completion_search_model.loading) {
                return;
            }

            buffer_controller.enable();
        });
        this.completion_popover.add_controller(focus_controller);

        this.text_input.activate.connect(() => {
            return_if_fail(!this.submit);  // Should be caught by buffer.
            if (this.loading) {
                this.completion_submit = true;
                buffer_controller.enable();
            } else {
                this.completion_accept();
                buffer_controller.replay();
            }


        });

        this.notify["loading"].connect((_, pspec) => {
            if (!this.loading) {
                if (this.completion_submitted) {
                    this.completion_accept();
                }
                buffer_controller.replay();
            }
        });

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


    /* === Text Entry ======================================================= */

    [GtkChild]
    private unowned Gtk.Text text_input;

    public unowned Gtk.Widget get_delegate() {
        return this.text_input;
    }

    public bool grab_focus_without_selecting() {
        return this.text_input.grab_focus_without_selecting();
    }

    private void
    text_input_init() {
        this.bind_property("text", this.text_input, "text", SYNC_CREATE | BIDIRECTIONAL);
    }


    /* === Popover ========================================================== */

    [GtkChild]
    private unowned Gtk.Popover popover;

    [GtkChild]
    private unowned Gtk.ListView list_view;

    public signal void file_activated(GLib.FileInfo fileinfo);

    private void
    popover_init() {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;

            var box = new Gtk.Box(HORIZONTAL, 6);
            box.append(new Brk.FileThumbnail());

            var label = new Gtk.Label("");
            label.halign = START;
            box.append(label);

            listitem.child = box;
        });
        factory.bind.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            var box = (Gtk.Box) listitem.child;
            var thumbnail = (Brk.FileThumbnail) box.get_first_child();
            var label = (Gtk.Label) box.get_last_child();
            var fileinfo = (GLib.FileInfo) listitem.item;

            thumbnail.fileinfo = fileinfo;
            label.set_markup(fileinfo.get_attribute_string("bricks::markup"));
        });
        this.list_view.factory = factory;
        this.list_view.model = this.selection_model;

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
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("entry");
    }

    construct {
        this.completion_init();
        this.text_input_init();
        this.popover_init();
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.QuickOpenEntry));
        base.dispose();
    }
}
