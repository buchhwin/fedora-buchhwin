#!/usr/bin/env python3
"""Make dwl honor cursor theme and size exported by the isolated session."""
from __future__ import annotations

import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-dwl-source.py /path/to/dwl.c")

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
pattern = re.compile(
    r'cursor_mgr\s*=\s*wlr_xcursor_manager_create\(NULL,\s*24\);\s*'
    r'setenv\("XCURSOR_SIZE",\s*"24",\s*1\);'
)
replacement = '''{
        const char *cursor_size_env = getenv("XCURSOR_SIZE");
        long cursor_size = cursor_size_env ? strtol(cursor_size_env, NULL, 10) : 24;

        if (cursor_size <= 0 || cursor_size > 512)
            cursor_size = 24;
        cursor_mgr = wlr_xcursor_manager_create(getenv("XCURSOR_THEME"), (uint32_t)cursor_size);
    }'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(f"cursor patch failed: expected one match, got {count}")

# Complete the small set of hunks from the pinned SceneFX patch which do not
# apply automatically to Fedora's wlroots-next dwl revision.
text = text.replace("#include <scenefx/types/fx/corner_location.h>\n", "")
client_blur_anchor = "\tstruct wlr_scene_rect *round_border;"
if client_blur_anchor not in text:
    raise SystemExit("SceneFX port failed: client blur anchor missing")
text = text.replace(client_blur_anchor, client_blur_anchor +
                    "\n\tstruct wlr_scene_blur *blur;", 1)
layer_anchor = "enum { LyrBg, LyrBottom, LyrTile, LyrFloat, LyrTop, LyrFS, LyrOverlay, LyrBlock, NUM_LAYERS };"
if layer_anchor not in text:
    raise SystemExit("SceneFX port failed: layer enum anchor missing")
text = text.replace(layer_anchor, layer_anchor.replace("LyrBg,", "LyrBg, LyrBlur,"), 1)

scenefx_prototype_anchor = "static void zoom(const Arg *arg);"
if scenefx_prototype_anchor not in text:
    raise SystemExit("SceneFX port failed: prototype anchor missing")
text = text.replace(scenefx_prototype_anchor, scenefx_prototype_anchor + r'''
static void iter_xdg_scene_buffers(struct wlr_scene_buffer *buffer, int sx, int sy, void *user_data);
static void iter_xdg_scene_buffers_blur(struct wlr_scene_buffer *buffer, int sx, int sy, void *user_data);
static void iter_xdg_scene_buffers_opacity(struct wlr_scene_buffer *buffer, int sx, int sy, void *user_data);
static void iter_xdg_scene_buffers_corner_radius(struct wlr_scene_buffer *buffer, int sx, int sy, void *user_data);
static void output_configure_scene(struct wlr_scene_node *node, Client *c);
static int in_shadow_ignore_list(const char *str);
static void client_set_shadow_blur_sigma(Client *c, int blur_sigma);
static void update_client_corner_radius(Client *c);
static void update_client_shadow_color(Client *c);
static void update_client_focus_decorations(Client *c, int focused, int urgent);
static void update_client_blur(Client *c);
static void update_buffer_corner_radius(Client *c, struct wlr_scene_buffer *buffer);''', 1)

variable_anchor = "static struct wl_listener new_session_lock = {.notify = locksession};"
if variable_anchor not in text:
    raise SystemExit("SceneFX port failed: variable anchor missing")
text = text.replace(variable_anchor, variable_anchor +
                    "\n\nstatic float transparent[4] = {0.1f, 0.1f, 0.1f, 0.0f};", 1)

renderer_pattern = re.compile(
    r'if \(!\(drw = wlr_renderer_autocreate\(backend\)\)\)\s*\n\s*die\("couldn.t create renderer"\);'
)
renderer_replacement = '''if (blur)
        wlr_scene_set_blur_data(scene, blur_data.num_passes, blur_data.radius,
                blur_data.noise, blur_data.brightness, blur_data.contrast,
                blur_data.saturation);
    if (!(drw = fx_renderer_create(backend)))
        die("couldn't create renderer");'''
text, count = renderer_pattern.subn(renderer_replacement, text, count=1)
if count != 1:
    raise SystemExit(f"SceneFX port failed: expected one renderer, got {count}")

old_resize_effects = r'''
	if (corner_radius > 0 && c->round_border) {
		wlr_scene_node_set_position(&c->round_border->node, 0, 0);
		wlr_scene_rect_set_size(c->round_border, c->geom.width, c->geom.height);
		wlr_scene_rect_set_clipped_region(c->round_border, (struct clipped_region) {
			.corner_radius = c->corner_radius,
			.corners = CORNER_LOCATION_ALL,
			.area = { c->bw, c->bw, c->geom.width - c->bw * 2, c->geom.height - c->bw * 2 }
		});
	}

	if (shadow && c->shadow) {
		/* TODO: shouldn't we call wlr_scene_shadow_set_blur_sigma? */
		client_set_shadow_blur_sigma(c, (int)round(c->shadow->blur_sigma));
	}
