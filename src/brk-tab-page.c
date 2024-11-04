#include <config.h>

#include "brk-tab-page.h"

#include <gdk/gdk.h>
#include <gio/gio.h>
#include <glib-object.h>
#include <glib.h>
#include <gtk/gtk.h>

#include "brk-bin-private.h"
#include "brk-main.h"
#include "brk-tab-page-private.h"
#include "brk-tab-view.h"

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
    PROP_0,
    PROP_CHILD,
    PROP_PARENT,
    PROP_SELECTED,
    PROP_TITLE,
    PROP_TOOLTIP,
    PROP_ICON,
    PROP_LOADING,
    PROP_INDICATOR_ICON,
    PROP_INDICATOR_TOOLTIP,
    PROP_INDICATOR_ACTIVATABLE,
    PROP_NEEDS_ATTENTION,
    PROP_KEYWORD,
    LAST_PROP,
    PROP_ACCESSIBLE_ROLE
};

static GParamSpec *props[LAST_PROP];

void
brk_tab_page_set_selected(BrkTabPage *self, gboolean selected) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    selected = !!selected;

    if (self->selected == selected) {
        return;
    }

    self->selected = selected;

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_SELECTED]);
}

gboolean
brk_tab_page_get_has_focus(BrkTabPage *self) {
    GtkRoot *root;
    GtkWidget *focus;

    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), FALSE);

    if (!self->selected) {
        return FALSE;
    }

    root = gtk_widget_get_root(brk_tab_page_get_bin(self));
    if (root == NULL) {
        return FALSE;
    }

    focus = gtk_root_get_focus(root);
    if (focus == NULL) {
        return FALSE;
    }

    if (!gtk_widget_is_ancestor(focus, brk_tab_page_get_bin(self))) {
        return FALSE;
    }

    return TRUE;
}

void
brk_tab_page_save_focus(BrkTabPage *self) {
    GtkRoot *root;
    GtkWidget *focus;

    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    if (!self->selected) {
        return;
    }

    root = gtk_widget_get_root(brk_tab_page_get_bin(self));
    if (root == NULL) {
        return;
    }

    focus = gtk_root_get_focus(root);
    if (focus == NULL) {
        return;
    }

    if (gtk_widget_is_ancestor(focus, brk_tab_page_get_bin(self))) {
        return;
    }

    g_set_weak_pointer(&self->last_focus, focus);
}

void
brk_tab_page_grab_focus(BrkTabPage *self) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));
    if (self->last_focus) {
        gtk_widget_grab_focus(self->last_focus);
    } else {
        gtk_widget_child_focus(brk_tab_page_get_bin(self), GTK_DIR_TAB_FORWARD);
    }
}

static void
page_parent_notify_cb(BrkTabPage *self) {
    BrkTabPage *grandparent = brk_tab_page_get_parent(self->parent);

    self->parent = NULL;

    if (grandparent) {
        brk_tab_page_set_parent(self, grandparent);
    } else {
        g_object_notify_by_pspec(G_OBJECT(self), props[PROP_PARENT]);
    }
}

