/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

public enum Brk.EntryCompletionMode {
    /**
     * The entry acts in plain completion mode.
     *
     * Completions are hints that can be used to populate the text box   Inline
     * completion uses the common prefix of all currently possible completions
     * and no completion is highlighted by default.
     */
    COMPLETE,

    /**
     * The entry acts more as a search box, combo box, or quick open menu.
     *
     * Completions are the possible values for the text.  One is always selected
     * and is activated on enter.  Inline completion uses the selected completion
     * rather than the common prefix.
     */
    SELECT
}

private sealed class Brk.StaticSearchModel : GLib.Object, GLib.ListModel, Brk.SearchModel {
    private Gtk.StringFilter filter;
    private Gtk.FilterListModel filter_list_model;

    public GLib.ListModel model { get; construct set; }

    /**
     * The expression to evaluate on each item to get a string to compare with.
     */
    public Gtk.Expression? expression { get; construct set; default = null; }

    /* === Search Model Interface =========================================== */

    public string? search { get; set; default = ""; }

    /* === List Model Interface ============================================= */

    public GLib.Object?
    get_item(uint position) {
        return this.filter_list_model.get_item(position);
    }

    public GLib.Type
    get_item_type() {
        return this.filter_list_model.get_item_type();
    }

    public uint
    get_n_items() {
        return this.filter_list_model.get_n_items();
    }

    /* === Lifecycle ======================================================== */

    private void
    update_filter() {
        if (search != null) {
            this.filter.expression = this.expression;
            this.filter.search = this.search;
            this.filter_list_model.model = this.model;
        } else {
            this.filter_list_model.model = null;
        }
    }

    construct {
        this.filter = new Gtk.StringFilter(null) {
            match_mode = PREFIX,
        };

        this.filter_list_model = new Gtk.FilterListModel(null, filter);
        this.filter_list_model.items_changed.connect((position, removed, added) => {
            this.items_changed(position, removed, added);
        });

        this.notify.connect(this.update_filter);
        this.update_filter();
    }
}

public sealed class Brk.Entry : Gtk.Widget {

    /* === Completion ======================================================= */

    /**
     * An optional list model containing possible values for the entry.
     *
     * Need not be exhaustive.
     *
     * If set to a Brk.SearchModel instance then will be passed the current
     * query.
     */
    public GLib.ListModel? completion_model { get; set; }

    /**
     * Used to construct rows to appear in the completion popover.
     */
    public Gtk.ListItemFactory? completion_factory { get; set; }

    /**
     * Used to convert completions to text for filtering (if completion_model is
     * not a Brk.SearchModel) finding common prefixes, replacing the entry text
     * if a completion is selected.
     */
    public Gtk.Expression? completion_expression { get; set; }

    /**
     * When text is shorter than this length, no completions will be shown.  Set
     * to zero to show all possible completions immediately on focus in.
     */
    public int completion_minimum_key_length { get; set; default = 1; }

    /**
     */
    public Brk.EntryCompletionMode completion_mode { get; set; default = COMPLETE; }

    /**
     * Determines whether a preview of the completion should be show inline in
     * the text box while typing.
     *
     * In COMPLETE mode this will be the common prefix of all possible
     * completions.  In SELECT mode it will be the rest of the completion that
     * is currently highlighted.
     */
    public bool completion_inline { get; set; default = false; }

    /**
     * Triggered when a user accepts a completion.  This can be used to match
     * the behaviour of browser address bars where selecting a completion
     * immediately submits.  Typically used with SELECT mode.
     */
    public signal void completion_activate(GLib.Object selected);

    public bool completion_loading { get; private set; default = false; }

    /* --- Completion Search State ------------------------------------------ */

    // Model specific completion state.  Invalidated whenever one of the
    // completion properties changes.
    private bool completion_needs_rebuild = false;
    private Brk.SearchModel completion_search_model;
    private GLib.Binding? completion_search_binding;

