/*
 * Copyright (c) 2026 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

private const string ATTRIBUTES = "standard::*,time::modified";

private struct QueryStackEntry {
    string subquery;
    GLib.FileInfo[] matches;
}

private void append_escaped(GLib.StringBuilder str, unichar chr) {
    // Mostly stolen from `g_markup_escape_text`,
    switch (chr) {
    case '&':
        str.append("&amp;");
        break;

    case '<':
        str.append("&lt;");
        break;

    case '>':
        str.append("&gt;");
        break;

    case '\'':
        str.append("&apos;");
        break;

    case '"':
        str.append("&quot;");
        break;

    default:
        if (
            (0x1 <= chr && chr <= 0x8) ||
            (0xb <= chr && chr <= 0xc) ||
            (0xe <= chr && chr <= 0x1f) ||
            (0x7f <= chr && chr <= 0x84) ||
            (0x86 <= chr && chr <= 0x9f)
        ) {
            str.append_printf("&#x%x;", chr);
        } else {
            str.append_unichar(chr);
        }
        break;
    }
}

private bool match_subquery(
    string subquery, string name, GLib.StringBuilder markup, out uint64 quality
) {
    bool bold = false;
    unowned string query_cursor;
    unowned string name_cursor;
    int quality_cursor = 0;
    unowned string chunk_start;

    quality = 0l;

    query_cursor = subquery;
    name_cursor = name;
    chunk_start = name;

    while (chunk_start.get_char() != '\0') {
        unowned string chunk_end;
        unowned string candidate_start;
        unowned string best_start;
        unowned string best_end;
        unowned string best_query_cursor;
        size_t best_length;

        // Find end of chunk.
        chunk_end = chunk_start.next_char();
        while (true) {
            unichar start_char = chunk_start.get_char();
            unichar end_char = chunk_end.get_char();

            if (end_char == '\0') {
                break;
            }

            if (start_char.isalpha()) {
                // Chunk is made up of an upper or lower case letter followed by
                // any number of lower case letters.
                if (!end_char.islower()) {
                    break;
                }
            } else if (start_char.isdigit()) {
                // Chunk is a sequence of digits
                if (!end_char.isdigit()) {
                    break;
                }
            } else {
                // Chunk is a single, non-alphanumeric character.
                break;
            }

            chunk_end = chunk_end.next_char();
        }

        // Find longest match.
        best_start = chunk_start;
        best_end = chunk_start;
        best_query_cursor = query_cursor;
        best_length = 0;

        candidate_start = chunk_start;
        while ((void *)candidate_start < (void *)chunk_end) {
            unowned string candidate_name_cursor;
            unowned string candidate_query_cursor;
            int candidate_length;

            candidate_name_cursor = candidate_start;
            candidate_query_cursor = query_cursor;
            candidate_length = 0;

            while ((void *)candidate_name_cursor <= (void *)chunk_end) {
                unichar name_char = candidate_name_cursor.get_char();
                unichar query_char = candidate_query_cursor.get_char();

                if (query_char == '\0') {
                    break;
                }

                if (name_char.tolower() != query_char.tolower()) {
                    break;
                }

                candidate_name_cursor = candidate_name_cursor.next_char();
                candidate_query_cursor = candidate_query_cursor.next_char();
                candidate_length++;
            }

            if (candidate_length > best_length) {
                best_start = candidate_start;
                best_end = candidate_name_cursor;
                best_query_cursor = candidate_query_cursor;
                best_length = candidate_length;
            }

            candidate_start = candidate_start.next_char();
        }

        while ((void *)name_cursor < (void *)chunk_end) {
            if (
                (void *)name_cursor >= (void *)best_start &&
                (void *)name_cursor < (void *)best_end
            ) {
                if (!bold) {
                    markup.append("<b>");
                    bold = true;
                }
                quality = quality | (1ull << int.max(63 - quality_cursor, 0));
            } else {
                if (bold) {
                    markup.append("</b>");
                    bold = false;
                }
            }

            append_escaped(markup, name_cursor.get_char());

            name_cursor = name_cursor.next_char();
            quality_cursor ++;
        }

        query_cursor = best_query_cursor;
        chunk_start = chunk_end;
    }

    if (bold) {
        markup.append("</b>");
    }

    if (query_cursor.get_char() == '\0') {
        return true;
    } else {
        quality = 0;
        return false;
    }
}

[GtkTemplate ( ui = "/com/bwhmather/Bricks/ui/brk-file-dialog-filter-view.ui")]
internal sealed class Brk.FileDialogFilterView : Gtk.Widget {

    /* === State ============================================================ */

    public GLib.File? root_directory { get; set; default = null; }
    public string query { get; set; default = "";}
    public bool show_binary { get; set; }
    public bool show_hidden { get; set; }

    public bool loading { get; private set; default = false; }
    public GLib.FileInfo? selection { get { return this.selection_model.selected_item as GLib.FileInfo?; }}

    private GLib.ListStore list_store;
    private Gtk.SingleSelection selection_model;

    private QueryStackEntry[] query_stack = null;
    private void
    query_stack_truncate(int n) {
        for (var i = n; i < this.query_stack.length; i++) {
            this.query_stack[i] = {};
        }
        this.query_stack.resize(n);
    }

    private async void
    update_matches(GLib.Cancellable cancellable) {
        // Rules:
        //  1. Before every `yield`, the query stack must be left in a valid
        //     state.
        //  2. After every `yield` the state of `cancellable` must be checked
        //     and no further changes must be made if set.
        try {
            GLib.File? root = this.root_directory;
            string query = this.query;
            bool show_binary = this.show_binary;
            bool show_hidden = this.show_hidden;

            int n = 0;
            string remainder = query[:];

            string subquery = null;
            if (remainder.has_prefix("~/")) {
                root = GLib.File.new_for_path(GLib.Environment.get_home_dir());
                subquery = "~";
                remainder = remainder[2:];
            } else if (remainder.has_prefix("./")) {
                subquery = ".";
                remainder = remainder[2:];
            } else if (remainder.has_prefix("/")) {
                root = GLib.File.new_for_path("/");
                subquery = "";
                remainder = remainder[1:];
            }
            if (root == null) {
                this.query_stack_truncate(0);
                this.list_store.remove_all();
                this.selection_model.selected = 0;
                return;
            }

            this.loading = true;

            if (this.query_stack.length <= n || this.query_stack[n].subquery != subquery) {
                // Truncate before doing anything else to leave stack in valid
                // state.
                this.query_stack_truncate(n);

                var rootinfo = yield root.query_info_async(
                    ATTRIBUTES, NONE, GLib.Priority.DEFAULT, cancellable
                );

                rootinfo.set_attribute_object("standard::file", root);

                string markup = subquery == null ? "" : GLib.Markup.printf_escaped("<b>%s</b>", subquery);
                rootinfo.set_attribute_string("bricks::markup", markup);

                this.query_stack.resize(n + 1);
                this.query_stack[n].subquery = subquery;
                this.query_stack[n].matches = {rootinfo};
            }

            bool done = false;
            while (!done) {
                n += 1;

                // Subquery is from the beginning of the remaining query to
                // either the next `/` or the very end.  We need to read the
                // next subquery here and consume any following slashes.
                // Segments can be empty if the query ends with a trailing /.
                int next_slash = remainder.index_of_char('/', 0);
                if (next_slash >= 0) {
                    subquery = remainder[:next_slash];
                    remainder = remainder[next_slash + 1:];
                } else {
                    subquery = remainder;
                    remainder = "";
                    done = true;
                }

                if (this.query_stack.length > n && this.query_stack[n].subquery == subquery) {
                    // Use cached entry from stack.
                    continue;
                }

                if (subquery == "..") {
                    // Truncate to leave stack in valid state.
                    this.query_stack_truncate(n);

                    // Find all parent directories of all previous matches.
                    GLib.FileInfo[] matches = {};
                    GLib.File last_parent = null;
                    foreach (GLib.FileInfo matchinfo in this.query_stack[n-1].matches) {
                        GLib.File match = matchinfo.get_attribute_object("standard::file") as GLib.File;
                        GLib.File parent = match.get_parent();

                        if (parent == null) {
                            // Can't traverse to parent of root directory.
                            continue;
                        }
                        if (last_parent != null && parent.equal(last_parent)) {
                            // Matches should already be sorted by parent
                            // directory so deduplicating just a matter of
                            // tracking it.
                            continue;
                        }

                        var parentinfo = yield parent.query_info_async(
                            ATTRIBUTES, NONE, GLib.Priority.DEFAULT, cancellable
                        );
                        parentinfo.set_attribute_object("standard::file", parent);

                        string markup = matchinfo.get_attribute_string("bricks::markup");
                        parentinfo.set_attribute_string("bricks::markup", markup != "" ? markup + "<b>/..</b>" : "<b>..</b>");

                        matches += parentinfo;
                        last_parent = parent;
                    }

                    this.query_stack.resize(n + 1);
                    this.query_stack[n].subquery = (owned) subquery;
                    this.query_stack[n].matches = (owned) matches;

                    continue;
                }

                GLib.FileInfo[] candidates = {};
                if (this.query_stack.length > n && (
                    subquery.has_prefix(this.query_stack[n].subquery) ||
                    this.query_stack[n].subquery == ".."
                )) {
                    // New query is a refinement of the current query so we can
                    // copy the existing matches as a starting point.
                    candidates = this.query_stack[n].matches;
                } else {
                    // New query is not a refinement of the current query so we
                    // cannot reuse the existing list.
                    foreach (GLib.FileInfo parentinfo in this.query_stack[n-1].matches) {
                        GLib.FileType parenttype = parentinfo.get_file_type();
                        if (parenttype != DIRECTORY && parenttype != SYMBOLIC_LINK) {
                            continue;
                        }

                        GLib.File parent = parentinfo.get_attribute_object("standard::file") as GLib.File;
                        var enumerator = yield parent.enumerate_children_async(
                            ATTRIBUTES, NONE, GLib.Priority.DEFAULT, cancellable
                        );
                        while (true) {
                            var fileinfos = yield enumerator.next_files_async(
                                64, GLib.Priority.DEFAULT, cancellable
                            );
                            if (fileinfos.length() == 0) {
                                break;
                            }
                            foreach (var fileinfo in fileinfos) {
                                var file = enumerator.get_child(fileinfo);
                                fileinfo.set_attribute_object("standard::file", file);

                                candidates += fileinfo;
                            }
                        }
                        yield enumerator.close_async(GLib.Priority.DEFAULT, cancellable);
                    }
                }

                // TODO Filter to only include matches and sort by match quality.
                // When sorting, files should be kept together with other files
                // with the same parent directory.

                GLib.FileInfo[] matches = {};
                var parent_index = 0;
                var markup = new GLib.StringBuilder();
                foreach (var candidate in candidates) {
                    if (!show_hidden && candidate.get_is_hidden()) {
                        continue;
                    }

                    var file = candidate.get_attribute_object("standard::file") as GLib.File;

                    markup.truncate(0);
                    while (true) {
                        var parentinfo = this.query_stack[n - 1].matches[parent_index];
                        var parentfile = parentinfo.get_attribute_object("standard::file") as GLib.File;
                        if (parentfile.equal(file.get_parent())) {
                            markup.append(parentinfo.get_attribute_string("bricks::markup"));
                            break;
                        }
                        parent_index++;
                    }
                    if (markup.len > 0) {
                        markup.append("<b>/</b>");
                    }

                    string name = candidate.get_name();
                    uint64 quality = 0;
                    if (!match_subquery(subquery, name, markup, out quality)) {
                        continue;
                    }

                    // We need to dup in order to invalidate the list view items.
                    var match = candidate.dup();
                    match.set_attribute_string("bricks::markup", markup.str);
                    match.set_attribute_uint64("bricks::quality", quality);

                    matches += match;
                }

                GLib.qsort_with_data<GLib.FileInfo>(matches, sizeof (GLib.FileInfo), (a, b) => {
                    var fa = a.get_attribute_object("standard::file") as GLib.File;
                    var fb = b.get_attribute_object("standard::file") as GLib.File;
                    if (!fa.has_parent(fb.get_parent())) {
                        // Preserve existing order if parents don't match.
                        return -1;
                    }

                    var qa = a.get_attribute_uint64("bricks::quality");
                    var qb = b.get_attribute_uint64("bricks::quality");
                    if (qa < qb) {
                        return 1;
                    }
                    if (qa > qb) {
                        return -1;
                    }

                    if (fa.get_basename() < fb.get_basename()) {
                        return -1;
                    } else {
                        return 1;
                    }
                });

                // Changing a stack entry invalidates all higher entries.
                this.query_stack.resize(n + 1);
                this.query_stack[n].subquery = (owned) subquery;
                this.query_stack[n].matches = (owned) matches;
            }

            // Remove any unused entries from the query cache as these were
            // derived from a different query.
            this.query_stack_truncate(n + 1);
            this.list_store.splice(0, this.list_store.get_n_items(), this.query_stack[n].matches);
            this.selection_model.selected = 0;
            this.loading = false;

        } catch (GLib.IOError.CANCELLED _) {
            // We don't know if another query is going to be triggered so can't
            // safely unset loading or do any other cleanup here.  All we can
            // do is make sure all cancellable operations levae the view in a
            // consistent state and let the cancelling code clean up.
            return;
        } catch {
            this.query_stack_truncate(0);
            this.list_store.remove_all();
            this.selection_model.selected = 0;
            this.loading = false;
            // TODO
            return;
        }
    }

    private GLib.Cancellable query_cancellable = null;
    private void
    update() {
        if (this.query_cancellable != null) {
            this.query_cancellable.cancel();
            this.query_cancellable = null;
        }

        if (!this.get_mapped() || this.root_directory == null || this.query == "") {
            this.list_store.remove_all();
            this.selection_model.selected = 0;
            this.loading = false;
            return;
        }

        this.query_cancellable = new GLib.Cancellable();
        this.update_matches.begin(this.query_cancellable, (_, res) => {
            this.update_matches.end(res);
        });
    }

    /* === View ============================================================= */

    [GtkChild]
    private unowned Gtk.ListView list_view;

    private void
    view_init() {
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
        this.list_view.factory = factory;

        this.list_view.model = this.selection_model;
    }

    /* === Lifecycle ======================================================== */

    class construct {
        set_layout_manager_type(typeof (Gtk.BinLayout));
    }

    construct {
        this.list_store = new GLib.ListStore(typeof(GLib.FileInfo));
        this.selection_model = new Gtk.SingleSelection(this.list_store);
        this.selection_model.notify["selected-item"].connect((sm, pspec) => {
            this.notify_property("selection");
        });

        this.notify["root-directory"].connect((fv, pspec) => {
            this.query_stack_truncate(0);
            this.update();
        });
        this.notify["query"].connect((fv, pspec) => {
            this.update();
        });
        this.notify["show-binary"].connect((fv, pspec) => {
            this.query_stack_truncate(0);
            this.update();
        });
        this.notify["show-hidden"].connect((fv, pspec) => {
            this.query_stack_truncate(0);
            this.update();
        });
        this.map.connect(() => {
            this.update();
        });
        this.unmap.connect(() => {
            this.update();
        });
        this.update();

        this.view_init();
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.FileDialogFilterView));
        base.dispose();
    }

    public void
    select_prev() {
        this.selection_model.selected -= 1;
    }

    public void
    select_next() {
        this.selection_model.selected += 1;
    }
}

