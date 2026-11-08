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

    public string? search { get; set; default = null; }

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
     * Determines whether a preview of the selected completion should be show
     * inline in the text box while typing.
     *
     * In COMPLETE mode, when nothing is selected, this will also determine
     * whether to show the common prefix of all possible completions.
     */
    public bool completion_inline { get; set; default = false; }

    /**
     * Triggered when a user accepts a completion.  This can be used to match
     * the behaviour of browser address bars where selecting a completion
     * immediately submits.  Typically used with SELECT mode.
     */
    public signal void completion_activate(GLib.Object selected);

    /**
     * Triggered when a user explicitly dismisses the completion by hitting the
     * escape key.
     */
    public signal void completion_dismiss();

    public bool completion_loading { get; private set; default = false; }

    /* --- Completion Search State ------------------------------------------ */

    // Model specific completion state.  Invalidated whenever one of the
    // completion properties changes.
    private bool completion_needs_rebuild = false;
    private Brk.SearchModel completion_search_model;
    private ulong completion_search_loading_handler = 0;

    private string
    completion_item_text(GLib.Object item) {
        var expression = this.completion_expression;
        if (expression == null) {
            expression = new Gtk.PropertyExpression(typeof(Gtk.StringObject), null, "string");
        }
        var text_value = GLib.Value(typeof(string));
        text_value.unset();  // only way to create uninitialised Value in vala...
        expression.evaluate(item, ref text_value);
        return text_value.get_string() ?? "";
    }

    private void
    completion_update_search() {
        if (this.completion_search_model == null) {
            return;
        }
        var text = this.text_input.text;
        if (text.char_count() >= this.completion_minimum_key_length) {
            this.completion_search_model.search = text;
        } else {
            this.completion_search_model.search = null;
        }
    }

    private void
    completion_rebuild_state() {
        this.completion_inline_reset();

        // Tear down previous completion setups.
        if (this.completion_popover != null) {
            this.completion_selection_model.model = null;
        }
        if (this.completion_search_model != null) {
            this.completion_search_model.search = null;
        }
        if (this.completion_search_loading_handler != 0) {
            GLib.SignalHandler.disconnect(this.completion_search_model, this.completion_search_loading_handler);
            this.completion_search_loading_handler = 0;
        }
        this.completion_search_model = null;
        this.completion_loading = false;

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
        if (this.completion_search_model is Brk.AsyncSearchModel) {
            var async_search_model = (Brk.AsyncSearchModel) this.completion_search_model;
            this.completion_search_loading_handler = async_search_model.notify["loading"].connect(() => {
                this.completion_loading = async_search_model.loading;
            });
        }

        this.completion_update_search();
        this.completion_selection_model.model = this.completion_search_model;

        if (this.completion_search_model is Brk.AsyncSearchModel) {
            this.completion_loading = ((Brk.AsyncSearchModel) this.completion_search_model).loading;
        }

        // SELECT completion mode requires a selection.  COMPLETE just provides
        // the option to complete.
        this.completion_selection_model.autoselect = this.completion_mode == SELECT;
        this.completion_selection_model.can_unselect = this.completion_mode != SELECT;

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
                label.label = this.completion_item_text(listitem.item);
            });
            this.completion_list_view.factory = factory;
        }
    }

    private void
    completion_dispose_state() {
        if (this.completion_search_loading_handler != 0) {
            GLib.SignalHandler.disconnect(this.completion_search_model, this.completion_search_loading_handler);
            this.completion_search_loading_handler = 0;
        }
    }

    /* --- Completion View State -------------------------------------------- */

    // Common completion state.  Scoped from the first point at which the search
    // model becomes valid to dispose.
    private Gtk.Popover? completion_popover;
    private Gtk.ListView? completion_list_view;
    private Gtk.SingleSelection? completion_selection_model;
    private Gtk.EventControllerFocus? completion_focus_controller;

    private void
    completion_resize_popover() {
        this.completion_popover.set_size_request(this.get_width(), -1);
    }

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
            autohide = false
        };
        this.completion_popover.set_parent(this);

        // Initialise scrolled window.
        var scrolled_window = new Gtk.ScrolledWindow() {
            hexpand = true,
            vexpand = true,
            propagate_natural_height = true,
            max_content_height = 300
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
                this.completion_selection_model.get_n_items() > 0
            ) {
                this.completion_resize_popover();
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
                this.completion_inline_accept();
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

    /* --- Inline Completion ------------------------------------------------ */

    private bool completion_inline_pending = false;
    private bool completion_updating_text = false;
    private bool completion_inline_editing = false;
    private string? completion_inline_prefix = null;
    private uint completion_inline_idle = 0;

    private string?
    completion_inline_candidate(string typed) {
        var selection = this.completion_selection_model.selected_item;
        if (selection != null) {
            return this.completion_item_text(selection);
        }
        if (this.completion_mode != COMPLETE) {
            return null;
        }

        string? prefix = null;
        var n_items = this.completion_selection_model.get_n_items();
        for (uint i = 0; i < n_items; i++) {
            var text = this.completion_item_text(this.completion_selection_model.get_item(i));
            if (!text.has_prefix(typed)) {
                continue;
            }
            if (prefix == null) {
                prefix = text;
                continue;
            }
            int length = 0;
            while (length < prefix.length && length < text.length && prefix[length] == text[length]) {
                length++;
            }
            while (length > 0 && length < prefix.length && ((uint8) prefix[length] & 0xC0) == 0x80) {
                length--;
            }
            prefix = prefix.substring(0, length);
        }
        return prefix;
    }

    private void
    completion_inline_update() {
        if (!this.completion_inline || this.completion_selection_model == null) {
            return;
        }
        // Results may still be from the previous search.  Leave any pending
        // completion for when loading finishes.
        if (this.completion_loading) {
            return;
        }

        string typed;
        if (this.completion_inline_prefix != null) {
            typed = this.completion_inline_prefix;
            if (!this.text_input.text.has_prefix(typed)) {
                this.completion_inline_reset();
                return;
            }
        } else if (this.completion_inline_pending) {
            typed = this.text_input.text;
            int start, end;
            if (
                this.text_input.get_selection_bounds(out start, out end) ||
                this.text_input.cursor_position != typed.char_count()
            ) {
                this.completion_inline_pending = false;
                return;
            }
        } else {
            return;
        }

        var completion = this.completion_inline_candidate(typed);
        if (completion == null || completion.length <= typed.length || !completion.has_prefix(typed)) {
            completion = typed;
        }
        if (completion == this.text_input.text) {
            return;
        }

        var typed_length = typed.char_count();
        this.completion_updating_text = true;
        if (this.completion_inline_prefix != null) {
            this.text_input.do_delete_text(typed_length, -1);
        }
        if (completion != typed) {
            var position = typed_length;
            this.text_input.do_insert_text(completion.substring(typed.length), -1, ref position);
            this.text_input.select_region(typed_length, -1);
            this.completion_inline_prefix = typed;
            this.completion_inline_pending = false;
        } else {
            // The previous suggestion no longer applies.  Keep waiting in case
            // a later result does.
            this.completion_inline_prefix = null;
            this.completion_inline_pending = true;
        }
        this.completion_updating_text = false;
    }

    private void
    completion_inline_accept() {
        if (this.completion_inline_prefix == null) {
            return;
        }
        this.completion_inline_reset();
        this.text_input.set_position(-1);
    }

    private void
    completion_inline_reset() {
        this.completion_inline_prefix = null;
        this.completion_inline_pending = false;
    }

    private void
    completion_inline_cursor_moved() {
        if (this.completion_updating_text) {
            return;
        }
        this.completion_inline_prefix = null;
        if (this.text_input.cursor_position != this.text_input.text.char_count()) {
            this.completion_inline_pending = false;
        }
    }

    private void
    completion_inline_queue() {
        if (this.completion_inline_idle != 0) {
            return;
        }
        // Gtk.Text sets the cursor position after inserting text, so changes
        // made synchronously from inside the insertion would be clobbered.
        this.completion_inline_idle = GLib.Idle.add(() => {
            this.completion_inline_idle = 0;
            this.completion_inline_editing = false;
            this.completion_inline_update();
            return GLib.Source.REMOVE;
        }, GLib.Priority.HIGH);
    }

    // Applies any queued inline completion immediately, unless that would
    // happen inside an insertion, in which case it is left to the idle.
    private void
    completion_inline_flush() {
        if (this.completion_inline_editing) {
            return;
        }
        if (this.completion_inline_idle != 0) {
            GLib.Source.remove(this.completion_inline_idle);
            this.completion_inline_idle = 0;
        }
        this.completion_inline_update();
    }

    private void
    completion_init_inline() {
        this.text_input.insert_text.connect(() => {
            if (this.completion_updating_text) {
                return;
            }
            if (!this.completion_inline) {
                return;
            }
            // Cleared by the idle, as Gtk.Text keeps updating the cursor after
            // the insert-text signal has returned.
            this.completion_inline_editing = true;
        });
        this.text_input.insert_text.connect_after(() => {
            if (this.completion_updating_text) {
                return;
            }
            if (!this.completion_inline) {
                return;
            }
            this.completion_inline_pending = true;
            this.completion_inline_queue();
        });
        this.text_input.delete_text.connect(() => {
            if (this.completion_updating_text) {
                return;
            }
            this.completion_inline_reset();
        });
        this.text_input.notify["cursor-position"].connect(this.completion_inline_cursor_moved);
        this.text_input.notify["selection-bound"].connect(this.completion_inline_cursor_moved);
        this.completion_selection_model.items_changed.connect(this.completion_inline_queue);
        this.completion_selection_model.notify["selected"].connect(this.completion_inline_queue);
    }

    private void
    completion_dispose_inline() {
        if (this.completion_inline_idle != 0) {
            GLib.Source.remove(this.completion_inline_idle);
            this.completion_inline_idle = 0;
        }
        this.completion_inline_editing = false;
        this.completion_inline_reset();
    }

    /* --- Completion Keyboard Interaction ---------------------------------- */

    private void
    completion_init_keyboard() {
        // ... Capture Phase ...
        var buffer_controller = new Gtk.EventControllerBuffer();
        buffer_controller.propagation_phase = CAPTURE;

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
                    this.completion_search_model.search = null;
                    this.completion_dismiss();
                    return true;
                }
                return false;
            })
        ));

        // Identifies keys that can't be handled during loading and queues them
        // to be sent again when loading finishes later.
        var capture_controller = new Gtk.ShortcutController();
        capture_controller.propagation_phase = CAPTURE;
        capture_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Up|Down|Return"),
            new Gtk.CallbackAction(() => {
                if (!this.completion_loading) {
                    return false;
                }
                buffer_controller.enable_from(capture_controller.get_current_event());
                return true;
            })
        ));

        // The order here is important.  The cancel controller must be able to
        // intercept events before they are buffered.  The capture controller
        // must not receive events while buffering is enabled.
        this.text_input.add_controller(capture_controller);
        this.text_input.add_controller(buffer_controller);
        this.text_input.add_controller(cancel_controller);

        this.notify["completion-loading"].connect((_, pspec) => {
            if (!this.completion_loading) {
                // Replayed keys, in particular Return, must see the inline
                // completion derived from the final results.
                this.completion_inline_flush();
                buffer_controller.replay();
            }
        });
        this.text_input.notify["text"].connect((fe, pspec) => {
            // Buffered keyboard events will have happened before whatever
            // changed the entry (for example, a careful middle click paste)
            // and so can't be replayed after.
            if (!this.completion_updating_text) {
                buffer_controller.discard();
            }
        });
        this.text_input.notify["cursor-position"].connect((_, pspec) => {
            // Likewise, replaying events after moving the cursor would cause
            // text to be entered in the wrong place.
            if (!this.completion_updating_text) {
                buffer_controller.discard();
            }
        });

        // ... Bubble Phase ...
        var shortcut_controller = new Gtk.ShortcutController();
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Up"),
            new Gtk.CallbackAction(() => {
                var selection_model = this.completion_selection_model;
                if (selection_model.selected > 0) {
                    selection_model.selected -= 1;
                }
                return true;
            })
        ));
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Down"),
            new Gtk.CallbackAction(() => {
                var selection_model = this.completion_selection_model;
                if (selection_model.selected + 1 < selection_model.get_n_items()) {
                    selection_model.selected += 1;
                }
                return true;
            })
        ));
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Escape"),
            new Gtk.CallbackAction(() => {
                if (this.completion_search_model?.search != null) {
                    this.completion_search_model.search = null;
                    this.completion_dismiss();
                    return true;
                }
                return false;
            })
        ));
        this.text_input.add_controller(shortcut_controller);

        this.text_input.notify["text"].connect((fe, pspec) => {
            if (!this.completion_updating_text) {
                this.completion_update_search();
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

    private bool
    completion_accept() {
        if (this.completion_popover == null) {
            return false;
        }
        if (!this.completion_popover.visible) {
            return false;
        }

        var selection = this.completion_selection_model.selected_item;
        if (selection == null) {
            // TODO use common prefix.
            this.completion_popover.popdown();
            return false;
        }

        this.completion_updating_text = true;
        this.text = this.completion_item_text(selection);
        this.text_input.set_position(-1);
        this.completion_updating_text = false;
        this.completion_inline_reset();

        this.completion_popover.popdown();

        this.completion_activate(selection);
        return true;
    }

    /* --- Completion Lifecycle --------------------------------------------- */

    private void
    completion_invalidate() {
        if (this.completion_model != null && this.completion_popover == null) {
            this.completion_init_view();
            this.completion_init_keyboard();
            this.completion_init_inline();
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
        this.completion_dispose_inline();
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

    /**
     * Emitted when the entry is activated.
     *
     * The keybindings for this signal are all forms of the Enter key.
     */
    public new signal void activate();

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
        this.text_input.activate.connect(() => {
            if (!this.completion_accept()) {
                this.completion_inline_accept();
                this.activate();
            }
        });
        this.text_input.set_parent(this);
    }

    private void
    text_input_dispose() {
        this.text_input?.unparent();
        this.text_input = null;
    }

    /* === Layout =========================================================== */

    public override void
    measure(
        Gtk.Orientation orientation, int for_size,
        out int minimum, out int natural,
        out int minimum_baseline, out int natural_baseline
    ) {
        this.text_input.measure(
            orientation, for_size,
            out minimum, out natural,
            out minimum_baseline, out natural_baseline
        );
    }

    public override void
    size_allocate(int width, int height, int baseline) {
        var valign = this.get_valign();
        if (valign != BASELINE_FILL && valign != BASELINE_CENTER) {
            baseline = -1;
        }

        this.text_input.allocate(width, height, baseline, null);

        if (this.completion_popover != null) {
            this.completion_resize_popover();
            this.completion_popover.present();
        }
    }

    /* === Lifecycle ======================================================== */

    class construct {
        set_css_name("entry");
    }

    static construct {
        set_activate_signal_from_name("activate");
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
