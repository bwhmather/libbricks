#include <config.h>

#include "brk-tab-view.h"

#include <gdk/gdk.h>
#include <gio/gio.h>
#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-bin.h"
#include "brk-enums.h"
#include "brk-marshalers.h"
#include "brk-tab-view-private.h"
#include "brk-widget-utils-private.h"

struct _BrkTabPage {
    GObject parent_instance;

    GtkWidget *bin;
    GtkWidget *child;
    BrkTabPage *parent;
    gboolean selected;
    char *title;
    char *tooltip;
    GIcon *icon;
    gboolean loading;
    GIcon *indicator_icon;
    char *indicator_tooltip;
    gboolean indicator_activatable;
    gboolean needs_attention;
    char *keyword;

    GtkWidget *last_focus;
    GBinding *transfer_binding;

    GtkATContext *at_context;

    gboolean closing;

    gboolean in_destruction;
};

static void
brk_tab_page_buildable_init(GtkBuildableIface *iface);
static void
brk_tab_page_accessible_init(GtkAccessibleInterface *iface);

G_DEFINE_FINAL_TYPE_WITH_CODE(
    BrkTabPage, brk_tab_page, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, brk_tab_page_buildable_init)
        G_IMPLEMENT_INTERFACE(GTK_TYPE_ACCESSIBLE, brk_tab_page_accessible_init)
)

static GtkBuildableIface *tab_page_parent_buildable_iface;

enum {
    PAGE_PROP_0,
    PAGE_PROP_CHILD,
    PAGE_PROP_PARENT,
    PAGE_PROP_SELECTED,
    PAGE_PROP_TITLE,
    PAGE_PROP_TOOLTIP,
    PAGE_PROP_ICON,
    PAGE_PROP_LOADING,
    PAGE_PROP_INDICATOR_ICON,
    PAGE_PROP_INDICATOR_TOOLTIP,
    PAGE_PROP_INDICATOR_ACTIVATABLE,
    PAGE_PROP_NEEDS_ATTENTION,
    PAGE_PROP_KEYWORD,
    LAST_PAGE_PROP,
    PAGE_PROP_ACCESSIBLE_ROLE
};

static GParamSpec *page_props[LAST_PAGE_PROP];



static void
set_page_selected(BrkTabPage *self, gboolean selected) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    selected = !!selected;

    if (self->selected == selected)
        return;

    self->selected = selected;

    g_object_notify_by_pspec(G_OBJECT(self), page_props[PAGE_PROP_SELECTED]);
}

static void
set_page_parent(BrkTabPage *self, BrkTabPage *parent);

static void
page_parent_notify_cb(BrkTabPage *self) {
    BrkTabPage *grandparent = brk_tab_page_get_parent(self->parent);

    self->parent = NULL;

    if (grandparent)
        set_page_parent(self, grandparent);
    else
        g_object_notify_by_pspec(G_OBJECT(self), props[PAGE_PROP_PARENT]);
}

static void
set_page_parent(BrkTabPage *self, BrkTabPage *parent) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));
    g_return_if_fail(parent == NULL || BRK_IS_TAB_PAGE(parent));

    if (self->parent == parent)
        return;

    if (self->parent)
        g_object_weak_unref(G_OBJECT(self->parent), (GWeakNotify) page_parent_notify_cb, self);

    self->parent = parent;

    if (self->parent)
        g_object_weak_ref(G_OBJECT(self->parent), (GWeakNotify) page_parent_notify_cb, self);

    g_object_notify_by_pspec(G_OBJECT(self), props[PAGE_PROP_PARENT]);
}

static void
brk_tab_page_dispose(GObject *object) {
    BrkTabPage *self = BRK_TAB_PAGE(object);

    self->in_destruction = TRUE;

    set_page_parent(self, NULL);

    g_clear_object(&self->at_context);

    g_clear_object(&self->bin);

    G_OBJECT_CLASS(brk_tab_page_parent_class)->dispose(object);
}

static void
brk_tab_page_finalize(GObject *object) {
    BrkTabPage *self = (BrkTabPage *) object;

    g_clear_object(&self->child);
    g_clear_pointer(&self->title, g_free);
    g_clear_pointer(&self->tooltip, g_free);
    g_clear_object(&self->icon);
    g_clear_object(&self->indicator_icon);
    g_clear_pointer(&self->indicator_tooltip, g_free);
    g_clear_pointer(&self->keyword, g_free);
    g_clear_weak_pointer(&self->last_focus);

    G_OBJECT_CLASS(brk_tab_page_parent_class)->finalize(object);
}