'''
if old_resize_effects not in text:
    raise SystemExit("SceneFX port failed: old resize effects block missing")
text = text.replace(old_resize_effects, "", 1)

old_initial_blur = r'''
			if (blur) {
				int blur_optimized = !c->isfloating || blur_xray;
				wlr_scene_buffer_set_backdrop_blur(buffer, 1);
				wlr_scene_buffer_set_backdrop_blur_optimized(buffer, blur_optimized);
				wlr_scene_buffer_set_backdrop_blur_ignore_transparent(buffer, blur_ignore_transparent);
			}'''
new_initial_blur = r'''
			/* The blur node already sits below the client surface.  Do not use the
			 * client buffer as a transparency mask here: some terminals submit a
			 * mostly opaque shm/dmabuf and implement background opacity while
			 * rendering.  SceneFX then interprets that mask as fully opaque and the
			 * transparent terminal background becomes black.  Blurring the complete
			 * client rectangle is safe because opaque client pixels cover it. */'''
if old_initial_blur not in text:
    raise SystemExit("SceneFX port failed: initial blur API block missing")
text = text.replace(old_initial_blur, new_initial_blur, 1)

old_update_blur = r'''
			if (blur) {
				int blur_optimized = !c->isfloating || blur_xray;
				wlr_scene_buffer_set_backdrop_blur_optimized(buffer, blur_optimized);
			}'''
new_update_blur = r'''
			if (blur && c->blur)
				wlr_scene_blur_set_should_only_blur_bottom_layer(c->blur,
						!c->isfloating || blur_xray);'''
if old_update_blur not in text:
    raise SystemExit("SceneFX port failed: update blur API block missing")
text = text.replace(old_update_blur, new_update_blur, 1)

map_blur_anchor = "\twlr_scene_node_for_each_buffer(&c->scene_surface->node, iter_xdg_scene_buffers, c);"
if map_blur_anchor not in text:
    raise SystemExit("SceneFX port failed: mapped buffer anchor missing")
text = text.replace(map_blur_anchor, r'''
	if (blur) {
		c->blur = wlr_scene_blur_create(c->scene, c->geom.width, c->geom.height);
		wlr_scene_blur_set_should_only_blur_bottom_layer(c->blur, 1);
		wlr_scene_node_lower_to_bottom(&c->blur->node);
	}
	wlr_scene_node_for_each_buffer(&c->scene_surface->node, iter_xdg_scene_buffers, c);''', 1)

resize_blur_anchor = "\twlr_scene_subsurface_tree_set_clip(&c->scene_surface->node, &clip);"
if resize_blur_anchor not in text:
    raise SystemExit("SceneFX port failed: resize blur anchor missing")
text = text.replace(resize_blur_anchor, resize_blur_anchor + r'''
	if (blur && c->blur) {
		wlr_scene_blur_set_size(c->blur, c->geom.width, c->geom.height);
		wlr_scene_blur_set_clipped_region(c->blur, (struct clipped_region) {
			.corners = corner_radii_none(),
			.area = { c->bw, c->bw, c->geom.width - 2 * c->bw,
				c->geom.height - 2 * c->bw }
		});
	}''', 1)

text = text.replace(
    ".corner_radius = c->corner_radius + c->bw,\n\t\t.corners = CORNER_LOCATION_ALL,",
    ".corners = corner_radii_all(c->corner_radius + c->bw),",
    1,
)
text = text.replace(
    "wlr_scene_rect_set_corner_radius(c->round_border, radius, CORNER_LOCATION_ALL);",
    "wlr_scene_rect_set_corner_radius(c->round_border, radius);",
    1,
)
text = text.replace(
    "wlr_scene_buffer_set_corner_radius(buffer, radius, CORNER_LOCATION_ALL);",
    "wlr_scene_buffer_set_corner_radius(buffer, radius);",
    1,
)

# Forward native libinput touchpad gestures through the standard Wayland
# pointer-gestures protocol. Chromium/Brave use this for two-finger pinch zoom.
include_anchor = "#include <wlr/types/wlr_pointer_constraints_v1.h>"
if include_anchor not in text:
    raise SystemExit("gesture patch failed: pointer include anchor missing")
text = text.replace(
    include_anchor,
    include_anchor + "\n#include <wlr/types/wlr_pointer_gestures_v1.h>",
    1,
)

prototype_anchor = "static void buttonpress(struct wl_listener *listener, void *data);"
if prototype_anchor not in text:
    raise SystemExit("gesture patch failed: function prototype anchor missing")
text = text.replace(prototype_anchor, prototype_anchor + r'''
static void swipebegin(struct wl_listener *listener, void *data);
static void swipeupdate(struct wl_listener *listener, void *data);
static void swipeend(struct wl_listener *listener, void *data);
static void pinchbegin(struct wl_listener *listener, void *data);
static void pinchupdate(struct wl_listener *listener, void *data);
static void pinchend(struct wl_listener *listener, void *data);
static void holdbegin(struct wl_listener *listener, void *data);
static void holdend(struct wl_listener *listener, void *data);''', 1)

manager_anchor = "static struct wlr_pointer_constraints_v1 *pointer_constraints;"
if manager_anchor not in text:
    raise SystemExit("gesture patch failed: manager anchor missing")
text = text.replace(
    manager_anchor,
    "static struct wlr_pointer_gestures_v1 *pointer_gestures;\n" + manager_anchor,
    1,
)

listener_anchor = "static struct wl_listener cursor_button = {.notify = buttonpress};"
if listener_anchor not in text:
    raise SystemExit("gesture patch failed: listener anchor missing")
text = text.replace(listener_anchor, listener_anchor + r'''
static struct wl_listener cursor_swipe_begin = {.notify = swipebegin};
static struct wl_listener cursor_swipe_update = {.notify = swipeupdate};
static struct wl_listener cursor_swipe_end = {.notify = swipeend};
static struct wl_listener cursor_pinch_begin = {.notify = pinchbegin};
static struct wl_listener cursor_pinch_update = {.notify = pinchupdate};
static struct wl_listener cursor_pinch_end = {.notify = pinchend};
static struct wl_listener cursor_hold_begin = {.notify = holdbegin};
static struct wl_listener cursor_hold_end = {.notify = holdend};''', 1)

handler_anchor = "\nvoid\nbuttonpress(struct wl_listener *listener, void *data)\n{"
if handler_anchor not in text:
    raise SystemExit("gesture patch failed: handler anchor missing")
gesture_handlers = r'''

