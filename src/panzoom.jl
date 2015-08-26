module PanZoom

using Gtk, Compat
import Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
import Gtk.GConstants.GdkModifierType: SHIFT, CONTROL, MOD1
import Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL
import Gtk.GConstants.GdkScrollDirection: UP, DOWN

if VERSION < v"0.4.0-dev+3275"
    using Base.Graphics
else
    using Graphics
end

export
    # constants
    GDK_KEY_Left,
    GDK_KEY_Right,
    GDK_KEY_Up,
    GDK_KEY_Down,
    SHIFT,
    CONTROL,
    ALT,
    # functions
    add_pan_key,
    add_pan_mouse,
    add_zoom_key,
    add_zoom_mouse

const ALT = MOD1


# Any `limits` type should support the following API (`box` is a
# `BoundingBox` as defined in `Graphics`):

#  - `interior(box, limits)` returns a variant of `box` which is
#    inside the region allowd by `limits`. If possible, the width and
#    height of `box` should be preserved.

@doc """
`interior(bb, limits)` returns a variant of `bb`, a `BoundingBox`
which is inside the region allowd by `limits`. One should prefer
"shifting" `bb` over "shrinking" `bb` (if possible, the width and
height of `bb` should be preserved).
""" ->
function interior(bb, limits::BoundingBox)
    xmin, xmax, ymin, ymax = bb.xmin, bb.xmax, bb.ymin, bb.ymax
    if xmin < limits.xmin
        xmin = limits.xmin
        xmax = xmin + width(bb)
    elseif xmax > limits.xmax
        xmax = limits.xmax
        xmin = xmax - width(bb)
    end
    if ymin < limits.ymin
        ymin = limits.ymin
        ymax = ymin + width(bb)
    elseif ymax > limits.ymax
        ymax = limits.ymax
        ymin = ymax - width(bb)
    end
    BoundingBox(xmin, xmax, ymin, ymax) & limits
end

pan(bb, dx, dy, limits) = interior(shift(bb, dx, dy), limits)
panx(bb, frac, limits) = interior(shift(bb, frac*width(bb),  0), limits)
pany(bb, frac, limits) = interior(shift(bb, 0, frac*height(bb)), limits)

zoom(bb, s::Real, limits) = interior(s*bb, limits)

@doc """
`id = add_pan_key(c; kwargs...)` initializes panning-by-keypress for a
canvas `c`.

`c` is expected to have two `guidata` properties, `:viewbb` and
`:viewlimits`.  `:viewbb` is its current "view" `BoundingBox`---this
might be the entire area, or it might be smaller due to a previous
zoom event.  `:viewlimits` encodes the maximum allowable viewing
region; in most cases it will be another `BoundingBox`, but any object
that supports `interior` may be used.

You can configure the keys through keyword arguments. The default
settings are shown below. The first entry is the key, the second a
modifier (like the SHIFT key); `0` means no modifier.

```
    panleft      = (GDK_KEY_Left,0),
    panright     = (GDK_KEY_Right,0),
    panup        = (GDK_KEY_Up,0),
    pandown      = (GDK_KEY_Down,0),
    panleft_big  = (GDK_KEY_Left,SHIFT),
    panright_big = (GDK_KEY_Right,SHIFT),
    panup_big    = (GDK_KEY_Up,SHIFT),
    pandown_big  = (GDK_KEY_Down,SHIFT))
```
"Regular" panning motions correspond to 10% of the view region; "big"
panning motions are 100% of the view region, and thus jump by one
whole view area.  The constants are defined in `Gtk.GConstants` and
the modifiers in `Gtk.GConstants.GdkModifierType`.

The returned `id` can be disabled or enabled via
`signal_handler_block` and `signal_handler_unblock`, respectively, or
removed with `signal_handler_disconnect`.

Example:
```
    c = @Canvas()
    bb = BoundingBox(0,1,0,1)
    guidata[c, :viewlimits] = bb      # the "outer" limits of the plot
    guidata[c, :viewbb] = bb          # set the initial view to the whole view
    id = add_pan_keys(c)
```
The `draw` method for `c` should take account of `:viewbb`.
""" ->
function add_pan_key(c;
                     panleft  = (GDK_KEY_Left,0),
                     panright = (GDK_KEY_Right,0),
                     panup    = (GDK_KEY_Up,0),
                     pandown  = (GDK_KEY_Down,0),
                     panleft_big  = (GDK_KEY_Left,SHIFT),
                     panright_big = (GDK_KEY_Right,SHIFT),
                     panup_big    = (GDK_KEY_Up,SHIFT),
                     pandown_big  = (GDK_KEY_Down,SHIFT))
    add_events(c, KEY_PRESS)
    setproperty!(c, :can_focus, true)
    setproperty!(c, :has_focus, true)
    signal_connect(c, :key_press_event) do widget, event
        bb     = Main.GtkUtilities.guidata[c, :viewbb]
        limits = Main.GtkUtilities.guidata[c, :viewlimits]
        bb0 = bb
        if keymatch(event, panleft)
            bb = panx(bb, -0.1, limits)
        elseif keymatch(event, panright)
            bb = panx(bb,  0.1, limits)
        elseif keymatch(event, panup)
            bb = pany(bb, -0.1, limits)
        elseif keymatch(event, pandown)
            bb = pany(bb,  0.1, limits)
        elseif keymatch(event, panleft_big)
            bb = panx(bb, -1, limits)
        elseif keymatch(event, panright_big)
            bb = panx(bb,  1, limits)
        elseif keymatch(event, panup_big)
            bb = pany(bb, -1, limits)
        elseif keymatch(event, pandown_big)
            bb = pany(bb,  1, limits)
        end
        if bb != bb0
            Main.GtkUtilities.guidata[c, :viewbb] = bb
            draw(c)
        end
    end
