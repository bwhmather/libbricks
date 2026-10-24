/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

private sealed class Brk.StaticSearchModel : GLib.Object, GLib.ListModel, Brk.SearchModel {
    private Gtk.FilterListModel filter_list_model;

    public GLib.ListModel model { get; construct set; }

    /**
     * The expression to evaluate on each item to get a string to compare with.
     */
    public Gtk.Expression? expression { get; construct set; default = null; }
    public bool ignore_case { get; construct set; default = true; }

    /* === Search Model Interface =========================================== */

    public string search { get; set; }
    public bool loading { get { return false; } }

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

    construct {
        var filter = new Gtk.StringFilter(null);
        filter.match_mode = PREFIX;
        this.bind_property("expression", filter, "expression", SYNC_CREATE);
        this.bind_property("ignore-case", filter, "ignore-case", SYNC_CREATE);
        this.bind_property("search", filter, "search", SYNC_CREATE);

        this.filter_list_model = new Gtk.FilterListModel(null, filter);
        this.bind_property("model", this.filter_list_model, "model", SYNC_CREATE);
        this.filter_list_model.items_changed.connect((position, removed, added) => {
            this.items_changed(position, removed, added);
        });
    }
}

public sealed class Brk.Entry : Gtk.Widget {

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
     * Triggered when a user accepts a completion.  This can be used to match
     * the behaviour of browser address bars where selecting a completion
     * immediately submits.
     */
    public signal void completion_activate(GLib.Object);

    private Brk.SearchModel completion_search_model;
    private Gtk.SingleSelection completion_selection_model;

    private Gtk.Popover completion_popover;
    private Gtk.ListView completion_list_view;

    private void
    completion_rebuild() {
        // Tear down previous completion setups.


        // Early return if anything missing.
        if (this.completion_model == null) {
            return;
        }


        // Setup fixed stuff: the popover, list view, etc.
        if (this.completion_popover == null) {
            this.completion_popover = new Gtk.Popover() {
                halign = START,
                position = BOTTOM,
                has_arrow = false,
                autohide = false,
                width_request = 400,
                height_request = 300
            };
            this.completion_popover.set_parent(this);

            var scrolled_window = new Gtk.ScrolledWindow() {
                hexpand = true,
                vexpand = true
            };
            this.completion_popover.child = scrolled_window;

            this.completion_list_view = new Gtk.ListView(null, null) {
                tab_behavior = ITEM,
            };
            this.completion_list_view.add_css_class("data-table");
            scrolled_window.child = this.completion_list_view;
        }

        // Bind new models and factories.
        var expression = this.completion_expression;
        if (expression == null) {
            expression = new Gtk.PropertyExpression(typeof(Gtk.StringObject), null, "string");
        }

        if (this.completion_model is Brk.SearchModel) {
            this.completion_search_model = (Brk.SearchModel) this.completion_model;
        } else {
            var search_model = new Brk.StaticSearchModel();
            search_model.model = this.completion_model;
            search_model.expression = expression;
            this.completion_search_model = search_model;
        }

        this.bind_property("text", this.completion_search_model, "search", SYNC_CREATE);
        this.completion_search_model.items_changed.connect(() => {
            if (this.completion_search_model.get_n_items() > 0) {
                this.completion_popover.popup();
            } else {
                this.completion_popover.popdown();
            }
        });

        this.completion_selection_model = new Gtk.SingleSelection(this.completion_search_model);

        this.completion_list_view.model = this.completion_selection_model;
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
    completion_show() {
        this.completion_rebuild();
        this.completion_popover.popup();
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
    completion_invalidate() {
        this.completion_rebuild();
    }

    private void
    completion_init() {
        this.notify["completion-model"].connect(this.completion_invalidate);
        this.notify["completion-factory"].connect(this.completion_invalidate);
        this.notify["completion-expression"].connect(this.completion_invalidate);

        var focus_controller = new Gtk.EventControllerFocus();
        focus_controller.notify["contains-focus"].connect(() => {
            if (!focus_controller.contains_focus) {
            }
        });
        this.add_controller(focus_controller);
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
        this.dispose_template(typeof(Brk.QuickOpenEntry));
        base.dispose();
    }
}
