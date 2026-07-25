/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

private unowned string
get_category_from_content_type(string content_type) {
    // List opied from gtkfilechooserwidget.c:get_category_from_content_type.
    // They copied it from src/nautilus_file.c:get_description().
    // Represented as switch statement because vala is awesome and does the
    // right thing.
    switch (GLib.ContentType.get_generic_icon_name(content_type)) {
    case "application-x-executable":
        return _("Program");
    case "audio-x-generic":
        return _("Audio");
    case "font-x-generic":
        return _("Font");
    case "image-x-generic":
        return _("Image");
    case "package-x-generic":
        return _("Archive");
    case "text-html":
        return _("Markup");
    case "text-x-generic":
        return _("Text");
    case "text-x-generic-template":
        return _("Text");
    case "text-x-script":
        return _("Program");
    case "video-x-generic":
        return _("Video");
    case "x-office-address-book":
        return _("Contacts");
    case "x-office-calendar":
        return _("Calendar");
    case "x-office-document":
        return _("Document");
    case "x-office-presentation":
        return _("Presentation");
    case "x-office-spreadsheet":
        return _("Spreadsheet");
    default:
        return _("Unknown");
    }
}

private enum Brk.FileDialogMode {
    OPEN,
    SAVE,
}

private enum Brk.FileDialogViewMode {
    LIST,
    ICON,
    TREE
}

private sealed class Brk.FileDialogSidebarRow : Gtk.ListBoxRow {
    public string label { get; construct; }
    public GLib.Icon icon { get; construct; }
    public GLib.File file { get; construct; }

    private Gtk.Image icon_widget;
    private Gtk.Label label_widget;

    class construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
    }

    construct {
        this.icon_widget = new Gtk.Image.from_gicon(this.icon);
        this.icon_widget.set_parent(this);

        this.label_widget = new Gtk.Label(this.label);
        this.label_widget.halign = START;
        this.label_widget.insert_after(this, this.icon_widget);
    }

    public Brk.FileDialogSidebarRow.for_file(string label, GLib.Icon icon, GLib.File file) {
        Object(label: label, icon: icon, file: file);
    }

    public override void
    dispose() {
        this.icon_widget.unparent();
        this.label_widget.unparent();
        base.dispose();
    }
}

private sealed class Brk.FileDialogState {
    public Brk.FileDialogViewMode view_mode;

    // Common to all views.
    public bool show_binary;
    public bool show_hidden;

    public GLib.File root_directory;

    // Tree view specific.
    // Sorted list of expanded directories under the current mount.
    public string[] expanded;

    // List view specific.
    public string[] sort_columns;
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-file-dialog.ui")]
private sealed class Brk.FileDialogWindow : Gtk.Window {
    // Path to root folder under mount.

    public GLib.File root_directory { get; set; }
    public Gtk.DirectoryList directory_list;

    public signal void open(GLib.File result);

    public GLib.ListModel selection { get; set; default=new GLib.ListStore(typeof (GLib.FileInfo)); }
    public bool select_multiple { get; set; }

    public GLib.SimpleActionGroup dialog_actions = new GLib.SimpleActionGroup();

    public Brk.FileDialogMode mode { get; set; default = OPEN; }

    /* === Views ============================================================ */

    [GtkChild]
    private unowned Brk.ToolbarView toolbar_view;

    [GtkChild]
    private unowned Brk.FileDialogPathBar path_bar;

    [GtkChild]
    private unowned Brk.ButtonGroup view_button_group;

    [GtkChild]
    private unowned Gtk.Stack view_stack;

    public Brk.FileDialogViewMode view_mode { get; set; default = LIST; }

    public bool show_binary { get; set; }
    public bool show_hidden { get; set; }

    private void
    toolbar_update_visibility() {
        this.quick_open_entry.visible = this.quick_open_enabled;
        this.quick_open_button_group.hexpand = this.quick_open_enabled;

        this.path_bar.visible = !this.quick_open_enabled;
        if (!this.quick_open_enabled) {
            this.path_bar.editing = false;
        }

        this.view_button_group.visible = !this.quick_open_enabled;
    }

    private void
    view_stack_update_visible_child() {
        switch (this.view_mode) {
        case LIST:
            this.view_stack.visible_child = this.list_view;
            break;
        case ICON:
            this.view_stack.visible_child = this.icon_view;
            break;
        case TREE:
            this.view_stack.visible_child = this.tree_view;
            break;
        }
    }