void
swipebegin(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_swipe_begin_event *event = data;
    wlr_idle_notifier_v1_notify_activity(idle_notifier, seat);
    wlr_pointer_gestures_v1_send_swipe_begin(pointer_gestures, seat,
            event->time_msec, event->fingers);
}

void
swipeupdate(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_swipe_update_event *event = data;
    wlr_pointer_gestures_v1_send_swipe_update(pointer_gestures, seat,
            event->time_msec, event->dx, event->dy);
}

void
swipeend(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_swipe_end_event *event = data;
    wlr_pointer_gestures_v1_send_swipe_end(pointer_gestures, seat,
            event->time_msec, event->cancelled);
}

void
pinchbegin(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_pinch_begin_event *event = data;
    wlr_idle_notifier_v1_notify_activity(idle_notifier, seat);
    wlr_pointer_gestures_v1_send_pinch_begin(pointer_gestures, seat,
            event->time_msec, event->fingers);
}

void
pinchupdate(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_pinch_update_event *event = data;
    wlr_pointer_gestures_v1_send_pinch_update(pointer_gestures, seat,
            event->time_msec, event->dx, event->dy, event->scale,
            event->rotation);
}

void
pinchend(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_pinch_end_event *event = data;
    wlr_pointer_gestures_v1_send_pinch_end(pointer_gestures, seat,
            event->time_msec, event->cancelled);
}

void
holdbegin(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_hold_begin_event *event = data;
    wlr_idle_notifier_v1_notify_activity(idle_notifier, seat);
    wlr_pointer_gestures_v1_send_hold_begin(pointer_gestures, seat,
            event->time_msec, event->fingers);
}