static void
brk_tab_page_dispose(GObject *object) {
    BrkTabPage *self = BRK_TAB_PAGE(object);

    self->in_destruction = TRUE;

    brk_tab_page_set_parent(self, NULL);

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
    case PROP_CHILD:
        g_value_set_object(value, brk_tab_page_get_child(self));
        break;

    case PROP_PARENT:
        g_value_set_object(value, brk_tab_page_get_parent(self));
        break;

    case PROP_SELECTED:
        g_value_set_boolean(value, brk_tab_page_get_selected(self));
        break;

    case PROP_TITLE:
        g_value_set_string(value, brk_tab_page_get_title(self));
        break;

    case PROP_TOOLTIP:
        g_value_set_string(value, brk_tab_page_get_tooltip(self));
        break;

    case PROP_ICON:
        g_value_set_object(value, brk_tab_page_get_icon(self));
        break;

    case PROP_LOADING:
        g_value_set_boolean(value, brk_tab_page_get_loading(self));
        break;

    case PROP_INDICATOR_ICON:
        g_value_set_object(value, brk_tab_page_get_indicator_icon(self));
        break;

    case PROP_INDICATOR_TOOLTIP:
        g_value_set_string(value, brk_tab_page_get_indicator_tooltip(self));
        break;

    case PROP_INDICATOR_ACTIVATABLE:
        g_value_set_boolean(value, brk_tab_page_get_indicator_activatable(self));
        break;

    case PROP_NEEDS_ATTENTION:
        g_value_set_boolean(value, brk_tab_page_get_needs_attention(self));
        break;

    case PROP_KEYWORD:
        g_value_set_string(value, brk_tab_page_get_keyword(self));
        break;

    case PROP_ACCESSIBLE_ROLE:
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
    case PROP_CHILD:
        g_set_object(&self->child, g_value_get_object(value));
        brk_bin_set_child(BRK_BIN(self->bin), g_value_get_object(value));
        break;

    case PROP_PARENT:
        brk_tab_page_set_parent(self, g_value_get_object(value));
        break;

    case PROP_TITLE:
        brk_tab_page_set_title(self, g_value_get_string(value));
        break;

    case PROP_TOOLTIP:
        brk_tab_page_set_tooltip(self, g_value_get_string(value));
        break;

    case PROP_ICON:
        brk_tab_page_set_icon(self, g_value_get_object(value));
        break;

    case PROP_LOADING:
        brk_tab_page_set_loading(self, g_value_get_boolean(value));
        break;

    case PROP_INDICATOR_ICON:
        brk_tab_page_set_indicator_icon(self, g_value_get_object(value));
        break;

    case PROP_INDICATOR_TOOLTIP:
        brk_tab_page_set_indicator_tooltip(self, g_value_get_string(value));
        break;

    case PROP_INDICATOR_ACTIVATABLE:
        brk_tab_page_set_indicator_activatable(self, g_value_get_boolean(value));
        break;

    case PROP_NEEDS_ATTENTION:
        brk_tab_page_set_needs_attention(self, g_value_get_boolean(value));
        break;

    case PROP_KEYWORD:
        brk_tab_page_set_keyword(self, g_value_get_string(value));
        break;

    case PROP_ACCESSIBLE_ROLE:
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
    props[PROP_CHILD] = g_param_spec_object(
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
    props[PROP_PARENT] = g_param_spec_object(
        "parent", NULL, NULL, BRK_TYPE_TAB_PAGE,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS |
            G_PARAM_EXPLICIT_NOTIFY
    );

    /**
     * BrkTabPage:selected: (attributes org.gtk.Property.get=brk_tab_page_get_selected)
     *
     * Whether the page is selected.
     */
    props[PROP_SELECTED] = g_param_spec_boolean(
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
    props[PROP_TITLE] = g_param_spec_string(
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
    props[PROP_TOOLTIP] = g_param_spec_string(
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
    props[PROP_ICON] = g_param_spec_object(
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
    props[PROP_LOADING] = g_param_spec_boolean(
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
    props[PROP_INDICATOR_ICON] = g_param_spec_object(
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
    props[PROP_INDICATOR_TOOLTIP] = g_param_spec_string(
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
    props[PROP_INDICATOR_ACTIVATABLE] = g_param_spec_boolean(
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
    props[PROP_NEEDS_ATTENTION] = g_param_spec_boolean(
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
    props[PROP_KEYWORD] = g_param_spec_string(
        "keyword", NULL, NULL, "",
        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY
    );

    g_object_class_install_properties(object_class, LAST_PROP, props);

    g_object_class_override_property(object_class, PROP_ACCESSIBLE_ROLE, "accessible-role");
}

static void
brk_tab_page_init(BrkTabPage *self) {
    g_warn_if_fail(brk_is_initialized());

    self->title = g_strdup("");
    self->tooltip = g_strdup("");
    self->indicator_tooltip = g_strdup("");
    self->bin = g_object_ref_sink(brk_bin_new());
}

static void
brk_tab_page_buildable_add_child(
    GtkBuildable *buildable, GtkBuilder *builder, GObject *child, const char *type
) {
    if (GTK_IS_WIDGET(child)) {
        brk_bin_set_child(BRK_BIN(BRK_TAB_PAGE(buildable)->bin), GTK_WIDGET(child));
        g_set_object(&BRK_TAB_PAGE(buildable)->child, GTK_WIDGET(child));
    } else {
        tab_page_parent_buildable_iface->add_child(buildable, builder, child, type);
    }
}

static void
brk_tab_page_buildable_init(GtkBuildableIface *iface) {
    tab_page_parent_buildable_iface = g_type_interface_peek_parent(iface);

    iface->add_child = brk_tab_page_buildable_add_child;
}

static GtkATContext *
brk_tab_page_accessible_get_at_context(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);

    if (self->in_destruction) {
        return NULL;
    }

    if (self->at_context == NULL) {
        GtkAccessibleRole role = GTK_ACCESSIBLE_ROLE_TAB_PANEL;
        GdkDisplay *display;

        if (self->bin != NULL) {
            display = gtk_widget_get_display(self->bin);
        } else {
            display = gdk_display_get_default();
        }

        self->at_context = gtk_at_context_create(role, accessible, display);

        if (self->at_context == NULL) {
            return NULL;
        }
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

    if (!self->bin) {
        return NULL;
    }

    parent = gtk_widget_get_parent(self->bin);

    return GTK_ACCESSIBLE(g_object_ref(parent));
}

static GtkAccessible *
brk_tab_page_accessible_get_first_accessible_child(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);

    if (self->bin) {
        return GTK_ACCESSIBLE(g_object_ref(self->bin));
    }

    return NULL;
}

static GtkAccessible *
brk_tab_page_accessible_get_next_accessible_sibling(GtkAccessible *accessible) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);
    GtkWidget *view = gtk_widget_get_parent(self->bin);
    BrkTabPage *next_page;
    int pos;

    if (!BRK_TAB_VIEW(view)) {
        return NULL;
    }

    pos = brk_tab_view_get_page_position(BRK_TAB_VIEW(view), self);

    if (pos >= brk_tab_view_get_n_pages(BRK_TAB_VIEW(view)) - 1) {
        return NULL;
    }

    next_page = brk_tab_view_get_nth_page(BRK_TAB_VIEW(view), pos + 1);

    return GTK_ACCESSIBLE(g_object_ref(next_page));
}

static gboolean
brk_tab_page_accessible_get_bounds(
    GtkAccessible *accessible, int *x, int *y, int *width, int *height
) {
    BrkTabPage *self = BRK_TAB_PAGE(accessible);

    if (self->bin) {
        return gtk_accessible_get_bounds(GTK_ACCESSIBLE(self->bin), x, y, width, height);
    }

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

void
brk_tab_page_set_closing(BrkTabPage *self, gboolean closing) {
    self->closing = closing;
}

gboolean
brk_tab_page_get_closing(BrkTabPage *self) {
    return self->closing;
}

GtkWidget *
brk_tab_page_get_bin(BrkTabPage *self) {
    return self->bin;
}

/**
 * brk_tab_page_get_child: (attributes org.gtk.Method.get_property=child)
 * @self: a tab page
 *
 * Gets the child of @self.
 *
 * Returns: (transfer none): the child of @self
 */
GtkWidget *
brk_tab_page_get_child(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->child;
}

/**
 * brk_tab_page_get_parent: (attributes org.gtk.Method.get_property=parent)
 * @self: a tab page
 *
 * Gets the parent page of @self.
 *
 * See [method@TabView.add_page] and [method@TabView.close_page].
 *
 * Returns: (transfer none) (nullable): the parent page
 */
BrkTabPage *
brk_tab_page_get_parent(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->parent;
}

void
brk_tab_page_set_parent(BrkTabPage *self, BrkTabPage *parent) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));
    g_return_if_fail(parent == NULL || BRK_IS_TAB_PAGE(parent));

    if (self->parent == parent) {
        return;
    }

    if (self->parent) {
        g_object_weak_unref(G_OBJECT(self->parent), (GWeakNotify) page_parent_notify_cb, self);
    }

    self->parent = parent;

    if (self->parent) {
        g_object_weak_ref(G_OBJECT(self->parent), (GWeakNotify) page_parent_notify_cb, self);
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_PARENT]);
}

/**
 * brk_tab_page_get_selected: (attributes org.gtk.Method.get_property=selected)
 * @self: a tab page
 *
 * Gets whether @self is selected.
 *
 * Returns: whether @self is selected
 */
gboolean
brk_tab_page_get_selected(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), FALSE);

    return self->selected;
}

/**
 * brk_tab_page_get_title: (attributes org.gtk.Method.get_property=title)
 * @self: a tab page
 *
 * Gets the title of @self.
 *
 * Returns: the title of @self
 */
const char *
brk_tab_page_get_title(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->title;
}

/**
 * brk_tab_page_set_title: (attributes org.gtk.Method.set_property=title)
 * @self: a tab page
 * @title: the title of @self
 *
 * [class@TabBar] will display it in the center of the tab and will use it as a
 * tooltip unless [property@TabPage:tooltip] is set.
 *
 * Sets the title of @self.
 */
void
brk_tab_page_set_title(BrkTabPage *self, const char *title) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    if (!g_set_str(&self->title, title ? title : "")) {
        return;
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_TITLE]);

    gtk_accessible_update_property(
        GTK_ACCESSIBLE(self), GTK_ACCESSIBLE_PROPERTY_LABEL, self->title, -1
    );
}