    private void
    open_fileinfo(GLib.FileInfo fileinfo) {
        var file = (GLib.File) fileinfo.get_attribute_object("standard::file");
        switch (fileinfo.get_file_type()) {
        case REGULAR:
            if (this.mode == SAVE) {
                this.filename_entry.text = fileinfo.get_display_name();
                this.filename_entry.grab_focus();
            } else {
                this.open(file);
            }
            return;
        case DIRECTORY:
            this.root_directory = file;
            return;
        default:
            return;
        }
    }

    private void
    views_init() {
        this.dialog_actions.add_action(new GLib.PropertyAction("quick-open", this, "quick-open-enabled"));

        this.dialog_actions.add_action(new GLib.PropertyAction("view-mode", this, "view-mode"));

        this.dialog_actions.add_action(new GLib.PropertyAction("show-binary", this, "show-binary"));
        this.dialog_actions.add_action(new GLib.PropertyAction("show-hidden", this, "show-hidden"));

        this.notify["quick-open-enabled"].connect(this.toolbar_update_visibility);
        this.toolbar_update_visibility();

        this.notify["view-mode"].connect(this.view_stack_update_visible_child);
        this.view_stack_update_visible_child();

        // Unhandled keypresses get redirected to the quick open entry and, if
        // handled there, result in a switch to quick open mode.
        var event_controller = new Gtk.EventControllerKey();
        event_controller.name = "Redirect";
        event_controller.propagation_phase = BUBBLE;
        event_controller.key_pressed.connect((controller, keyval, keycode, modifiers) => {
            if (this.quick_open_enabled) {
                return false;
            }
            if (event_controller.forward(this.quick_open_entry.get_delegate())) {
                this.quick_open_entry.grab_focus_without_selecting();
                this.quick_open_enabled = true;
                return true;
            }
            this.quick_open_enabled = false;
            return false;
        });
        this.toolbar_view.add_controller(event_controller);

        var cancel_controller = new Gtk.ShortcutController();
        cancel_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("Escape"),
            new Gtk.CallbackAction(() => {
                // Partially duplicated on quick open entry to capture Escape
                // during CAPTURE phasee when buffering enabled.
                if (this.quick_open_enabled) {
                    this.quick_open_enabled = false;
                    return true;
                }
                if (this.path_bar.editing) {
                    this.path_bar.editing = false;
                    return true;
                }
                this.close();
                return true;
            })
        ));
        this.toolbar_view.add_controller(cancel_controller);

        this.bind_property("root-directory", this.path_bar, "root-directory", BIDIRECTIONAL | SYNC_CREATE);
        this.path_bar.notify["editing"].connect(() => {
            if (this.path_bar.editing) {
                this.quick_open_enabled = false;
            }
        });