    private void
    completion_rebuild_state() {
        // Tear down previous completion setups.
        if (this.completion_popover != null) {
            this.completion_selection_model.model = null;
        }
        this.completion_search_model = null;
        this.completion_search_binding?.unbind();
        this.completion_search_binding = null;

        // Early return if anything missing.
        if (this.completion_model == null) {
            return;
        }

        // Initialise expression,
        var expression = this.completion_expression;
        if (expression == null) {
            expression = new Gtk.PropertyExpression(typeof(Gtk.StringObject), null, "string");
        }

        if (this.completion_model is Brk.SearchModel) {
            this.completion_search_model = (Brk.SearchModel) this.completion_model;
        } else {
            this.completion_search_model = new StaticSearchModel() {
                model = this.completion_model,
                expression = expression
            };
        }
        this.completion_selection_model.model = this.completion_search_model;

        // Initialise list item factory.
        if (this.completion_factory != null) {
            this.completion_list_view.factory = this.completion_factory;
        } else {
            var factory = new Gtk.SignalListItemFactory();
            factory.setup.connect((listitem_) => {
                var listitem = (Gtk.ListItem) listitem_;

                var label = new Gtk.Label("");
                label.halign = START;

                listitem.child = label;
            });
            factory.bind.connect((listitem_) => {
                var listitem = (Gtk.ListItem) listitem_;
                var label = (Gtk.Label) listitem.child;
                GLib.Value val = GLib.Value(typeof(string));
                expression.evaluate(listitem.item, ref val);
                label.label = val.get_string();
            });
            this.completion_list_view.factory = factory;
        }
    }

    private void
    completion_dispose_state() {
        this.completion_search_binding?.unbind();
        this.completion_search_binding = null;
    }

    /* --- Completion View State -------------------------------------------- */

    // Common completion state.  Scoped from the first point at which the search
    // model becomes valid to dispose.
    private Gtk.Popover? completion_popover;
    private Gtk.ListView? completion_list_view;
    private Gtk.SingleSelection? completion_selection_model;
    private Gtk.EventControllerFocus? completion_focus_controller;

    private void
    completion_init_view() {
        if (this.completion_popover != null) {
            return;
        }

        // Initialise popover.
        this.completion_popover = new Gtk.Popover() {
            halign = START,
            position = BOTTOM,
            has_arrow = false,
            autohide = false,
            width_request = 400,
            height_request = 300
        };
        this.completion_popover.set_parent(this);

        // Initialise scrolled window.
        var scrolled_window = new Gtk.ScrolledWindow() {
            hexpand = true,
            vexpand = true
        };
        this.completion_popover.child = scrolled_window;

        // Initialise ist view.
        this.completion_list_view = new Gtk.ListView(null, null) {
            tab_behavior = ITEM,
        };
        this.completion_list_view.add_css_class("data-table");
        scrolled_window.child = this.completion_list_view;

        // Initialise selection model.
        this.completion_selection_model = new Gtk.SingleSelection(null) {
            autoselect = false,
            can_unselect = true
        };
        this.completion_selection_model.items_changed.connect(() => {
            if (
                this.completion_focus_controller.contains_focus &&
                this.text.length > 0 &&
                this.completion_selection_model.get_n_items() > 0
            ) {
                this.completion_popover.popup();
            } else {
                this.completion_clear();
            }
        });
        this.completion_list_view.model = this.completion_selection_model;

        // Initialise focus controller.
        this.completion_focus_controller = new Gtk.EventControllerFocus();
        this.completion_focus_controller.notify["contains-focus"].connect(() => {
            if (!this.completion_focus_controller.contains_focus) {
                this.completion_clear();
            }
        });
        this.add_controller(this.completion_focus_controller);
    }

    private void
    completion_dispose_view() {
        if (completion_popover != null) {
            this.remove_controller(this.completion_focus_controller);
            this.completion_focus_controller = null;
            this.completion_list_view = null;
            this.completion_selection_model = null;
            this.completion_popover.unparent();
            this.completion_popover = null;
        }
    }

    /* --- Completion Keyboard Interaction ---------------------------------- */

    // Keyboard input on the text entry can be handled asnychronously if the
    // view is still catching up.  Navigation (using up and down keys  before
    // the entry is submitted is buffered manually here.  Everything after the
    // entry is submitted is buffered using a Gtk.EventControllerBuffer.  Input
    // anywhere else is handled synchronously and ignores these two mechanisms.
    private int[] completion_navigate = null;
    private bool completion_submit = false;

    private void
    completion_clear_commands() {
        this.completion_navigate = null;
        this.completion_submit = false;
    }

    private void
    completion_play_commands() {
        return_if_fail(!this.completion_loading);

        foreach (int step in this.completion_navigate) {
            var selection_model = this.completion_selection_model;
            while (step < 0) {
                if (selection_model.selected > 0) {
                    selection_model.selected -= 1;
                }
                step += 1;
            }
            while (step > 0) {
                if (selection_model.selected + 1 < selection_model.get_n_items()) {
                    selection_model.selected += 1;
                }
                step -= 1;
            }
        }
        if (this.completion_submit) {
            this.completion_accept();
        }

        this.completion_navigate = null;
        this.completion_submit = false;
    }