end

keymatch(event, keydesc) = event.keyval == keydesc[1] && event.state == @compat(UInt32(keydesc[2]))

@doc """
`id = add_pan_mouse(c; kwargs...)` initializes panning-by-mouse-scroll
for a canvas `c`.

Horizontal or vertical panning is selected by modifier keys, which are
configurable through keyword arguments.  The default settings are:
```
    panhoriz = SHIFT,     # hold down the shift key
    panvert  = 0
```
where 0 means no modifier. SHIFT is defined in `Gtk.GConstants.GdkModifierType`.

For important additional information, see `add_pan_key`.

Example:
```
    c = @Canvas()
    bb = BoundingBox(0,1,0,1)
    guidata[c, :viewlimits] = bb      # the "outer" limits of the plot
    guidata[c, :viewbb] = bb          # set the initial view to the whole view
    id = add_pan_mouse(c)
```
""" ->
function add_pan_mouse(c;
                       panhoriz = SHIFT,
                       panvert  = 0)
    add_events(c, SCROLL)
    signal_connect(c, :scroll_event) do widget, event
        bb     = Main.GtkUtilities.guidata[c, :viewbb]
        limits = Main.GtkUtilities.guidata[c, :viewlimits]
        bb0 = bb
        if     event.state == @compat(UInt32(panhoriz))
            bb = panx(bb, 0.1*scrollpm(event.direction), limits)
        elseif event.state == @compat(UInt32(panvert))
            bb = pany(bb, 0.1*scrollpm(event.direction), limits)
        end
        if bb != bb0
            Main.GtkUtilities.guidata[c, :viewbb] = bb
            draw(c)
        end
    end
end

scrollpm(direction::Integer) =
    direction == UP ? -1 :
    direction == DOWN ? 1 : error("Direction ", direction, " not recognized")


@doc """
`id = add_zoom_key(c; kwargs...)` initializes zooming-by-keypress
for a canvas `c`.

The keys that initiate zooming are chosen through keyword arguments,
with default values:

```
    in        = (GDK_KEY_Up,  CONTROL)
    out       = (GDK_KEY_Down,CONTROL)
```
In other words, by default press Ctrl-Up to zoom in, and Ctrl-Down to
zoom out.

For important additional information, see `add_pan_key`.

Example:
```
    c = @Canvas()
    bb = BoundingBox(0,1,0,1)
    guidata[c, :viewlimits] = bb      # the "outer" limits of the plot
    guidata[c, :viewbb] = bb          # set the initial view to the whole view
    id = add_zoom_key(c)
```
""" ->
function add_zoom_key(c;
                     in  = (GDK_KEY_Up,  CONTROL),
                     out = (GDK_KEY_Down,CONTROL))
    add_events(c, KEY_PRESS)
    setproperty!(c, :can_focus, true)
    setproperty!(c, :has_focus, true)
    signal_connect(c, :key_press_event) do widget, event
        bb     = Main.GtkUtilities.guidata[c, :viewbb]
        limits = Main.GtkUtilities.guidata[c, :viewlimits]
        bb0 = bb
        if keymatch(event, in)
            bb = zoom(bb, 0.5, limits)
        elseif keymatch(event, out)
            bb = zoom(bb, 2.0, limits)
        end
        if bb != bb0
            Main.GtkUtilities.guidata[c, :viewbb] = bb
            draw(c)
        end
    end
end

@doc """
`id = add_zoom_mouse(c; kwargs...)` initializes zooming-by-mouse-scroll
for a canvas `c`.

Zooming is selected by a modifier key, which is configurable through
keyword arguments.  The keywords and their defaults are:
```
    mod   = CONTROL,     # hold down the ctrl-key
    focus = :pointer
```
CONTROL is defined in `Gtk.GConstants.GdkModifierType`, and 0 means no
modifier.

The `focus` keyword controls how the zooming progresses as you scroll
the mouse wheel. `:pointer` means that whatever feature of the canvas
is under the pointer will stay there as you zoom in or out. The other
choice, `:center`, keeps the canvas centered on its current location.
These behaviors are subject to modification by the canvas'
`:viewlimits` data.

For important additional information, see `add_pan_key`.

Example:
```
    c = @Canvas()
    bb = BoundingBox(0,1,0,1)
    guidata[c, :viewlimits] = bb      # the "outer" limits of the plot
    guidata[c, :viewbb] = bb          # set the initial view to the whole view
    id = add_zoom_mouse(c)
```
""" ->
function add_zoom_mouse(c;
                        mod = CONTROL,
                        focus::Symbol = :pointer)
    add_events(c, SCROLL)
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    signal_connect(c, :scroll_event) do widget, event
        bb     = Main.GtkUtilities.guidata[c, :viewbb]
        limits = Main.GtkUtilities.guidata[c, :viewlimits]
        bb0 = bb
        if event.state == @compat(UInt32(mod))
            s = 0.5
            if event.direction == DOWN
                s = 1/s
            end
            if focus == :pointer
                w, h = width(c), height(c)
                fx, fy = event.x/w, event.y/h
                w, h = width(bb), height(bb)
                centerx, centery = bb.xmin+fx*w, bb.ymin+fy*h
                wbb, hbb = s*w, s*h
                bb = interior(BoundingBox(centerx-fx*wbb,centerx+(1-fx)*wbb,centery-fy*hbb,centery+(1-fy)*hbb), limits)
            elseif focus == :center
                bb = zoom(bb, s, limits)
            end
        end
        if bb != bb0
            Main.GtkUtilities.guidata[c, :viewbb] = bb
            draw(c)
        end
    end
end

end