        var goto_controller = new Gtk.ShortcutController();
        goto_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("<Control>l"),
            new Gtk.CallbackAction(() => {
                this.path_bar.editing = true;
                this.path_bar.grab_focus();
                return true;
            })
        ));
        this.toolbar_view.add_controller(goto_controller);
    }

    /* --- Quick Open ------------------------------------------------------- */

    public bool quick_open_enabled { get; set; default=false; }

    [GtkChild]
    private unowned Brk.ButtonGroup quick_open_button_group;

    [GtkChild]
    private unowned Brk.QuickOpenEntry quick_open_entry;

    private void
    quick_open_init() {
        this.quick_open_entry.file_activated.connect((fileinfo) => {
            this.open_fileinfo(fileinfo);
        });

        this.notify["quick-open-enabled"].connect((v, pspec) => {
            if (!this.quick_open_enabled) {
                // Clear the quick open entry text so that next quick open is
                // enabled it can start from a clean slate.
                this.quick_open_entry.text = "";
                this.view_stack.grab_focus();
            }
        });
        this.quick_open_entry.notify["text"].connect((fe, pspec) => {
            if (this.quick_open_entry.text == "") {
                // Exit quick open when text is deleted.  This won't be
                // triggered on enabling the quick open entry as the entry is
                // cleared when closed.
                this.quick_open_enabled = false;
            }
        });

        this.notify["root-directory"].connect((fd, pspec) => {
            this.quick_open_enabled = false;
        });

        this.bind_property("root-directory", this.quick_open_entry, "root-directory", SYNC_CREATE);
        this.bind_property("show-binary", this.quick_open_entry, "show-binary", SYNC_CREATE);
        this.bind_property("show-hidden", this.quick_open_entry, "show-hidden", SYNC_CREATE);

        this.notify["focus-widget"].connect(() => {
            if (!this.quick_open_enabled) {
                return;
            }
            var fw = this.focus_widget;
            if (fw != null && (fw == this.quick_open_entry || fw.is_ancestor(this.quick_open_entry))) {
                return;
            }
            this.quick_open_enabled = false;
        });
    }

    /* --- List View -------------------------------------------------------- */

    public string[] sort_columns;

    [GtkChild]
    private unowned Gtk.ScrolledWindow list_view;

    [GtkChild]
    private unowned Gtk.ColumnView list_view_column_view;

    [GtkChild]
    private unowned Gtk.ColumnViewColumn list_view_name_column;

    [GtkChild]
    private unowned Gtk.ColumnViewColumn list_view_size_column;

    [GtkChild]
    private unowned Gtk.ColumnViewColumn list_view_type_column;

    private Gtk.SortListModel list_view_sort_model = new Gtk.SortListModel(null, null);

    internal Gtk.SelectionModel list_view_selection_model { get; set; default = new Gtk.NoSelection(null); }
    // Files that should be in the current selection but haven't been loaded
    // into the directory list yet.
    private GLib.HashTable<GLib.File, GLib.FileInfo> list_view_pending_selection = new GLib.HashTable<GLib.File, GLib.FileInfo>(GLib.File.hash, GLib.File.equal);

    private void
    list_view_save_selection() {
        var list_model = this.list_view_selection_model as GLib.ListModel;
        var result = new GLib.ListStore(typeof(GLib.FileInfo));
        for (var i = 0; i < list_model.get_n_items(); i++) {
            if (this.list_view_selection_model.is_selected(i)) {
                result.append(this.list_view_selection_model.get_item(i) as GLib.FileInfo);
            }
        }
        list_view_pending_selection.foreach((_, fileinfo) => {
            result.append(fileinfo as GLib.FileInfo);
        });
        this.selection = result;
    }

    private void
    list_view_restore_selection() {
        var selection = this.selection;
        this.list_view_pending_selection.remove_all();
        var root_directory = this.directory_list.file;
        for (var i = 0; i < (selection != null? selection.get_n_items() : 0); i++) {
            var fileinfo = selection.get_item(i) as GLib.FileInfo;
            var file = fileinfo.get_attribute_object("standard::file") as GLib.File;
            if (!file.has_parent(root_directory)) {
                // File not visible in current state of view.  Only safe thing
                // to do is to clear the entire selection.  Silently dropping
                // just some files from the selection or worse leaving invisible
                // files selected is not acceptable.
                this.list_view_pending_selection.remove_all();
                break;
            }
            this.list_view_pending_selection[file] = fileinfo;
        }
        var selected = new Gtk.Bitset.empty();
        var mask = new Gtk.Bitset.range(0, this.list_view_sort_model.n_items);
        for (var i = 0; i < this.list_view_sort_model.n_items; i++) {
            var fileinfo = this.list_view_sort_model.get_item(i) as GLib.FileInfo;
            var file = fileinfo.get_attribute_object("standard::file") as GLib.File;
            if (this.list_view_pending_selection.steal(file)) {
                selected.add(i);
            }
        }
        this.list_view_selection_model.set_selection(selected, mask);
    }

    private void
    list_view_rebuild_selection() {
        if (this.select_multiple) {
            this.list_view_selection_model = new Gtk.MultiSelection(this.list_view_sort_model);
        } else {
            this.list_view_selection_model = new Gtk.SingleSelection(this.list_view_sort_model);
        }
        this.list_view_selection_model.selection_changed.connect((sm, p, n_items) => {
            if (this.view_mode == LIST) {
                this.list_view_save_selection();
            }
        });
        this.list_view_restore_selection();
    }

    private void
    list_view_on_sort_model_items_changed(GLib.ListModel _, uint position, uint removed, uint added) {
        // Check if any of the newly added items is in the pending selection and
        // should be selected.
        var selected = new Gtk.Bitset.empty();
        var mask = new Gtk.Bitset.range(position, added);
        for (var i = position; i < position + added; i++) {
            var fileinfo = this.list_view_sort_model.get_item(i) as GLib.FileInfo;
            var file = fileinfo.get_attribute_object("standard::file") as GLib.File;
            if (this.list_view_pending_selection.steal(file)) {
                selected.add(i);
            }
        }
        this.list_view_selection_model.set_selection(selected, mask);
    }

    private void
    list_view_on_directory_list_notify_loading(GLib.Object _, GLib.ParamSpec pspec) {
        if (!this.directory_list.loading) {
            // All files that actually exist in the directory should now also be
            // in the directory list model.  Any files in the selection that
            // aren't in the directory list model don't exist anymore and should
            // be removed.
            this.list_view_pending_selection.remove_all();
            this.list_view_save_selection();
        }
    }

    private void
    list_view_name_column_init() {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            listitem.child = new Brk.FileThumbnail();
        });
        factory.bind.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            var thumbnail = (Brk.FileThumbnail) listitem.child;
            thumbnail.fileinfo = (GLib.FileInfo) listitem.item;
        });
        this.list_view_name_column.factory = factory;
        var sorter = new Gtk.CustomSorter((aptr, bptr) => {
            var ainfo = (GLib.FileInfo) aptr;
            var aname = ainfo.get_name();
            var akey = aname.collate_key_for_filename();

            var binfo = (GLib.FileInfo) bptr;
            var bname = binfo.get_name();
            var bkey = bname.collate_key_for_filename();

            return Gtk.Ordering.from_cmpfunc(GLib.strcmp(akey, bkey));
        });
        this.list_view_name_column.sorter = sorter;
    }

    private void
    list_view_size_column_init() {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            var label = new Gtk.Label("");
            label.halign = START;
            listitem.child = label;
        });
        factory.bind.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            Gtk.Label label = (Gtk.Label) listitem.child;
            GLib.FileInfo info = (GLib.FileInfo) listitem.item;
            label.label = GLib.format_size(info.get_size());
        });
        this.list_view_size_column.factory = factory;
        var sorter = new Gtk.CustomSorter((aptr, bptr) => {
            var ainfo = (GLib.FileInfo) aptr;
            var asize = ainfo.get_size();

            var binfo = (GLib.FileInfo) bptr;
            var bsize = binfo.get_size();

            if (asize < bsize) return Gtk.Ordering.SMALLER;
            if (asize > bsize) return Gtk.Ordering.LARGER;
            return Gtk.Ordering.EQUAL;
        });
        this.list_view_size_column.sorter = sorter;
    }

    private void
    list_view_type_column_init() {
        var factory = new Gtk.SignalListItemFactory();
        factory.setup.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            var label = new Gtk.Label("");
            label.halign = START;
            listitem.child = label;
        });
        factory.bind.connect((listitem_) => {
            var listitem = (Gtk.ListItem) listitem_;
            Gtk.Label label = (Gtk.Label) listitem.child;
            GLib.FileInfo info = (GLib.FileInfo) listitem.item;
            var content_type = info.get_content_type();
            label.label = get_category_from_content_type(content_type);
        });
        this.list_view_type_column.factory = factory;
    }

    private void
    list_view_on_column_view_activate(Gtk.ColumnView cv, uint position) {
        var fileinfo = this.list_view_selection_model.get_item(position) as GLib.FileInfo;
        if (fileinfo != null) {
            this.open_fileinfo(fileinfo);
        }
    }

    // Direction that focus was last moving in when it entered the list view.
    private Gtk.DirectionType list_view_focus_direction = Gtk.DirectionType.TAB_FORWARD;

    private void
    list_view_grab_focus(Gtk.DirectionType direction) {
        this.list_view_focus_direction = direction;
        if (this.list_view.child_focus(direction)) {
            return;
        }
        // Nothing to focus yet.  Park focus on the scrolled window, which is
        // focusable, so that it can be handed on to the rows once the
        // directory list has loaded.
        this.set_focus(this.list_view);
    }

    private void
    list_view_on_selection_model_items_changed(GLib.ListModel _, uint pos, uint removed, uint added) {
        if (added == 0 || this.focus_widget != this.list_view) {
            return;
        }
        this.list_view.child_focus(this.list_view_focus_direction);
    }

    private void
    list_view_init() {
        this.list_view_sort_model.model = this.directory_list;

        this.notify["select-multiple"].connect((lv, pspec) => {
            this.list_view_rebuild_selection();
        });
        this.list_view_rebuild_selection();

        this.notify["view-mode"].connect(() => {
            if (this.view_mode == LIST) {
                // Apply the shared selection to the list view when switching
                // to it from a different view.
                this.list_view_restore_selection();
            }
        });

        // This handler requires that the directory list is bound to the
        // selection model first.  Do not move before the call to rebuild the
        // selection.
        this.directory_list.notify["loading"].connect(this.list_view_on_directory_list_notify_loading);

        this.list_view_sort_model.items_changed.connect(this.list_view_on_sort_model_items_changed);

        this.list_view_name_column_init();
        this.list_view_size_column_init();
        this.list_view_type_column_init();

        this.list_view_column_view.sort_by_column(this.list_view_name_column, ASCENDING);

        this.bind_property("list-view-selection-model", this.list_view_column_view, "model", SYNC_CREATE);
        this.list_view_column_view.bind_property("sorter", this.list_view_sort_model, "sorter", SYNC_CREATE);
        this.list_view_column_view.activate.connect(this.list_view_on_column_view_activate);

        this.notify["list-view-selection-model"].connect((obj, pspec) => {
            this.list_view_selection_model.items_changed.connect(this.list_view_on_selection_model_items_changed);
        });
        this.list_view_selection_model.items_changed.connect(this.list_view_on_selection_model_items_changed);
    }

    /* --- Icon View -------------------------------------------------------- */

    [GtkChild]
    private unowned Brk.FileDialogIconView icon_view;

    private void
    on_icon_view_file_activated(GLib.FileInfo fileinfo) {
        this.open_fileinfo(fileinfo);
    }

    private void
    icon_view_init() {
        this.icon_view.directory_list = this.directory_list;
        this.icon_view.file_activated.connect(this.on_icon_view_file_activated);
    }

    /* --- Tree View -------------------------------------------------------- */

    // Sorted list of expanded directories under the current mount.
    public string[] expanded;

    [GtkChild]
    private unowned Brk.FileDialogTreeView tree_view;

    private void
    on_tree_view_file_activated(GLib.FileInfo fileinfo) {
        this.open_fileinfo(fileinfo);
    }

    private void
    tree_view_init() {
        this.tree_view.directory_list = this.directory_list;
        this.tree_view.file_activated.connect(this.on_tree_view_file_activated);
    }

    /* === Sidebar ========================================================== */

    [GtkChild]
    private unowned Gtk.ListBox sidebar_list_box;

    private void
    sidebar_init() {
        this.sidebar_list_box.append(new FileDialogSidebarRow.for_file(
            _("Home"),
            new GLib.ThemedIcon("user-home"),
            GLib.File.new_for_path(GLib.Environment.get_home_dir())
        ));
        this.sidebar_list_box.append(new FileDialogSidebarRow.for_file(
            _("Filesystem"),
            new GLib.ThemedIcon("drive-harddisk"),
            GLib.File.new_for_path("/")
        ));

        this.sidebar_list_box.row_activated.connect((row) => {
            var sidebar_row = row as FileDialogSidebarRow;
            if (sidebar_row != null) {
                this.root_directory = sidebar_row.file;
            }
        });
    }

    /* === Action Bars ====================================================== */

    /* --- Open Bar --------------------------------------------------------- */

    [GtkChild]
    private unowned Gtk.ActionBar open_bar;

    [GtkChild]
    private unowned Gtk.Button open_button;

    private GLib.SimpleAction open_action;

    private void
    open_action_on_activate() {
        GLib.FileInfo? selection = (GLib.FileInfo?) this.selection.get_item(0);
        if (selection != null) {
            this.open_fileinfo(selection);
        }
    }

    private void
    open_action_update_enabled() {
        this.open_action.set_enabled(this.selection.get_n_items() > 0);
    }

    private void
    open_bar_update_visibility() {
        if (this.mode == OPEN) {
            this.open_bar.visible = true;
            this.default_widget = open_button;
        } else {
            this.open_bar.visible = false;
        }
    }

    private void
    open_bar_init() {
        this.open_action = new GLib.SimpleAction("open", null);
        this.open_action.activate.connect(this.open_action_on_activate);
        this.dialog_actions.add_action(this.open_action);

        this.open_action_update_enabled();
        this.notify["selection"].connect(this.open_action_update_enabled);

        this.notify["mode"].connect(this.open_bar_update_visibility);
        this.open_bar_update_visibility();
    }

    /* --- Save Bar --------------------------------------------------------- */

    [GtkChild]
    private unowned Gtk.ActionBar save_bar;

    [GtkChild]
    private unowned Gtk.Entry filename_entry;

    public string filename {
        get { return this.filename_entry.text; }
        set { this.filename_entry.text = value; }
    }

    private void
    save_bar_update_visibility() {
        if (this.mode == SAVE) {
            this.save_bar.visible = true;
            this.default_widget = save_button;
        } else {
            this.save_bar.visible = false;
        }
    }

    [GtkChild]
    private unowned Gtk.Button save_button;

    private GLib.SimpleAction save_action;

    private void
    save_action_on_activate() {
        var filename = this.filename_entry.text.strip();
        return_if_fail(filename != "");
        this.open(this.root_directory.get_child(filename));
    }

    private void
    save_action_update_enabled() {
        save_action.set_enabled(this.filename_entry.text.strip() != "");
    }

    private void
    save_bar_init() {
        this.save_action = new GLib.SimpleAction("save", null);
        this.save_action.activate.connect(this.save_action_on_activate);
        this.dialog_actions.add_action(this.save_action);

        this.filename_entry.notify["text"].connect(this.save_action_update_enabled);
        this.save_action_update_enabled();

        this.notify["mode"].connect(this.save_bar_update_visibility);
        this.save_bar_update_visibility();

        this.notify["selection"].connect(() => {
            var item = (GLib.FileInfo?) this.selection.get_item(0);
            if (item != null && item.get_file_type() == REGULAR) {
                this.filename_entry.text = item.get_display_name();
            }
        });
    }

    /* === Lifecycle ======================================================== */

    class construct {
        typeof (Brk.FileDialogPathBar).ensure();
        typeof (Brk.QuickOpenEntry).ensure();
        typeof (Brk.FileDialogIconView).ensure();
        typeof (Brk.FileDialogTreeView).ensure();
    }

    construct {
        this.directory_list = new Gtk.DirectoryList(
            "standard::icon,standard::name,standard::display-name,standard::size,time::modified,standard::type,standard::content-type",
            this.root_directory
        );
        directory_list.monitored = true;
        this.bind_property("root-directory", this.directory_list, "file", SYNC_CREATE);

        this.views_init();
        this.quick_open_init();
        this.list_view_init();
        this.icon_view_init();
        this.tree_view_init();
        this.sidebar_init();
        this.open_bar_init();
        this.save_bar_init();

        this.insert_action_group("dialog", this.dialog_actions);

        this.map.connect(() => {
            if (this.mode == SAVE) {
                this.filename_entry.grab_focus();
            } else if (this.view_mode == LIST) {
                this.list_view_grab_focus(TAB_FORWARD);
            } else {
                this.view_stack.visible_child.child_focus(TAB_FORWARD);
            }
        });
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.FileDialogWindow));
        base.dispose();
    }
}

