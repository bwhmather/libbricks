/*
 * Copyright (c) 2025 Ben Mather <bwhmather@bwhmather.com>
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

/**
 * # CSS nodes
 *
 * ```
 * tabview[.empty][.single]
 * ├── tabbar
 * ┊   ├── tabbuttons.start
 * ┊   ┊
 * ┊   ├── tabs
 * ┊   ┊    ╰── tab[.selected]
 * ┊   ┊
 * ┊   ╰── tabbuttons.end
 * ┊
 * ╰── tabpages
 *     ╰── tabpage
 *          ╰── <child>
 * ```
 */

[Flags]
public enum Brk.TabViewShortcuts {
    NONE,
    CONTROL_TAB,
    CONTROL_SHIFT_TAB,
    CONTROL_PAGE_UP,
    CONTROL_PAGE_DOWN,
    CONTROL_HOME,
    CONTROL_END,
    CONTROL_SHIFT_PAGE_UP,
    CONTROL_SHIFT_PAGE_DOWN,
    CONTROL_SHIFT_HOME,
    CONTROL_SHIFT_END,
    ALT_DIGITS,
    ALT_ZERO,
    ALL_SHORTCUTS
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-tab-page-tab.ui")]
private sealed class Brk.TabPageTab : Gtk.Widget {
    public unowned Brk.TabPage page { get; construct; }

    [GtkChild]
    private unowned Gtk.Label label;

    [GtkChild]
    private unowned Gtk.Button close_button;

    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("tab");
        set_accessible_role(TAB);
    }

    construct {
        this.page.bind_property("title", this.label, "label", SYNC_CREATE);
        this.page.notify["selected"].connect((p, pspec) => {
            if (this.page.selected) {
                this.add_css_class("selected");
            } else {
                this.remove_css_class("selected");
            }
        });
        this.close_button.clicked.connect((b) => {
            this.page.close();
        });

        var drag_controller = new Gtk.DragSource();
        drag_controller.prepare.connect((s, x, y) => {
            this.page.drag_tab_offset = x;
            var gvalue = new GLib.Value(typeof(Brk.TabPage));
            gvalue.set_object(this.page);
            return new Gdk.ContentProvider.for_value(gvalue);
        });
        drag_controller.drag_begin.connect((s, drag) => {
            assert(this.page.drag == null);

            drag.actions = MOVE;

            // Disable default drag icon.
            var drag_icon = Gtk.DragIcon.get_for_drag(drag) as Gtk.DragIcon;
            //drag_icon.child = new Gtk.Box(VERTICAL, 0);
            drag_icon.child = new Gtk.Label(".");

            this.page.drag = drag;
        });
        drag_controller.drag_cancel.connect((s, drag, r) => {
            assert(this.page.drag == drag);

            var drag_icon = Gtk.DragIcon.get_for_drag(drag) as Gtk.DragIcon;
            //drag_icon.child = new Gtk.Box(VERTICAL, 0);
            drag_icon.child = new Gtk.Label(".");

            // TODO page shouldn't know about views.
            if (!this.page.drag_source.has_page(this.page)) {
                this.page.drag_source.attach_page(this.page);
            }

            return true;
        });
        drag_controller.drag_end.connect((s, drag, delete_data) => {
//            assert(this.page.drag == drag);
            this.page.drag = null;
        });
        this.add_controller(drag_controller);

        var click_controller = new Gtk.GestureClick();
        click_controller.pressed.connect((n_press, x, y) => {
            var picked = this.pick(x, y, DEFAULT);
            if (picked == this.close_button || picked.is_ancestor(this.close_button)) {
                return;
            }

            this.page.focus();
        });
        this.add_controller(click_controller);
    }

    public override void
    dispose() {
        this.dispose_template(typeof(Brk.TabPageTab));
    }

    internal TabPageTab(Brk.TabPage page) {
        Object(page: page);
    }
}

private sealed class Brk.TabPageBin : Gtk.Widget {
    public unowned Brk.TabPage page { get; construct; }

