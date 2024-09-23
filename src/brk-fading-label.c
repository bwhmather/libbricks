/*
 * Copyright (C) 2021 Purism SPC
 *
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Author: Alice Mikhaylenko <alice.mikhaylenko@puri.sm>
 */

#include "config.h"
#include "brk-fading-label-private.h"

#include <glib/gi18n-lib.h>
#include "brk-bidi-private.h"

#define FADE_WIDTH 18.0f

struct _BrkFadingLabel
{
  GtkWidget parent_instance;

  GtkWidget *label;
  float align;
};

G_DEFINE_FINAL_TYPE (BrkFadingLabel, brk_fading_label, GTK_TYPE_WIDGET)

enum {
  PROP_0,
  PROP_LABEL,
  PROP_ALIGN,
  LAST_PROP
};

static GParamSpec *props[LAST_PROP];

static gboolean
is_rtl (BrkFadingLabel *self)
{
  PangoDirection pango_direction = PANGO_DIRECTION_NEUTRAL;
  const char *label = brk_fading_label_get_label (self);

  if (label)
    pango_direction = brk_find_base_dir (label, -1);

  if (pango_direction == PANGO_DIRECTION_RTL)
    return TRUE;

  if (pango_direction == PANGO_DIRECTION_LTR)
    return FALSE;

  return gtk_widget_get_direction (GTK_WIDGET (self)) == GTK_TEXT_DIR_RTL;
}

static void
brk_fading_label_measure (GtkWidget      *widget,
                          GtkOrientation  orientation,
                          int             for_size,
                          int             *min,
                          int             *nat,
                          int             *min_baseline,
                          int             *nat_baseline)
{
  BrkFadingLabel *self = BRK_FADING_LABEL (widget);

  gtk_widget_measure (self->label, orientation, for_size,
                      min, nat, min_baseline, nat_baseline);

  if (orientation == GTK_ORIENTATION_HORIZONTAL && min)
    *min = 0;
}

static void
brk_fading_label_size_allocate (GtkWidget *widget,
                                int        width,
                                int        height,
                                int        baseline)
{
  BrkFadingLabel *self = BRK_FADING_LABEL (widget);
  float align = is_rtl (self) ? 1 - self->align : self->align;
  int child_width;
  float offset;
  GskTransform *transform;

  gtk_widget_measure (self->label, GTK_ORIENTATION_HORIZONTAL, height,
                      NULL, &child_width, NULL, NULL);

  offset = (width - child_width) * align;
  transform = gsk_transform_translate (NULL, &GRAPHENE_POINT_INIT (offset, 0));

  gtk_widget_allocate (self->label, child_width, height, baseline, transform);
}

static void
brk_fading_label_snapshot (GtkWidget   *widget,
                           GtkSnapshot *snapshot)
{
  BrkFadingLabel *self = BRK_FADING_LABEL (widget);
  float align = is_rtl (self) ? 1 - self->align : self->align;
  int width = gtk_widget_get_width (widget);
  int clipped_size;
  GtkSnapshot *child_snapshot;
  GskRenderNode *node;
  graphene_rect_t bounds;

  if (width <= 0)
    return;

  clipped_size = gtk_widget_get_width (self->label) - width;

  if (clipped_size <= 0) {
    gtk_widget_snapshot_child (widget, self->label, snapshot);

    return;
  }

  child_snapshot = gtk_snapshot_new ();
  gtk_widget_snapshot_child (widget, self->label, child_snapshot);
  node = gtk_snapshot_free_to_node (child_snapshot);

  gsk_render_node_get_bounds (node, &bounds);
  bounds.origin.x = 0;
  bounds.origin.y = floor (bounds.origin.y);
  bounds.size.width = width;
  bounds.size.height = ceil (bounds.size.height) + 1;

  gtk_snapshot_push_mask (snapshot, GSK_MASK_MODE_INVERTED_ALPHA);

  if (align > 0) {
    gtk_snapshot_append_linear_gradient (snapshot,
                                         &GRAPHENE_RECT_INIT (0, bounds.origin.y,
                                                              FADE_WIDTH, bounds.size.height),
                                         &GRAPHENE_POINT_INIT (0, 0),
                                         &GRAPHENE_POINT_INIT (FADE_WIDTH, 0),
                                         (GskColorStop[2]) {
                                             { 0, { 0, 0, 0, 1 } },
                                             { 1, { 0, 0, 0, 0 } },
                                         },
                                         2);
  }

  if (align < 1) {
    gtk_snapshot_append_linear_gradient (snapshot,
                                         &GRAPHENE_RECT_INIT (width - FADE_WIDTH, bounds.origin.y,
                                                              FADE_WIDTH, bounds.size.height),
                                         &GRAPHENE_POINT_INIT (width, 0),
                                         &GRAPHENE_POINT_INIT (width - FADE_WIDTH, 0),
                                         (GskColorStop[2]) {
                                             { 0, { 0, 0, 0, 1 } },
                                             { 1, { 0, 0, 0, 0 } },
                                         },
                                         2);
  }

  gtk_snapshot_pop (snapshot);

  gtk_snapshot_push_clip (snapshot, &bounds);
  gtk_snapshot_append_node (snapshot, node);
  gtk_snapshot_pop (snapshot);

  gtk_snapshot_pop (snapshot);

  gsk_render_node_unref (node);
}