/**
 * brk_tab_page_get_tooltip: (attributes org.gtk.Method.get_property=tooltip)
 * @self: a tab page
 *
 * Gets the tooltip of @self.
 *
 * Returns: (nullable): the tooltip of @self
 */
const char *
brk_tab_page_get_tooltip(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->tooltip;
}

/**
 * brk_tab_page_set_tooltip: (attributes org.gtk.Method.set_property=tooltip)
 * @self: a tab page
 * @tooltip: the tooltip of @self
 *
 * Sets the tooltip of @self.
 *
 * The tooltip can be marked up with the Pango text markup language.
 */
void
brk_tab_page_set_tooltip(BrkTabPage *self, const char *tooltip) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    if (!g_set_str(&self->tooltip, tooltip ? tooltip : "")) {
        return;
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_TOOLTIP]);
}

/**
 * brk_tab_page_get_icon: (attributes org.gtk.Method.get_property=icon)
 * @self: a tab page
 *
 * Gets the icon of @self.
 *
 * Returns: (transfer none) (nullable): the icon of @self
 */
GIcon *
brk_tab_page_get_icon(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->icon;
}

/**
 * brk_tab_page_set_icon: (attributes org.gtk.Method.set_property=icon)
 * @self: a tab page
 * @icon: (nullable): the icon of @self
 *
 * Sets the icon of @self.
 *
 * [class@TabBar] displays the icon next to the title,  unless
 * [property@TabPage:loading] is set to `TRUE`.
 */