    static construct {
        set_layout_manager_type(typeof (Gtk.BinLayout));
        set_css_name("tabpage");
        set_accessible_role(TAB_PANEL);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.HORIZONTAL, -1);
        this.page.child.set_parent(this);
    }

    public override void
    dispose() {
        while (this.get_last_child() != null) {
            this.get_last_child().unparent();
        }
    }

    public override void
    compute_expand_internal(out bool hexpand, out bool vexpand) {
        hexpand = this.page.child.compute_expand(Gtk.Orientation.HORIZONTAL);
        vexpand = this.page.child.compute_expand(Gtk.Orientation.VERTICAL);
    }

    public override bool
    focus(Gtk.DirectionType direction) {
        return this.page.child.focus(direction);
    }

    internal TabPageBin(Brk.TabPage page) {
        Object(page: page);
    }
}

public sealed class Brk.TabPage : GLib.Object {
    internal Brk.TabPageTab tab;
    internal Brk.TabPageBin bin;

//    internal GLib.WeakRef last_focus;

    /**
     * The child widget that this page wraps.
     */
    public Gtk.Widget child { get; construct; }

    /**
     * The tab that this page was created from.
     *
     * As an example, if you were to follow a hyperlink on a page then the new
     * page would be a child of the original one and would be inserted
     * immediately after it.
     */
    public Brk.TabPage parent { get; construct; }

    /**
     * Will be set if this tab page is the currently selected page in its containing
     * view.
     */
    public bool selected { get; internal set; }

    /**
     * Human readable title that will be displayed in the page's tab.
     */
    public string title { get; set; }

    /**
     * Human readable tooltip that will be displayed when a user mouses over
     * the page's tab.
     *
     * Text is encoded using the Pango text markup language.
     */
    public string tooltip { get; set; }

    /**
     * An icon that should be displayed in the page's tab.
     */
    public GLib.Icon? icon { get; set; }

    /**
     * Whether the page is loading.
     *
     * If set to ``TRUE``, the tab will display a spinner in place of the
     * page's icon.
     */
    public bool loading { get; set; }

    public bool closing { get; internal set; }

    public Gdk.Drag drag { get; internal set; }

    public static Brk.TabPage?
    get_for_drag(Gdk.Drag drag) {
        try {
            var val = new GLib.Value(typeof(Brk.TabPage));
            drag.content.get_value(ref val);
            return val.get_object() as Brk.TabPage;
        } catch {
            return null;
        }
    }

    // This is needed to workaround a race where a tab can be dragged to a new
    // bar before the motion controller of the original bar is notified.  It
    // should, ideally, not be used for anything else.
    internal unowned Brk.TabView? drag_source;

    // The offset of the mouse in the tab at drag start.
    internal double drag_tab_offset;
    // The current offset of the mouse in the tab bar.
    internal double drag_bar_offset;

    /**
     * An indicator icon for the page.
     *
     * A common use case isan audio or camera indicator in a web browser.
     *
     * This will be shown it at the beginning of the tab, alongside the icon
     * representing [property@TabPage:icon] or loading spinner.
     *
     * [property@TabPage:indicator-tooltip] can be used to set the tooltip on the
     * indicator icon.
     *
     * If [property@TabPage:indicator-activatable] is set to `TRUE`, the
     * indicator icon can act as a button.
     */
    public GLib.Icon? indicator_icon { get; set; }

    /**
     * Human readable tooltip that will be displayed when a user mouses over
     * the indicator icon in this page's tab.
     *
     * Text is encoded using the Pango text markup language.
     */
    public string indicator_tooltip { get; set; }

    /**
     * Whether the indicator icon is activatable.
     *
     * If set to `TRUE`, [signal@TabView::indicator-activated] will be emitted
     * when the indicator icon is clicked.
     *
     * Does nothing if [property@TabPage:indicator-icon] is not set.
     */
    public bool indicator_activatable { get; set; }

    /**
     * Whether the page needs attention.
     *
     * This will cause a line to be displayed under the tab representing the
     * page if set to `TRUE`. If the tab is not visible, the corresponding edge
     * of the tab bar will be highlighted.
     */
    public bool needs_attention { get; set; }

    internal signal void close();
    internal signal void focus();

    construct {
        this.tab = new Brk.TabPageTab(this);
        this.bin = new Brk.TabPageBin(this);
    }

    public override void
    dispose() {
        this.tab = null;
        this.bin = null;
    }

    internal TabPage(Gtk.Widget child) {
        Object(child: child);
    }
}