/**
 * Asnychronous API for opening a file chooser dialog.
 *
 * Brk.FileDialog collects the arguments that are needed topresent the dialog to
 * the user such as a title or whether it should be modal.
 *
 * It is safe to reuse a file dialog object multiple times to serve multiple
 * requests.  You do not need to wait for previous requests to finish before
 * asking for a new window.
 */
public sealed class Brk.FileDialog : GLib.Object {
    public string title { get; set; }

    public GLib.File initial_file { get; set; }
    public GLib.File initial_folder { get; set; }
    public string initial_name { get; set; }

    public Gtk.FileFilter default_filter { get; set; }
    public GLib.ListModel filters { get; set; }

    public string accept_label { get; set; }

    /**
     * Opens a new file chooser dialog to allow the user to select a single file
     * for reading.
     *
     * If the user closes the chooser without selecting a file will return NULL.
     * Will throw a CANCELLED error if interrupted.
     */
    public async GLib.File?
    open(Gtk.Window? parent, GLib.Cancellable? cancellable) throws Error {
        if (cancellable != null && cancellable.is_cancelled()) {
            throw new GLib.IOError.CANCELLED("open cancelled");
        }

        var window = new Brk.FileDialogWindow();
        window.set_transient_for(parent);

        Brk.FileDialogState? state = parent.get_data("bricks-file-dialog-state");
        if (state != null) {
            window.view_mode = state.view_mode;
            window.show_binary = state.show_binary;
            window.show_hidden = state.show_hidden;
            window.root_directory =  state.root_directory;
            window.expanded = {};
            window.sort_columns = {};
        } else {
            window.view_mode = LIST;
            window.root_directory = GLib.File.new_for_path(
                GLib.Environment.get_current_dir()
            );
            window.expanded = {};
            window.sort_columns = {};
        }

        GLib.File? result = null;
        bool done = false;

        ulong cancellable_id = 0;
        if (cancellable != null) {
            cancellable_id = cancellable.connect((c) => {
                if (!done) {
                    done = true;
                    window.close();
                    this.open.callback();
                }
            });
        }
        window.open.connect((file) => {
            result = file;
            if (!done) {
                done = true;
                window.close();
                this.open.callback();
            }
        });
        ((Gtk.Widget) window).unrealize.connect(() => {
            if (!done) {
                done = true;
                this.open.callback();
            }
        });
        window.present();
        yield;

        if (cancellable != null) {
            cancellable.disconnect(cancellable_id);
        }

        var new_state = new FileDialogState() {
            view_mode = window.view_mode,
            show_binary = window.show_binary,
            show_hidden = window.show_hidden,
            root_directory = window.root_directory,
            expanded = null,
            sort_columns = null,
        };
        parent.set_data("bricks-file-dialog-state", new_state);

        if (cancellable != null && cancellable.is_cancelled()) {
            throw new GLib.IOError.CANCELLED("open cancelled");
        }

        return result;
    }