void
brk_tab_page_set_icon(BrkTabPage *self, GIcon *icon) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));
    g_return_if_fail(icon == NULL || G_IS_ICON(icon));

    if (!g_set_object(&self->icon, icon)) {
        return;
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_ICON]);
}

/**
 * brk_tab_page_get_loading: (attributes org.gtk.Method.get_property=loading)
 * @self: a tab page
 *
 * Gets whether @self is loading.
 *
 * Returns: whether @self is loading
 */
gboolean
brk_tab_page_get_loading(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), FALSE);

    return self->loading;
}

/**
 * brk_tab_page_set_loading: (attributes org.gtk.Method.set_property=loading)
 * @self: a tab page
 * @loading: whether @self is loading
 *
 * Sets whether @self is loading.
 *
 * If set to `TRUE`, [class@TabBar] will display a spinner in place of icon.
 */
void
brk_tab_page_set_loading(BrkTabPage *self, gboolean loading) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    loading = !!loading;

    if (self->loading == loading) {
        return;
    }

    self->loading = loading;

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_LOADING]);
}

/**
 * brk_tab_page_get_indicator_icon:  (attributes org.gtk.Method.get_property=indicator-icon)
 * @self: a tab page
 *
 * Gets the indicator icon of @self.
 *
 * Returns: (transfer none) (nullable): the indicator icon of @self
 */
GIcon *
brk_tab_page_get_indicator_icon(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->indicator_icon;
}

/**
 * brk_tab_page_set_indicator_icon:  (attributes org.gtk.Method.set_property=indicator-icon)
 * @self: a tab page
 * @indicator_icon: (nullable): the indicator icon of @self
 *
 * Sets the indicator icon of @self.
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
void
brk_tab_page_set_indicator_icon(BrkTabPage *self, GIcon *indicator_icon) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));
    g_return_if_fail(indicator_icon == NULL || G_IS_ICON(indicator_icon));

    if (!g_set_object(&self->indicator_icon, indicator_icon)) {
        return;
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_INDICATOR_ICON]);
}

/**
 * brk_tab_page_get_indicator_tooltip:  (attributes org.gtk.Method.get_property=indicator-tooltip)
 * @self: a tab page
 *
 * Gets the tooltip of the indicator icon of @self.
 *
 * Returns: (transfer none): the indicator tooltip of @self
 *
 * Since: 1.2
 */