[GtkTemplate (ui = "/com/bwhmather/Bricks/ui/brk-tab-page-drag-view.ui")]
private sealed class Brk.TabPageDragView : Gtk.Widget {
    public Brk.TabPage page { get; construct; }

    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("tab-drag");
    }

    construct {
        assert(!page.drag_source.has_page(page));

        this.page.selected = true;
        this.page.bin.set_parent(this);
    }

    internal
    TabPageDragView(Brk.TabPage page) {
        Object(page: page);
    }

    public override void
    dispose() {
        assert(!page.drag_source.has_page(page));

        this.page.selected = false;
        this.page.bin.unparent();

        this.dispose_template(typeof(Brk.TabPageDragView));
    }
}

private sealed class Brk.TabViewTabs : Gtk.Widget {
    public unowned Brk.TabView view { get; construct; }

    private Gtk.Button left_button;
    private Gtk.Button right_button;

    private Gtk.Adjustment adjustment = new Gtk.Adjustment(0, 0, 0, 1, 1, 0);

    private void
    acquire_drag(Gdk.Drag drag, double x, double y) {
        var page = Brk.TabPage.get_for_drag(drag);
        if (page == null) {
            return;
        }
        page.drag_bar_offset = x;
        this.queue_allocate();
        if (this.view.has_page(page)) {
            return;
        }

        var drag_icon = Gtk.DragIcon.get_for_drag(drag) as Gtk.DragIcon;
        drag_icon.child = new Gtk.Label(".");  // TODO old icon won't be replaced if fully transparent...

        this.view.attach_page(page);
        this.view.selected_page = page;
    }

    private void
    release_drag(Gdk.Drag drag) {
        var page = Brk.TabPage.get_for_drag(drag);
        if (page == null) {
            return;
        }
        if (!this.view.has_page(page)) {
            return;
        }
        if (page.drag != drag) {
            return;
        }
        this.view.detach_page(page);

        var drag_icon = Gtk.DragIcon.get_for_drag(drag) as Gtk.DragIcon;
        drag_icon.child = new Brk.TabPageDragView(page);
    }

    static construct {
        set_css_name("tabs");
        set_accessible_role(TAB_LIST);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.HORIZONTAL, -1);

        this.hexpand = true;

        this.left_button = new Gtk.Button.from_icon_name("go-previous-symbolic");
        this.left_button.add_css_class("navigation-button");
        this.left_button.add_css_class("left");
        this.left_button.insert_before(this, null);

        this.right_button = new Gtk.Button.from_icon_name("go-next-symbolic");
        this.right_button.add_css_class("navigation-button");
        this.right_button.add_css_class("right");
        this.right_button.insert_after(this, null);

        this.view.pages.items_changed.connect((position, removed, added) => {
            Gtk.Widget? next = this.get_first_child();
            for (var i = 0; i < position; i++) {
                next = next.get_next_sibling();
            }

            for (var i = 0; i < removed; i++) {
                var target = next;
                next = next.get_next_sibling();
                target.unparent();
            }

            for (var i = 0; i < added; i++) {
                var page = this.view.pages.get_item(position + i) as Brk.TabPage;
                page.tab.insert_before(this, next);
            }
        });

        this.view.page_attached.connect((page) => {
            page.notify["drag"].connect((p, pspec) => {
                if (((Brk.TabPage) p).drag != null) {
                    this.release_drag(((Brk.TabPage) p).drag);
                }
            });
        });
        this.view.page_detached.connect((page) => {
            GLib.SignalHandler.disconnect_by_data(page, this);
        });

        var drop_controller = new Gtk.DropTargetAsync(
            new Gdk.ContentFormats.for_gtype(typeof(Brk.TabPage)), MOVE | COPY | LINK | ASK
        );
        drop_controller.drag_enter.connect((dc, drop, x, y) => {
            var drag = drop.drag;
            this.acquire_drag(drag, x, y);
            return MOVE;
        });
        drop_controller.drag_leave.connect((dc, drop) => {
            var drag = drop.drag;
            this.release_drag(drag);
        });
        drop_controller.drag_motion.connect((dc, drop, x, y) => {
            var drag = drop.drag;
            this.acquire_drag(drag, x, y);
            return MOVE;
        });
        drop_controller.drop.connect((dc, drop, x, y) => {
            // TODO figure out if I had a good reason for not including this bit:
          //  var drag = drop.drag;
          //  this.acquire_drag(drag, x, y);

            var page = Brk.TabPage.get_for_drag(drop.drag);
            page.drag = null;

            var expected = drop.get_actions();
            drop.finish(COPY);  // TODO
            return true;
        });
        this.add_controller(drop_controller);