    private void
    completion_init_keyboard() {
        var buffer_controller = new Gtk.EventControllerBuffer();
        buffer_controller.propagation_phase = CAPTURE;
        buffer_controller.discarded.connect(() => {
            // Queued commands are effectively the same as buffered input.
            // If we lose the input buffer then commands should also be dropped.
            this.completion_clear_commands();
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
                    this.completion_search_model.search = null;
                    return true;
                }
                return false;
            })
        ));

        var shortcut_controller = new Gtk.ShortcutController();
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Up"),
            new Gtk.CallbackAction(() => {
                return_val_if_fail(!this.completion_submit, false);  // Should be caught by buffer.
                this.completion_navigate += -1;
                if (!this.completion_loading) {
                    this.completion_play_commands();
                }
                return true;
            })
        ));
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Down"),
            new Gtk.CallbackAction(() => {
                return_val_if_fail(!this.completion_submit, false);  // Should be caught by buffer.
                this.completion_navigate += 1;
                if (!this.completion_loading) {
                    this.completion_play_commands();
                }
                return true;
            })
        ));
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Escape"),
            new Gtk.CallbackAction(() => {
                if (this.completion_search_model?.search != null) {
                    this.completion_search_model.search = null;
                    return true;
                }
                return false;
            })
        ));

        // The order here is important.  The cancel controller must be able to
        // intercept events before they are buffered.  The shortcut controller
        // must not receive events until after they are released.
        this.text_input.add_controller(cancel_controller);
        this.text_input.add_controller(buffer_controller);
        this.text_input.add_controller(shortcut_controller);

        this.notify["completion-loading"].connect((_, pspec) => {
            if (!this.completion_loading) {
                this.completion_play_commands();
                buffer_controller.replay();
            }
        });

        this.text_input.activate.connect(() => {
            return_if_fail(!this.completion_submit);  // Should be caught by buffer.
            this.completion_submit = true;
            if (this.completion_loading) {
                buffer_controller.enable();
            } else {
                this.completion_play_commands();
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

        this.text_input.notify["text"].connect((fe, pspec) => {
            if (this.completion_search_model == null) {
                return;
            }
            var text = text_input.text;
            if (text.length >= this.completion_minimum_key_length) {
                this.completion_search_model.search = text;
            } else {
                this.completion_search_model.search = null;
            }
        });
    }

    private void
    completion_dispose_keyboard() {

    }

    private void
    completion_clear() {
        this.completion_popover.popdown();
    }

    private void
    completion_accept() {
        // If selection:  use it.

        // Otherwise use common prefix.

        // Close the popover.

        // Activate (if configured)
    }

    /* --- Completion Lifecycle --------------------------------------------- */

    private void
    completion_invalidate() {
        if (this.completion_model != null && this.completion_popover == null) {
            this.completion_init_view();
            this.completion_init_keyboard();
        }

        // Defer until first map so that properties set during construction
        // result in a single rebuild.
        if (this.get_mapped()) {
            this.completion_rebuild_state();
            this.completion_needs_rebuild = false;
        } else {
            this.completion_needs_rebuild = true;
        }
    }


    private void
    completion_init() {
        this.notify["completion-model"].connect(this.completion_invalidate);
        this.notify["completion-factory"].connect(this.completion_invalidate);
        this.notify["completion-expression"].connect(this.completion_invalidate);
        this.notify["completion-minimum-key-length"].connect(this.completion_invalidate);
        this.notify["completion-mode"].connect(this.completion_invalidate);
        this.notify["completion-inline"].connect(this.completion_invalidate);

        this.map.connect(() => {
            if (this.completion_needs_rebuild) {
                this.completion_rebuild_state();
                this.completion_needs_rebuild = false;
            }
        });
    }

    private void
    completion_dispose() {
        this.completion_needs_rebuild = false;
        this.completion_dispose_state();
        this.completion_dispose_keyboard();
        this.completion_dispose_view();
    }

    /* === Text Entry ======================================================= */

    private Gtk.Text text_input;


    /**
     * Retrieves the selection bound of the editable.
     *
     * `start_pos` will be filled with the start of the selection and `end_pos`
     * with the end.  If no text was selected both will be identical and FALSE
     * will be returned.
     *
     * Note that positions are specified in characters, not bytes.
     *
     * @param(start_pos) Location to store the starting position.
     * @param(end_pos) Location to store the end position.
     * @returns TRUE if there is a non-empty selection, FALSE otherwise.
     */
    public bool
    get_selection_bounds(out int start, out int end) {
        return this.text_input.get_selection_bounds(out start, out end);
    }

    /**
     * Selects a region of text.
     *
     * The characters that are selected are those characters at positions from
     * `start_pos` up to, but not including `end_pos`.  If `end_pos` is negative
     * then the characters selected are those characters from `start_pos` to the
     * end of the text.
     *
     * Note that positions are specified in characters, not bytes.
     *
     * @param(start_pos) Start of region.
     * @param(end_pos) End of region.
     */
    public void
    select_region(int start, int end) {
        this.text_input.select_region(start, end);
    }

    /**
     * Gets the Gtk.Editable that the entry is delegating its implementation to.
     */
    public unowned Gtk.Editable?
    get_delegate() {
        return this.text_input;
    }

    /**
     * The contents of the entry.
     */
    public unowned string text {
        get { return this.text_input.text; }
        set { this.text_input.text = value; }
    }

    /**
     * The contents of the entry, including pseudo-content such as the preedit
     * buffer.
     */
    public string complete_text {
        owned get { return this.text_input.complete_text; }
    }

    /**
     * The current position of the insertion cursor in chars.
     */
    public int cursor_position {
        get { return this.text_input.cursor_position; }
    }

    /**
     * Whether the entry contents can be edited.
     */
    public bool editable {
        get { return this.text_input.editable; }
        set { this.text_input.editable = value; }
    }

    /**
     * If undo/redo should be enabled for the entry.
     */
    public bool enable_undo {
        get { return this.text_input.enable_undo; }
        set { this.text_input.enable_undo = value; }
    }

    /**
     * A widget to intercept key events from, so that textual input aimed at it
     * is handled by this entry instead.
     *
     * Only input that an input method would handle is intercepted.
     */
    public Gtk.Widget input_interceptor {
        owned get { return this.text_input.input_interceptor; }
        set { this.text_input.input_interceptor = value; }
    }

    /**
     * The desired maximum width of the entry, in characters.
     */
    public int max_width_chars {
        get { return this.text_input.max_width_chars; }
        set { this.text_input.max_width_chars = value; }
    }

    /**
     * The position of the opposite end of the selection from the cursor in chars.
     */
    public int selection_bound {
        get { return 0; } //this.text_input.selection_bound; }
    }

    /**
     * Number of characters to leave space for in the entry.
     */
    public int width_chars {
        get { return this.text_input.width_chars; }
        set { this.text_input.width_chars = value; }
    }

    /**
     * The horizontal alignment, from 0 (left) to 1 (right).
     *
     * Reversed for RTL layouts.
     */
    public float xalign {
        get { return this.text_input.xalign; }
        set { this.text_input.xalign = value; }
    }

    /**
     * Causes the entry to have keyboard focus.
     *
     * It behaves like gtk_widget_grab_focus(), except that it does not select
     * the contents of self.
     *
     * You only want to call this on some special entries which the user usually
     * doesn't want to replace all text in, such as seach-as-you-type entries.
     *
     * @returns True if focus is now inside self.
     */
    public bool
    grab_focus_without_selecting() {
        return this.text_input.grab_focus_without_selecting();
    }

    private void
    text_input_init() {
        this.text_input = new Gtk.Text();
        this.text_input.notify["text"].connect(() => { this.notify_property("text"); });
        this.text_input.notify["complete-text"].connect(() => { this.notify_property("complete-text"); });
        this.text_input.notify["cursor-position"].connect(() => { this.notify_property("cursor-position"); });
        this.text_input.notify["editable"].connect(() => { this.notify_property("editable"); });
        this.text_input.notify["enable-undo"].connect(() => { this.notify_property("enable-undo"); });
        this.text_input.notify["input-interceptor"].connect(() => { this.notify_property("input-interceptor"); });
        this.text_input.notify["max-width-chars"].connect(() => { this.notify_property("max-width-chars"); });
        this.text_input.notify["selection-bound"].connect(() => { this.notify_property("selection-bound"); });
        this.text_input.notify["width-chars"].connect(() => { this.notify_property("width-chars"); });
        this.text_input.notify["xalign"].connect(() => { this.notify_property("xalign"); });
        this.text_input.set_parent(this);
    }

    private void
    text_input_dispose() {
        this.text_input?.unparent();
        this.text_input = null;
    }

    /* === Lifecycle ======================================================== */

    class construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("entry");
    }

    construct {
        this.text_input_init();
        this.completion_init();
    }

    public override void
    dispose() {
        this.completion_dispose();
        this.text_input_dispose();
        base.dispose();
    }
}