void
holdend(struct wl_listener *listener, void *data)
{
    struct wlr_pointer_hold_end_event *event = data;
    wlr_pointer_gestures_v1_send_hold_end(pointer_gestures, seat,
            event->time_msec, event->cancelled);
}
'''
text = text.replace(handler_anchor, gesture_handlers + handler_anchor, 1)

cleanup_anchor = "\twl_list_remove(&cursor_button.link);"
if cleanup_anchor not in text:
    raise SystemExit("gesture patch failed: cleanup anchor missing")
text = text.replace(cleanup_anchor, cleanup_anchor + r'''
	wl_list_remove(&cursor_swipe_begin.link);
	wl_list_remove(&cursor_swipe_update.link);
	wl_list_remove(&cursor_swipe_end.link);
	wl_list_remove(&cursor_pinch_begin.link);
	wl_list_remove(&cursor_pinch_update.link);
	wl_list_remove(&cursor_pinch_end.link);
	wl_list_remove(&cursor_hold_begin.link);
	wl_list_remove(&cursor_hold_end.link);''', 1)

protocol_anchor = "\trelative_pointer_mgr = wlr_relative_pointer_manager_v1_create(dpy);"
if protocol_anchor not in text:
    raise SystemExit("gesture patch failed: protocol anchor missing")
text = text.replace(
    protocol_anchor,
    protocol_anchor + "\n\tpointer_gestures = wlr_pointer_gestures_v1_create(dpy);",
    1,
)

signal_anchor = "\twl_signal_add(&cursor->events.button, &cursor_button);"
if signal_anchor not in text:
    raise SystemExit("gesture patch failed: cursor signal anchor missing")
text = text.replace(signal_anchor, signal_anchor + r'''
	wl_signal_add(&cursor->events.swipe_begin, &cursor_swipe_begin);
	wl_signal_add(&cursor->events.swipe_update, &cursor_swipe_update);
	wl_signal_add(&cursor->events.swipe_end, &cursor_swipe_end);
	wl_signal_add(&cursor->events.pinch_begin, &cursor_pinch_begin);
	wl_signal_add(&cursor->events.pinch_update, &cursor_pinch_update);
	wl_signal_add(&cursor->events.pinch_end, &cursor_pinch_end);
	wl_signal_add(&cursor->events.hold_begin, &cursor_hold_begin);
	wl_signal_add(&cursor->events.hold_end, &cursor_hold_end);''', 1)

# Scene-independent bottom-stack layout used by Super+Up/Down. Keep this in
# the private build patcher so the user's upstream dwl checkout stays clean.
prototype_anchor = "static void tile(Monitor *m);"
if prototype_anchor not in text:
    raise SystemExit("horizontal layout patch failed: tile prototype missing")
text = text.replace(
    prototype_anchor,
    "static void bstack(Monitor *m);\nstatic void sethorizontalmfact(const Arg *arg);\nstatic void togglelayoutorientation(const Arg *arg);\n" + prototype_anchor,
    1,
)

tile_anchor = "\nvoid\ntile(Monitor *m)\n{"
if tile_anchor not in text:
    raise SystemExit("horizontal layout patch failed: tile function missing")
horizontal_code = r'''

void
bstack(Monitor *m)
{
    unsigned int mh, mx, sx;
    int i, n = 0;
    Client *c;

    wl_list_for_each(c, &clients, link)
        if (VISIBLEON(c, m) && !c->isfloating && !c->isfullscreen)
            n++;
    if (n == 0)
        return;

    if (n > m->nmaster)
        mh = m->nmaster ? (int)roundf(m->w.height * m->mfact) : 0;
    else
        mh = m->w.height;
    i = mx = sx = 0;
    wl_list_for_each(c, &clients, link) {
        if (!VISIBLEON(c, m) || c->isfloating || c->isfullscreen)
            continue;
        if (i < m->nmaster) {
            resize(c, (struct wlr_box){.x = m->w.x + mx, .y = m->w.y,
                .width = (m->w.width - mx) / (MIN(n, m->nmaster) - i), .height = mh}, 0);
            mx += c->geom.width;
        } else {
            resize(c, (struct wlr_box){.x = m->w.x + sx, .y = m->w.y + mh,
                .width = (m->w.width - sx) / (n - i), .height = m->w.height - mh}, 0);
            sx += c->geom.width;
        }
        i++;
    }
}

void
sethorizontalmfact(const Arg *arg)
{
    Arg layout = {.v = &layouts[3]};

    if (!selmon)
        return;
    if (selmon->lt[selmon->sellt] != &layouts[3])
        setlayout(&layout);
    setmfact(arg);
}

void
togglelayoutorientation(const Arg *arg)
{
    Arg layout = {.v = selmon && selmon->lt[selmon->sellt] == &layouts[3]
        ? &layouts[0] : &layouts[3]};

    if (selmon)
        setlayout(&layout);
}
'''
text = text.replace(tile_anchor, horizontal_code + tile_anchor, 1)

resize_anchor = "\tc->geom = geo;\n\tapplybounds(c, bbox);"
if resize_anchor not in text:
    raise SystemExit("geometry safety patch failed: resize geometry anchor missing")
text = text.replace(resize_anchor, '''\tc->geom = geo;
\tapplybounds(c, bbox);
\t/* Never pass a negative surface size to wlroots. Borders are part of
\t * geom, so the content must retain at least one pixel beyond both. */
\tc->geom.width = MAX((int)(2 * c->bw + 1), c->geom.width);
\tc->geom.height = MAX((int)(2 * c->bw + 1), c->geom.height);''', 1)
path.write_text(text, encoding="utf-8")
print(f"patched {path}")