        var scroll_controller = new Gtk.EventControllerScroll(HORIZONTAL | KINETIC);
        scroll_controller.scroll.connect((dx, dy) => {
            this.adjustment.value += dx;
            this.queue_allocate();
            return true;
        });
        this.add_controller(scroll_controller);
    }

    public TabViewTabs(Brk.TabView view) {
        Object(view: view);
    }

    public override void
    measure(
        Gtk.Orientation orientation,
        int for_size,
        out int minimum,
        out int natural,
        out int minimum_baseline,
        out int natural_baseline
    ) {
        if (orientation == HORIZONTAL) {
            int child_minimum, child_natural;

            // At minimum width just the scroll buttons will be show.  All tabs will be hidden.
            minimum = 0;

            this.left_button.measure(
                orientation, for_size,
                out child_minimum, out child_natural,
                null, null
            );
            minimum += child_minimum;

            this.right_button.measure(
                orientation, for_size,
                out child_minimum, out child_natural,
                null, null
            );
            minimum += child_minimum;

            // At natural width, scroll buttons are hidden and all tabs are expanded to their
            // own natural width.
            natural = 0;

            for (var i = 0; i < this.view.n_pages; i++) {
                var page = this.view.get_page(i);
                var child = page.tab;

                child.measure(
                    orientation, for_size,
                    out child_minimum, out child_natural,
                    null, null
                );
                natural += child_natural;
            }

            if (natural < minimum) {
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        } else {
            int child_minimum, child_natural;

            minimum = 0;
            natural = 0;

            this.left_button.measure(
                orientation, for_size,
                out child_minimum, out child_natural,
                null, null
            );
            if (child_minimum > minimum) {
                minimum = child_minimum;
            }
            if (child_natural > natural) {
                natural = child_natural;
            }

            this.right_button.measure(
                orientation, for_size,
                out child_minimum, out child_natural,
                null, null
            );
            if (child_minimum > minimum) {
                minimum = child_minimum;
            }
            if (child_natural > natural) {
                natural = child_natural;
            }


            for (var i = 0; i < this.view.n_pages; i++) {
                var page = this.view.get_page(i);
                var child = page.tab;

                child.measure(
                    orientation, for_size,
                    out child_minimum, out child_natural,
                    null, null
                );

                if (child_minimum > minimum) {
                    minimum = child_minimum;
                }
                if (child_natural > natural) {
                    natural = child_natural;
                }
            }
            minimum_baseline = -1;
            natural_baseline = -1;
        }
    }

    public override void
    size_allocate (int width, int height, int baseline) {
        // The tab bar will progress through three modes as tabs are added:
        //  - Expanded mode: Not enought tabs to reach all the way across the
        //    bar.  Tabs will be expanded to their natural width.
        //  - Fill mode: There are enough tabs to reach all the way across the
        //    bar if expanded to their natural width, but there is still enough
        //    space to fit them at their minimum width.  The tabs will be
        //    shrunk to exactly fit the bar with extra space being allocated in
        //    proportion to the difference between minimum and natural widths
        //    of each tab.
        //  - Overflow mode: Not all tabs can fit in the tab bar.  All tabs
        //    will be shrunk to their minimum width and scroll buttons will be
        //    added to the beginning and end of the bar.

        // Figure out the minimum and natural width of all tabs in the bar.
        int minimum = 0;
        int natural = 0;
        int num_tabs = 0;
        for (var i = 0; i < this.view.n_pages; i++) {
            var page = this.view.get_page(i);
            var child = page.tab;

            int child_minimum, child_natural;
            child.measure(
                HORIZONTAL, height,
                out child_minimum, out child_natural,
                null, null
            );
            minimum += child_minimum;
            natural += child_natural;
            num_tabs += 1;
        }
        if (num_tabs == 0) {
            return;
        }

        // Figure out how much space the tabs should actually get.  In overflow
        // mode this will be greater than the actual amount of space on the bar.
        int allocated = natural;
        bool overflowing = false;
        if (width < allocated) {
            // Shrink to fit available space.
            allocated = width;
        }
        if (minimum > allocated) {
            // Tabs don't fit in available space.  Trigger overflow mode.
            allocated = minimum;
            overflowing = true;
        }

        // If necessary, we now allocate space for the navigation buttons.
        int left_button_width = 0;
        int right_button_width = 0;
        if (overflowing) {
            this.left_button.measure(
                HORIZONTAL, height,
                out left_button_width, null,
                null, null
            );
            Gsk.Transform transform = null;
            this.left_button.allocate(left_button_width, height, baseline, transform);

            this.right_button.measure(
                HORIZONTAL, height,
                out right_button_width, null,
                null, null
            );
            transform = null;
            transform = transform.translate({width - right_button_width, 0});
            this.right_button.allocate(right_button_width, height, baseline, transform);
        }

        this.adjustment.upper = allocated;
        this.adjustment.page_size = width - left_button_width - right_button_width;

        // Tabs.
        Gsk.Transform transform = null;
        transform = transform.translate({(float)(left_button_width - adjustment.value), 0});

        int requested_slack = natural - minimum;
        int remaining_slack = allocated - minimum;

        // This is where we handle reordering dragged tabs.  Only the tab of the
        // view's selected page will be reordered.  The insertion point is
        // chosen to minimize the distance between the anchor point on the tab
        // and the position of the cursor.  Changing the insertion point will
        // queue up another allocation, but this _should_ be a no-op.
        Brk.TabPage? drag_page = null;
        if (this.view.selected_page.drag != null) {
            drag_page = this.view.selected_page;

            // Horizontal offset of the cursor inside the tab at drag start.
            double drag_tab_offset = drag_page.drag_tab_offset;
            // Current horizontal offset of the cursor inside the tab bar.
            double drag_bar_offset = drag_page.drag_bar_offset;;
            // The ideal offset of the tab from the beginning of the list of
            // tabs after scrolling applied.
            double drag_target_offset =
                drag_bar_offset -
                drag_tab_offset +
                adjustment.value -
                left_button_width;

            double drag_candidate_offset = 0;
            for (var i = 0; i < this.view.n_pages; i++) {
                var page = this.view.get_page(i);
                if (page == drag_page) {
                    continue;
                }

                var child = page.tab;

                int child_minimum, child_natural;
                child.measure(
                    HORIZONTAL, height,
                    out child_minimum, out child_natural,
                    null, null
                );

                int child_slack = 0;
                if (requested_slack != 0) {
                    child_slack += child_natural - child_minimum;
                    child_slack *= remaining_slack; // TODO overflow likely.
                    child_slack /= requested_slack;

                    requested_slack -= (child_natural - child_minimum);
                    remaining_slack -= child_slack;
                }
                int child_width = child_minimum + child_slack;


                double next_candidate_offset = drag_candidate_offset + child_width;

                if ((drag_target_offset - next_candidate_offset).abs() > (drag_target_offset - drag_candidate_offset).abs()) {
                    this.view.reorder_page_before(drag_page, page);
                    break;
                }

                if (i + 1 == this.view.n_pages) {
                    this.view.reorder_page_after(drag_page, page);
                    break;
                }


                drag_candidate_offset = next_candidate_offset;
            }
        }

        for (var i = 0; i < this.view.n_pages; i++) {
            var page = this.view.get_page(i);
            var child = page.tab;

            int child_minimum, child_natural;
            child.measure(
                HORIZONTAL, height,
                out child_minimum, out child_natural,
                null, null
            );

            int child_slack = 0;
            if (requested_slack != 0) {
                child_slack += child_natural - child_minimum;
                child_slack *= remaining_slack; // TODO overflow likely.
                child_slack /= requested_slack;

                requested_slack -= (child_natural - child_minimum);
                remaining_slack -= child_slack;
            }
            int child_width = child_minimum + child_slack;

            if (page == drag_page) {
                var drag_transform = new Gsk.Transform().translate({
                    (float)(drag_page.drag_bar_offset - drag_page.drag_tab_offset),
                    0
                });
                child.allocate(child_width, height, baseline, drag_transform);
            } else {
                child.allocate(child_width, height, baseline, transform);
            }
            transform = transform.translate({child_width, 0});
        }
    }

    private void
    snapshot_tabs(Gtk.Snapshot snapshot) {
        for (var i = 0; i < this.view.n_pages; i++) {
            var page = this.view.get_page(i);
            var child = page.tab;
            this.snapshot_child(child, snapshot);
        }
    }

    public override void
    snapshot(Gtk.Snapshot snapshot) {
        double tabs_offset = this.adjustment.value;
        double tabs_window = this.adjustment.page_size;
        double tabs_width = this.adjustment.upper;

        bool overflow_left = tabs_offset > 0;
        bool overflow_right = tabs_offset + tabs_width > tabs_window;

        if (overflow_left || overflow_right) {
            var fade_overlap = 10;
            var fade_width = 20;

            // Figure out how much room is left for rendering tabs after buttons
            // are allocated.
            Graphene.Rect bounds;
            var ok = this.left_button.compute_bounds(this, out bounds);
            return_if_fail(ok);
            var left = bounds.get_x() + bounds.get_width() - fade_overlap;

            ok = this.right_button.compute_bounds(this, out bounds);
            return_if_fail(ok);
            var right = bounds.get_x() + fade_overlap;

            snapshot.push_clip(Graphene.Rect().init(left, 0, right - left, this.get_height()));
            snapshot.push_mask(INVERTED_ALPHA);
            if (overflow_left) {
                snapshot.append_linear_gradient(
                    Graphene.Rect().init(left, 0, fade_width, this.get_height()),
                    Graphene.Point().init(left, 0),
                    Graphene.Point().init(left + fade_width, 0),
                    {
                        {0,{0,0,0,1}},
                        {1,{0,0,0,0}},
                    }
                );
            }
            if (overflow_right) {
                snapshot.append_linear_gradient(
                    Graphene.Rect().init(right - fade_width, 0, fade_width, this.get_height()),
                    Graphene.Point().init(right, 0),
                    Graphene.Point().init(right - fade_width, 0),
                    {
                        {0,{0,0,0,1}},
                        {1,{0,0,0,0}},
                    }
                );
            }
            snapshot.pop();  // Pop mask.

            this.snapshot_tabs(snapshot);

            snapshot.pop();  // Pop mask contents.
            snapshot.pop();  // Pop clip.

            this.snapshot_child(this.left_button, snapshot);
            this.snapshot_child(this.right_button, snapshot);
        } else {
            this.snapshot_tabs(snapshot);
        }
    }
}