    /**
     * Opens a new file chooser dialog to allow the user to select a path for
     * writing.
     *
     * If the user closes the chooser without selecting a file will return NULL.
     * Will throw a CANCELLED error if interrupted.
     */
    public async GLib.File?
    save(Gtk.Window? parent, GLib.Cancellable? cancellable) throws Error {
        if (cancellable != null && cancellable.is_cancelled()) {
            throw new GLib.IOError.CANCELLED("save cancelled");
        }

        var window = new Brk.FileDialogWindow();
        window.set_transient_for(parent);
        window.mode = SAVE;

        Brk.FileDialogState? state = parent.get_data("bricks-file-dialog-state");
        if (state != null) {
            window.view_mode = state.view_mode;
            window.show_binary = state.show_binary;
            window.show_hidden = state.show_hidden;
            window.root_directory = state.root_directory;
            window.expanded = {};
            window.sort_columns = {};
        } else {
            window.view_mode = LIST;
            window.root_directory = GLib.File.new_for_path(
                GLib.Environment.get_current_dir()
            );
            window.expanded = {};
            window.sort_columns = {};
        }

        if (this.initial_file != null) {
            window.root_directory = this.initial_file.get_parent() ?? window.root_directory;
            window.filename = this.initial_file.get_basename() ?? "";
        } else {
            if (this.initial_folder != null) {
                window.root_directory = this.initial_folder;
            }
            if (this.initial_name != null) {
                window.filename = this.initial_name;
            }
        }

        GLib.File? result = null;
        bool done = false;

        ulong cancellable_id = 0;
        if (cancellable != null) {
            cancellable_id = cancellable.connect((c) => {
                if (!done) {
                    done = true;
                    window.close();
                    this.save.callback();
                }
            });
        }
        window.open.connect((file) => {
            result = file;
            if (!done) {
                done = true;
                window.close();
                this.save.callback();
            }
        });
        ((Gtk.Widget) window).unrealize.connect(() => {
            if (!done) {
                done = true;
                this.save.callback();
            }
        });
        window.present();
        yield;

        if (cancellable != null) {
            cancellable.disconnect(cancellable_id);
        }

        var new_state = new FileDialogState() {
            view_mode = window.view_mode,
            show_binary = window.show_binary,
            show_hidden = window.show_hidden,
            root_directory = window.root_directory,
            expanded = null,
            sort_columns = null,
        };
        parent.set_data("bricks-file-dialog-state", new_state);

        if (cancellable != null && cancellable.is_cancelled()) {
            throw new GLib.IOError.CANCELLED("save cancelled");
        }

        return result;
    }
}