static void
brk_tab_page_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec) {
    BrkTabPage *self = BRK_TAB_PAGE(object);

    switch (prop_id) {
    case PAGE_PROP_CHILD:
        g_value_set_object(value, brk_tab_page_get_child(self));
        break;

    case PAGE_PROP_PARENT:
        g_value_set_object(value, brk_tab_page_get_parent(self));
        break;

    case PAGE_PROP_SELECTED:
        g_value_set_boolean(value, brk_tab_page_get_selected(self));
        break;

    case PAGE_PROP_TITLE:
        g_value_set_string(value, brk_tab_page_get_title(self));
        break;

    case PAGE_PROP_TOOLTIP:
        g_value_set_string(value, brk_tab_page_get_tooltip(self));
        break;

    case PAGE_PROP_ICON:
        g_value_set_object(value, brk_tab_page_get_icon(self));
        break;

    case PAGE_PROP_LOADING:
        g_value_set_boolean(value, brk_tab_page_get_loading(self));
        break;

    case PAGE_PROP_INDICATOR_ICON:
        g_value_set_object(value, brk_tab_page_get_indicator_icon(self));
        break;

    case PAGE_PROP_INDICATOR_TOOLTIP:
        g_value_set_string(value, brk_tab_page_get_indicator_tooltip(self));
        break;

    case PAGE_PROP_INDICATOR_ACTIVATABLE:
        g_value_set_boolean(value, brk_tab_page_get_indicator_activatable(self));
        break;

    case PAGE_PROP_NEEDS_ATTENTION:
        g_value_set_boolean(value, brk_tab_page_get_needs_attention(self));
        break;

    case PAGE_PROP_KEYWORD:
        g_value_set_string(value, brk_tab_page_get_keyword(self));
        break;

    case PAGE_PROP_ACCESSIBLE_ROLE:
        g_value_set_enum(value, GTK_ACCESSIBLE_ROLE_TAB_PANEL);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_tab_page_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec) {
    BrkTabPage *self = BRK_TAB_PAGE(object);

    switch (prop_id) {
    case PAGE_PROP_CHILD:
        g_set_object(&self->child, g_value_get_object(value));
        brk_bin_set_child(BRK_BIN(self->bin), g_value_get_object(value));
        break;

    case PAGE_PROP_PARENT:
        set_page_parent(self, g_value_get_object(value));
        break;

    case PAGE_PROP_TITLE:
        brk_tab_page_set_title(self, g_value_get_string(value));
        break;

    case PAGE_PROP_TOOLTIP:
        brk_tab_page_set_tooltip(self, g_value_get_string(value));
        break;

    case PAGE_PROP_ICON:
        brk_tab_page_set_icon(self, g_value_get_object(value));
        break;

    case PAGE_PROP_LOADING:
        brk_tab_page_set_loading(self, g_value_get_boolean(value));
        break;

    case PAGE_PROP_INDICATOR_ICON:
        brk_tab_page_set_indicator_icon(self, g_value_get_object(value));
        break;

    case PAGE_PROP_INDICATOR_TOOLTIP:
        brk_tab_page_set_indicator_tooltip(self, g_value_get_string(value));
        break;

    case PAGE_PROP_INDICATOR_ACTIVATABLE:
        brk_tab_page_set_indicator_activatable(self, g_value_get_boolean(value));
        break;

    case PAGE_PROP_NEEDS_ATTENTION:
        brk_tab_page_set_needs_attention(self, g_value_get_boolean(value));
        break;

    case PAGE_PROP_KEYWORD:
        brk_tab_page_set_keyword(self, g_value_get_string(value));
        break;

    case PAGE_PROP_ACCESSIBLE_ROLE:
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_tab_page_class_init(BrkTabPageClass *klass) {
    GObjectClass *object_class = G_OBJECT_CLASS(klass);

    object_class->dispose = brk_tab_page_dispose;
    object_class->finalize = brk_tab_page_finalize;
    object_class->get_property = brk_tab_page_get_property;
    object_class->set_property = brk_tab_page_set_property;

    /**
     * BrkTabPage:child: (attributes org.gtk.Property.get=brk_tab_page_get_child)
     *
     * The child of the page.
     */
    page_props[PAGE_PROP_CHILD] = g_param_spec_object(
        "child", NULL, NULL, GTK_TYPE_WIDGET,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS
    );

    /**
     * BrkTabPage:parent: (attributes org.gtk.Property.get=brk_tab_page_get_parent)
     *
     * The parent page of the page.
     *
     * See [method@TabView.add_page] and [method@TabView.close_page].
     */
    page_props[PAGE_PROP_PARENT] = g_param_spec_object(
        "parent", NULL, NULL, BRK_TYPE_TAB_PAGE,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS |
            G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:selected: (attributes org.gtk.Property.get=brk_tab_page_get_selected)
     *
     * Whether the page is selected.
     */
    page_props[PAGE_PROP_SELECTED] = g_param_spec_boolean(
        "selected", NULL, NULL, FALSE, G_PARAM_READABLE | G_PARAM_STATIC_STRINGS
    );

    /**
     * BrkTabPage:title: (attributes org.gtk.Property.get=brk_tab_page_get_title org.gtk.Property.set=brk_tab_page_set_title)
     *
     * The title of the page.
     *
     * [class@TabBar] will display it in the center of the tab and will use it as
     * a tooltip unless [property@TabPage:tooltip] is set.
     */
    page_props[PAGE_PROP_TITLE] = g_param_spec_string(
        "title", NULL, NULL, "",
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:tooltip: (attributes org.gtk.Property.get=brk_tab_page_get_tooltip org.gtk.Property.set=brk_tab_page_set_tooltip)
     *
     * The tooltip of the page.
     *
     * The tooltip can be marked up with the Pango text markup language.
     *
     * If not set, [class@TabBar] will use [property@TabPage:title] as a tooltip
     *instead.
     */
    page_props[PAGE_PROP_TOOLTIP] = g_param_spec_string(
        "tooltip", NULL, NULL, "",
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:icon: (attributes org.gtk.Property.get=brk_tab_page_get_icon org.gtk.Property.set=brk_tab_page_set_icon)
     *
     * The icon of the page.
     *
     * [class@TabBar] displays the icon next to the title, unless
     * [property@TabPage:loading] is set to `TRUE`.
     */
    page_props[PAGE_PROP_ICON] = g_param_spec_object(
        "icon", NULL, NULL, G_TYPE_ICON,
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:loading: (attributes org.gtk.Property.get=brk_tab_page_get_loading org.gtk.Property.set=brk_tab_page_set_loading)
     *
     * Whether the page is loading.
     *
     * If set to `TRUE`, [class@TabBar] and will display a  spinner in place of
     * icon.
     */
    page_props[PAGE_PROP_LOADING] = g_param_spec_boolean(
        "loading", NULL, NULL, FALSE,
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:indicator-icon: (attributes org.gtk.Property.get=brk_tab_page_get_indicator_icon org.gtk.Property.set=brk_tab_page_set_indicator_icon)
     *
     * An indicator icon for the page.
     *
     * A common use case is an audio or camera indicator in a web browser.
     *
     * [class@TabBar] will show it at the beginning of the tab, alongside icon
     * representing [property@TabPage:icon] or loading spinner.
     *
     * [property@TabPage:indicator-tooltip] can be used to set the tooltip on the
     * indicator icon.
     *
     * If [property@TabPage:indicator-activatable] is set to `TRUE`, the
     * indicator icon can act as a button.
     */
    page_props[PAGE_PROP_INDICATOR_ICON] = g_param_spec_object(
        "indicator-icon", NULL, NULL, G_TYPE_ICON,
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:indicator-tooltip: (attributes org.gtk.Property.get=brk_tab_page_get_indicator_tooltip org.gtk.Property.set=brk_tab_page_set_indicator_tooltip)
     *
     * The tooltip of the indicator icon.
     *
     * The tooltip can be marked up with the Pango text markup language.
     *
     * See [property@TabPage:indicator-icon].
     *
     * Since: 1.2
     */
    page_props[PAGE_PROP_INDICATOR_TOOLTIP] = g_param_spec_string(
        "indicator-tooltip", NULL, NULL, "",
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:indicator-activatable: (attributes org.gtk.Property.get=brk_tab_page_get_indicator_activatable org.gtk.Property.set=brk_tab_page_set_indicator_activatable)
     *
     * Whether the indicator icon is activatable.
     *
     * If set to `TRUE`, [signal@TabView::indicator-activated] will be emitted
     * when the indicator icon is clicked.
     *
     * If [property@TabPage:indicator-icon] is not set, does nothing.
     */
    page_props[PAGE_PROP_INDICATOR_ACTIVATABLE] = g_param_spec_boolean(
        "indicator-activatable", NULL, NULL, FALSE,
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:needs-attention: (attributes org.gtk.Property.get=brk_tab_page_get_needs_attention org.gtk.Property.set=brk_tab_page_set_needs_attention)
     *
     * Whether the page needs attention.
     *
     * [class@TabBar] will display a line under the tab representing the page if
     * set to `TRUE`. If the tab is not visible, the corresponding edge of the tab
     * bar will be highlighted.
     *
     * [class@TabButton] will display a dot if any of the pages that aren't
     * selected have this property set to `TRUE`.
     */
    page_props[PAGE_PROP_NEEDS_ATTENTION] = g_param_spec_boolean(
        "needs-attention", NULL, NULL, FALSE,
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:keyword: (attributes org.gtk.Property.get=brk_tab_page_get_keyword org.gtk.Property.set=brk_tab_page_set_keyword)
     *
     * The search keyboard of the page.
     *
     * Keywords allow to include e.g. page URLs into tab search in a web browser.
     *
     * Since: 1.3
     */
    page_props[PAGE_PROP_KEYWORD] = g_param_spec_string(
        "keyword", NULL, NULL, "",
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    g_object_class_install_properties(object_class, LAST_PAGE_PROP, page_props);

    g_object_class_override_property(object_class, PAGE_PROP_ACCESSIBLE_ROLE, "accessible-role");
}

static void
brk_tab_page_init(BrkTabPage *self) {
    self->title = g_strdup("");
    self->tooltip = g_strdup("");
    self->indicator_tooltip = g_strdup("");
    self->bin = g_object_ref_sink(brk_bin_new());
}

static void
brk_tab_page_buildable_add_child(
    GtkBuildable *buildable, GtkBuilder *builder, GObject *child, const char *type
) {
    if (GTK_IS_WIDGET(child))
        brk_bin_set_child(BRK_BIN(BRK_TAB_PAGE(buildable)->bin), GTK_WIDGET(child));
    else
        tab_page_parent_buildable_iface->add_child(buildable, builder, child, type);
}

static void
brk_tab_page_buildable_init(GtkBuildableIface *iface) {
    tab_page_parent_buildable_iface = g_type_interface_peek_parent(iface);

    iface->add_child = brk_tab_page_buildable_add_child;
}

static GtkATContext *
brk_tab_page_accessible_get_at_context(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);

    if (self->in_destruction)
        return NULL;

    if (self->at_context == NULL) {
        GtkAccessibleRole role = GTK_ACCESSIBLE_ROLE_TAB_PANEL;
        GdkDisplay *display;

        if (self->bin != NULL)
            display = gtk_widget_get_display(self->bin);
        else
            display = gdk_display_get_default();

        self->at_context = gtk_at_context_create(role, accessible, display);

        if (self->at_context == NULL)
            return NULL;
    }

    return g_object_ref(self->at_context);
}

static gboolean
brk_tab_page_accessible_get_platform_state(GtkAccessible *self, GtkAccessiblePlatformState state) {
    return FALSE;
}

static GtkAccessible *
brk_tab_page_accessible_get_accessible_parent(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);
    GtkWidget *parent;

    if (!self->bin)
        return NULL;

    parent = gtk_widget_get_parent(self->bin);

    return GTK_ACCESSIBLE(g_object_ref(parent));
}

static GtkAccessible *
brk_tab_page_accessible_get_first_accessible_child(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);

    if (self->bin)
        return GTK_ACCESSIBLE(g_object_ref(self->bin));

    return NULL;
}

static GtkAccessible *
brk_tab_page_accessible_get_next_accessible_sibling(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);
    GtkWidget *view = gtk_widget_get_parent(self->bin);
    BrkTabPage *next_page;
    int pos;

    if (!BRK_TAB_VIEW(view))
        return NULL;

    pos = brk_tab_view_get_page_position(BRK_TAB_VIEW(view), self);

    if (pos >= brk_tab_view_get_n_pages(BRK_TAB_VIEW(view)) - 1)
        return NULL;

    next_page = brk_tab_view_get_nth_page(BRK_TAB_VIEW(view), pos + 1);

    return GTK_ACCESSIBLE(g_object_ref(next_page));
}

static gboolean
brk_tab_page_accessible_get_bounds(
    GtkAccessible *accessible, int *x, int *y, int *width, int *height
) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);

    if (self->bin)
        return gtk_accessible_get_bounds(GTK_ACCESSIBLE(self->bin), x, y, width, height);

    return FALSE;
}

static void
brk_tab_page_accessible_init(GtkAccessibleInterface *iface) {
    iface->get_at_context = brk_tab_page_accessible_get_at_context;
    iface->get_platform_state = brk_tab_page_accessible_get_platform_state;
    iface->get_accessible_parent = brk_tab_page_accessible_get_accessible_parent;
    iface->get_first_accessible_child = brk_tab_page_accessible_get_first_accessible_child;
    iface->get_next_accessible_sibling = brk_tab_page_accessible_get_next_accessible_sibling;
    iface->get_bounds = brk_tab_page_accessible_get_bounds;
}