private sealed class Brk.TabViewBar : Gtk.Widget {
    public unowned Brk.TabView view { get; construct; }

    private Brk.TabViewTabs tabs;

    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("tabbar");
        set_accessible_role(GROUP);
    }

    construct {
        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.HORIZONTAL, -1);

        this.hexpand = true;

        this.tabs = new Brk.TabViewTabs(this.view);
        this.tabs.insert_after(this, null);
    }

    public TabViewBar(Brk.TabView view) {
        Object(view: view);
    }
}

private sealed class Brk.TabViewStack : Gtk.Widget {
    public unowned Brk.TabView view { get; construct; }

    static construct {
        set_css_name("tabpages");
    }

    construct {
        this.view.pages.items_changed.connect((position, removed, added) => {
            Gtk.Widget? next = this.get_first_child();
            for (var i = 0; i < position; i++) {
                next = next.get_next_sibling();
            }

            for (var i = 0; i < removed; i++) {
                var target = next;
                next = next.get_next_sibling();
                target.unparent();
            }

            for (var i = 0; i < added; i++) {
                var page = this.view.pages.get_item(position + i) as Brk.TabPage;
                page.bin.insert_before(this, next);
            }
        });

        this.view.notify["selected-page"].connect((v, pspec) => {
            if (this.in_destruction()) {
                return;
            }

            for (var child = this.get_first_child(); child != null; child = child.get_next_sibling()) {
                child.set_child_visible(child == this.view.selected_page.bin);
            }

            this.queue_allocate();
        });
    }

