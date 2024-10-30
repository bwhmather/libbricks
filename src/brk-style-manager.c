#include <config.h>

#include "brk-style-manager-private.h"

struct _BrkStyleManager {
    GObject parent_instance;
    GdkDisplay *display;
};

G_DEFINE_FINAL_TYPE(BrkStyleManager, brk_style_manager, G_TYPE_OBJECT);

enum {
    PROP_0,
    PROP_DISPLAY,
    NUM_PROPS,
};

static GParamSpec *props[NUM_PROPS];

static void
brk_style_manager_constructed(GObject *object) {

    G_OBJECT_CLASS(brk_style_manager_parent_class)->constructed(object);
}

static void
brk_style_manager_dispose(GObject *object) {

    G_OBJECT_CLASS(brk_style_manager_parent_class)->dispose(object);
}

static void
brk_style_manager_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(object);

    switch (prop_id) {
    case PROP_DISPLAY:
        g_value_set_object(value, brk_style_manager_get_display(self));
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_style_manager_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec) {
    BrkStyleManager *self = BRK_STYLE_MANAGER(object);

    switch (prop_id) {
    case PROP_DISPLAY:
        self->display = g_value_get_object(value);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
    }
}

static void
brk_style_manager_class_init(BrkStyleManagerClass *class) {
    GObjectClass *object_class = G_OBJECT_CLASS(class);

    object_class->constructed = brk_style_manager_constructed;
    object_class->dispose = brk_style_manager_dispose;
    object_class->get_property = brk_style_manager_get_property;
    object_class->set_property = brk_style_manager_set_property;

    props[PROP_DISPLAY] = g_param_spec_object(
        "display", NULL, NULL, GDK_TYPE_DISPLAY,
        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY | G_PARAM_STATIC_STRINGS
    );

    g_object_class_install_properties(object_class, NUM_PROPS, props);
}

static void
brk_style_manager_init(BrkStyleManager *self) {}

BrkStyleManager *
brk_style_manager_new(GdkDisplay *display) {
    BrkStyleManager *style_manager;

    g_return_val_if_fail(GDK_IS_DISPLAY(display), NULL);

    style_manager = g_object_new(
        BRK_TYPE_STYLE_MANAGER,
        "display", display,
        NULL
    );

    return style_manager;
}

GdkDisplay *
brk_style_manager_get_display(BrkStyleManager *self) {
    g_return_val_if_fail(BRK_IS_STYLE_MANAGER(self), NULL);
    return self->display;
}