const char *
brk_tab_page_get_indicator_tooltip(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->indicator_tooltip;
}

/**
 * brk_tab_page_set_indicator_tooltip:  (attributes org.gtk.Method.set_property=indicator-tooltip)
 * @self: a tab page
 * @tooltip: the indicator tooltip of @self
 *
 * Sets the tooltip of the indicator icon of @self.
 *
 * The tooltip can be marked up with the Pango text markup language.
 *
 * See [property@TabPage:indicator-icon].
 *
 * Since: 1.2
 */
void
brk_tab_page_set_indicator_tooltip(BrkTabPage *self, const char *tooltip) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));
    g_return_if_fail(tooltip != NULL);

    if (!g_set_str(&self->indicator_tooltip, tooltip ? tooltip : "")) {
        return;
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_INDICATOR_TOOLTIP]);
}

/**
 * brk_tab_page_get_indicator_activatable:  (attributes org.gtk.Method.get_property=indicator-activatable)
 * @self: a tab page
 *
 *
 * Gets whether the indicator of @self is activatable.
 *
 * Returns: whether the indicator is activatable
 */
gboolean
brk_tab_page_get_indicator_activatable(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), FALSE);

    return self->indicator_activatable;
}

/**
 * brk_tab_page_set_indicator_activatable:  (attributes org.gtk.Method.set_property=indicator-activatable)
 * @self: a tab page
 * @activatable: whether the indicator is activatable
 *
 * Sets whether the indicator of @self is activatable.
 *
 * If set to `TRUE`, [signal@TabView::indicator-activated] will be emitted
 * when the indicator icon is clicked.
 *
 * If [property@TabPage:indicator-icon] is not set, does nothing.
 */
void
brk_tab_page_set_indicator_activatable(BrkTabPage *self, gboolean activatable) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    activatable = !!activatable;

    if (self->indicator_activatable == activatable) {
        return;
    }

    self->indicator_activatable = activatable;

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_INDICATOR_ACTIVATABLE]);
}

/**
 * brk_tab_page_get_needs_attention:  (attributes org.gtk.Method.get_property=needs-attention)
 * @self: a tab page
 *
 * Gets whether @self needs attention.
 *
 * Returns: whether @self needs attention
 */
gboolean
brk_tab_page_get_needs_attention(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), FALSE);

    return self->needs_attention;
}

/**
 * brk_tab_page_set_needs_attention:  (attributes org.gtk.Method.set_property=needs-attention)
 * @self: a tab page
 * @needs_attention: whether @self needs attention
 *
 * Sets whether @self needs attention.
 *
 * [class@TabBar] will display a line under the tab representing the page if
 * set to `TRUE`. If the tab is not visible, the corresponding edge of the tab
 * bar will be highlighted.
 *
 * [class@TabButton] will display a dot if any of the pages that aren't
 * selected have [property@TabPage:needs-attention] set to `TRUE`.
 */
void
brk_tab_page_set_needs_attention(BrkTabPage *self, gboolean needs_attention) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    needs_attention = !!needs_attention;

    if (self->needs_attention == needs_attention) {
        return;
    }

    self->needs_attention = needs_attention;

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_NEEDS_ATTENTION]);
}

/**
 * brk_tab_page_get_keyword: (attributes org.gtk.Method.get_property=keyword)
 * @self: a tab page
 *
 * Gets the search keyword of @self.
 *
 * Returns: (nullable): the search keyword of @self
 *
 * Since: 1.3
 */
const char *
brk_tab_page_get_keyword(BrkTabPage *self) {
    g_return_val_if_fail(BRK_IS_TAB_PAGE(self), NULL);

    return self->keyword;
}

/**
 * brk_tab_page_set_keyword: (attributes org.gtk.Method.set_property=keyword)
 * @self: a tab page
 * @keyword: the search keyword
 *
 * Sets the search keyword for @self.
 *
 * Keywords allow to include e.g. page URLs into tab search in a web browser.
 *
 * Since: 1.3
 */
void
brk_tab_page_set_keyword(BrkTabPage *self, const char *keyword) {
    g_return_if_fail(BRK_IS_TAB_PAGE(self));

    if (!g_set_str(&self->keyword, keyword)) {
        return;
    }

    g_object_notify_by_pspec(G_OBJECT(self), props[PROP_KEYWORD]);
}