    internal TabViewStack(Brk.TabView view) {
        Object(view: view);
    }

    public override bool
    focus(Gtk.DirectionType direction) {
        if (this.view.selected_page == null) {
            return false;
        }

        // TODO restore focus.
        return this.view.selected_page.bin.focus(direction);
    }

    public override void
    measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
        minimum = 0;
        natural = 0;

        for (var child = this.get_first_child(); child != null; child = child.get_next_sibling()) {
            int child_minimum, child_natural;
            child.measure(
                orientation, for_size,
                out child_minimum, out child_natural,
                null, null
            );

            if (child_minimum > minimum) {
                minimum = child_minimum;
            }
            if (child_natural > natural) {
                natural = child_natural;
            }
        }
        minimum_baseline = -1;
        natural_baseline = -1;
    }

    public override void
    size_allocate (int width, int height, int baseline) {
        for (var child = this.get_first_child(); child != null; child = child.get_next_sibling()) {
            if (child.get_child_visible()) {
                child.allocate(width, height, baseline, null);
            }
        }
    }

    public override void
    snapshot(Gtk.Snapshot snapshot) {
        if (this.view.selected_page != null) {
            this.snapshot_child(this.view.selected_page.bin, snapshot);
        }
    }

    public override Gtk.SizeRequestMode
    get_request_mode() {
        return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
    }

    public override void
    compute_expand_internal(out bool hexpand, out bool vexpand) {
        hexpand = true;
        vexpand = true;
    }
}