static void
brk_fading_label_get_property (GObject    *object,
                               guint       prop_id,
                               GValue     *value,
                               GParamSpec *pspec)
{
  BrkFadingLabel *self = BRK_FADING_LABEL (object);

  switch (prop_id) {
  case PROP_LABEL:
    g_value_set_string (value, brk_fading_label_get_label (self));
    break;

  case PROP_ALIGN:
    g_value_set_float (value, brk_fading_label_get_align (self));
    break;

  default:
    G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
  }
}

static void
brk_fading_label_set_property (GObject      *object,
                               guint         prop_id,
                               const GValue *value,
                               GParamSpec   *pspec)
{
  BrkFadingLabel *self = BRK_FADING_LABEL (object);

  switch (prop_id) {
  case PROP_LABEL:
    brk_fading_label_set_label (self, g_value_get_string (value));
    break;

  case PROP_ALIGN:
    brk_fading_label_set_align (self, g_value_get_float (value));
    break;

  default:
    G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
  }
}

static void
brk_fading_label_dispose (GObject *object)
{
  BrkFadingLabel *self = BRK_FADING_LABEL (object);

  g_clear_pointer (&self->label, gtk_widget_unparent);

  G_OBJECT_CLASS (brk_fading_label_parent_class)->dispose (object);
}

static void
brk_fading_label_class_init (BrkFadingLabelClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);

  object_class->get_property = brk_fading_label_get_property;
  object_class->set_property = brk_fading_label_set_property;
  object_class->dispose = brk_fading_label_dispose;

  widget_class->measure = brk_fading_label_measure;
  widget_class->size_allocate = brk_fading_label_size_allocate;
  widget_class->snapshot = brk_fading_label_snapshot;

  props[PROP_LABEL] =
    g_param_spec_string ("label", NULL, NULL,
                         NULL,
                         G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY);

  props[PROP_ALIGN] =
    g_param_spec_float ("align", NULL, NULL,
                        0.0, 1.0, 0.0,
                        G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS | G_PARAM_EXPLICIT_NOTIFY);

  g_object_class_install_properties (object_class, LAST_PROP, props);
}

static void
brk_fading_label_init (BrkFadingLabel *self)
{
  self->label = gtk_label_new (NULL);
  gtk_label_set_single_line_mode (GTK_LABEL (self->label), TRUE);

  gtk_widget_set_parent (self->label, GTK_WIDGET (self));
}

const char *
brk_fading_label_get_label (BrkFadingLabel *self)
{
  g_return_val_if_fail (BRK_IS_FADING_LABEL (self), NULL);

  return gtk_label_get_label (GTK_LABEL (self->label));
}

void
brk_fading_label_set_label (BrkFadingLabel *self,
                            const char     *label)
{
  g_return_if_fail (BRK_IS_FADING_LABEL (self));

  if (!g_strcmp0 (label, brk_fading_label_get_label (self)))
    return;

  gtk_label_set_label (GTK_LABEL (self->label), label);

  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_LABEL]);
}

float
brk_fading_label_get_align (BrkFadingLabel *self)
{
  g_return_val_if_fail (BRK_IS_FADING_LABEL (self), 0.0f);

  return self->align;
}

void
brk_fading_label_set_align (BrkFadingLabel *self,
                            float           align)
{
  g_return_if_fail (BRK_IS_FADING_LABEL (self));

  align = CLAMP (align, 0.0, 1.0);

  if (G_APPROX_VALUE (self->align, align, FLT_EPSILON))
    return;

  self->align = align;

  gtk_widget_queue_allocate (GTK_WIDGET (self));

  g_object_notify_by_pspec (G_OBJECT (self), props[PROP_ALIGN]);
}
