/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

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
        this.bind_property("root-directory", this.path_bar, "root-directory", BIDIRECTIONAL | SYNC_CREATE);

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
                this.close();
                return true;
            })
        ));
        this.toolbar_view.add_controller(cancel_controller);
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
    private unowned Brk.FileDialogListView list_view;

    private void
    on_list_view_file_activated(GLib.FileInfo fileinfo) {
        this.open_fileinfo(fileinfo);
    }

    private void
    list_view_init() {
        this.list_view.directory_list = this.directory_list;
        this.list_view.file_activated.connect(this.on_list_view_file_activated);

        this.notify["view-mode"].connect(() => {
            if (this.view_mode == LIST) {
                // Apply current selection to list view when switching from a
                // different view.
                this.list_view.selection = this.selection;
            }
        });
        this.list_view.notify["selection"].connect((v, pspec) => {
            if (this.view_mode == LIST) {
                // Sync selection to match list view when list view visible.
                this.selection = this.list_view.selection;
            }
        });
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
        typeof (Brk.FileDialogListView).ensure();
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