public sealed class Brk.TabView : Gtk.Widget {
    private GLib.ListStore page_list;

    private Brk.TabViewBar bar;
    private Brk.TabViewStack stack;

    /**
     * The number of pages in the tab view.
     */
    public uint n_pages { get { return this.page_list.n_items; } }

    public GLib.ListModel pages { get { return page_list; } }

    public Brk.TabPage
    get_page(uint i) {
        return this.page_list.get_item(i) as Brk.TabPage;
    }

    public bool
    has_page(Brk.TabPage target) {
        for (var i = 0; i < this.n_pages; i++) {
            var candidate = this.get_page(i);
            if (candidate == target) {
                return true;
            }
        }
        return false;
    }

    internal uint
    get_page_position(Brk.TabPage page) {
        for (var i = 0; i < this.n_pages; i++) {
            var candidate = this.get_page(i);
            if (candidate == page) {
                return i;
            }
        }
        assert(false);
        return 0;
    }

    /**
     * The currently visible page.
     */
    public Brk.TabPage? selected_page { get; set; }

    /**
     * Whether a page is being transferred.
     *
     * This property will be set to `TRUE` when a drag-n-drop tab transfer starts
     * on any `BrkTabView`, and to `FALSE` after it ends.
     *
     * During the transfer, children cannot receive pointer input and a tab can
     * be safely dropped on the tab view.
     */
    public bool is_transferring_page { get; private set; }

    /**
     * Tab context menu model.
     *
     * When a context menu is shown for a tab, it will be constructed from the
     * provided menu model. Use the [signal@TabView::setup-menu] signal to set up
     * the menu actions for the particular tab.
     */
    public GLib.MenuModel menu_model { get; set; }

    /**
     * Requests to close page.
     *
     * Calling this function will result in the [signal@TabView::close-page] signal
     * being emitted for @page. Closing the page can then be confirmed or
     * denied via [method@TabView.close_page_finish].
     *
     * If the page is waiting for a [method@TabView.close_page_finish] call, this
     * function will do nothing.
     *
     * The default handler for [signal@TabView::close-page] will immediately confirm
     * closing the page. This behavior can be changed by registering your own
     * handler for that signal.
     *
     * If @page was selected, another page will be selected instead:
     *
     * If the [property@TabPage:parent] value is `NULL`, the next page will be
     * selected when possible, or if the page was already last, the previous page
     * will be selected instead.
     *
     * If it's not `NULL`, the previous page will be selected if it's a descendant
     * (possibly indirect) of the parent.
     */
    public signal bool close_page(Brk.TabPage page);

    /**
     * Emitted when a tab should be transferred into a new window.
     *
     * This can happen after a tab has been dropped on desktop.
     *
     * The signal handler is expected to create a new window, position it as
     * needed and return its `BrkTabView` that the page will be transferred into.
     */
    public signal unowned Brk.TabView? create_window();
    public signal void indicator_activated(Brk.TabPage page);
    public signal void page_attached(Brk.TabPage page);
    public signal void page_detached(Brk.TabPage page);
    public signal void setup_menu(Brk.TabPage? page);

    private void
    select_prev_page() {
        var target = this.get_page_position(this.selected_page);
        if (target == 0) {
            target = this.page_list.n_items;
        }
        target -= 1;
        this.selected_page = this.get_page(target);
    }

    private void
    select_next_page() {
        var target = this.get_page_position(this.selected_page);
        target += 1;
        if (target >= this.page_list.n_items) {
            target = 0;
        }
        this.selected_page = this.get_page(target);
    }

    static construct {
        set_layout_manager_type(typeof (Gtk.BoxLayout));
        set_css_name("tabview");
    }

    construct {
        var shortcut_controller = new Gtk.ShortcutController();
        shortcut_controller.propagation_phase = CAPTURE;
        shortcut_controller.scope = GLOBAL;
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("<Control><Shift>Tab"),
            new Gtk.CallbackAction((v, args) => { this.select_prev_page(); return true; })
        ));
        shortcut_controller.add_shortcut(new Gtk.Shortcut(
            Gtk.ShortcutTrigger.parse_string("<Control>Tab"),
            new Gtk.CallbackAction((v, args) => { this.select_next_page(); return true; })
        ));
        this.add_controller(shortcut_controller);

        this.page_list = new GLib.ListStore(typeof(Brk.TabPage));
        this.page_list.notify["n-items"].connect((l, pspec) => { this.notify_property("n-pages"); });

        this.notify["selected-page"].connect((s, pspec) => {
            for (var i = 0; i < this.n_pages; i++) {
                var page = this.get_page(i);
                page.selected = page == this.selected_page;
            }
        });

        this.update_property(Gtk.AccessibleProperty.ORIENTATION, Gtk.Orientation.VERTICAL, -1);

        var layout_manager = this.layout_manager as Gtk.BoxLayout;
        layout_manager.orientation = VERTICAL;

        this.bar = new Brk.TabViewBar(this);
        this.bar.insert_before(this, null);

        this.stack = new Brk.TabViewStack(this);
        this.stack.insert_before(this, null);
    }

    internal void
    attach_page(Brk.TabPage page) {
        if (page.drag_source != null) {
            assert(!page.drag_source.has_page(page));
        }

        // TODO position should depend on parent, on the existing children of
        // the parent, and probably on lots of other subtle things.
        uint index = this.page_list.n_items;
        this.page_list.insert(index, page);

        page.close.connect((p) => this.close_page(p));
        page.focus.connect((p) => { this.selected_page = p; });

        page.drag_source = this;
        this.page_attached(page);

        if (this.page_list.n_items == 1) {
            this.selected_page = page;
        }
    }

    internal void
    detach_page(Brk.TabPage page) {
        uint position;
        return_if_fail(this.page_list.find(page, out position));
        if (this.selected_page == page) {
            if (this.n_pages == 1) {
                this.selected_page = null;
            } else if (position == this.n_pages - 1) {
                this.selected_page = this.get_page(position - 1);
            } else {
                this.selected_page = this.get_page(position + 1);
            }
        }
        GLib.SignalHandler.disconnect_by_data(page, this);
        this.page_list.remove(position);
        this.page_detached(page);
    }

    public unowned Brk.TabPage
    add_page(Gtk.Widget child, Brk.TabPage? parent) {
        return_val_if_fail(child.parent == null, null);

        var page = new Brk.TabPage(child);
        this.attach_page(page);

        unowned Brk.TabPage reference = page;
        return reference;
    }

    internal bool
    reorder_page_after(Brk.TabPage page, Brk.TabPage target) {
        return_val_if_fail(page != target, false);

        var page_position = this.get_page_position(page);
        var target_position = this.get_page_position(target);

        if (page_position == target_position + 1) {
            return false;
        }
        if (page_position < target_position) {
            target_position -= 1;
        }
        this.page_list.remove(page_position);
        this.page_list.insert(target_position + 1, page);
        return true;
    }

    internal bool
    reorder_page_before(Brk.TabPage page, Brk.TabPage target) {
        return_val_if_fail(page != target, false);

        var page_position = this.get_page_position(page);
        var target_position = this.get_page_position(target);
        if (page_position < target_position) {
            target_position -= 1;
        }
        this.page_list.remove(page_position);
        this.page_list.insert(target_position, page);
        return true;
    }
    /**
     * Transfers @page from @self to @other_view.
     *
     * The @page object will be reused.
     */
    public void
    transfer_page(Brk.TabPage page, Brk.TabView other_view) {
        this.detach_page(page);
        other_view.attach_page(page);
    }

    /**
     * Completes a [method:@TabView.close_page] call for @page.
     *
     * If @confirm is `TRUE`, @page will be closed.  If it's `FALSE`, it will be
     * reverted to its previous state and [method@TabView.close_page] can be called
     * for it again.
     *
     * This functions should not be called unless a custom handler for
     * [signal@TabView::close-page] is used.
     */
    public void
    close_page_finish(Brk.TabPage page, bool should_close) {
        page.closing = false;
        if (!should_close) {
            return;
        }

        this.detach_page(page);
    }
}
