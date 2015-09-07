module PanZoom

using Gtk, Compat
import Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
import Gtk.GConstants.GdkModifierType: SHIFT, CONTROL, MOD1
import Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL
import Gtk.GdkEventType: BUTTON_PRESS, DOUBLE_BUTTON_PRESS
import Gtk.GConstants.GdkScrollDirection: UP, DOWN
import Base: *

if VERSION < v"0.4.0-dev"
    using Docile, Base.Graphics
else
    using Graphics
end

using ..GtkUtilities.Link
import ..guidata, ..trigger, ..rubberband_start
import ..Link: AbstractState

typealias VecLike Union{AbstractVector,Tuple}

export
    # Types
    Interval,
    # constants
    GDK_KEY_Left,
    GDK_KEY_Right,
    GDK_KEY_Up,
    GDK_KEY_Down,
    SHIFT,
    CONTROL,
    ALT,
    # functions
    interior,
    fullview,
    panzoom,
    add_pan_key,
    add_pan_mouse,
    add_zoom_key,
    add_zoom_mouse

const ALT = MOD1

@doc """
An `Interval` is a `(min,max)` pair. It is the one-dimensional analog
of a `BoundingBox`.
""" ->
immutable Interval{T}
    min::T
    max::T
end
Base.convert{T}(::Type{Interval{T}}, v::Interval{T}) = v
Base.convert{T}(::Type{Interval{T}}, v::Interval) = Interval{T}(v.min, v.max)
function Base.convert{T}(::Type{Interval{T}}, v::VecLike)
    v1, v2 = v[1], v[end]
    Interval{T}(min(v1,v2), max(v1,v2))
end

Graphics.width(iv::Interval) = iv.max-iv.min
(Base.&)(iv1::Interval, iv2::Interval) = Interval(max(iv1.min, iv2.min),
                                             min(iv1.max, iv2.max))
Graphics.shift(iv::Interval, dx) = deform(iv, dx, dx)
function (*)(s::Real, iv::Interval)
    dx = 0.5*(s - 1)*width(iv)
    deform(iv, -dx, dx)
end
(*)(iv::Interval, s::Real) = s*iv
Graphics.deform(iv::Interval, dmin, dmax) = Interval(iv.min+dmin, iv.max+dmax)

@doc """
`ivnew = interior(iv, limits)` returns a new version of `iv`, an
`Interval`, which is inside the region allowd by `limits`. One
should prefer "shifting" `iv` over "shrinking" `iv` (if possible, the
width of `iv` should be preserved).

If `limits == nothing`, then `iv` is unconstrained and `ivnew == iv`.

The simplest effectual `limits` object is another `Interval`
representing the full view interval across the chosen axis. If you
need more sophisticated behavior, you can extend this function to work
with custom types of `limits` objects.
""" ->
interior(iv, ::Void) = iv

function interior(iv, limits::Interval)
    imin, imax = iv.min, iv.max
    if imin < limits.min
        imin = limits.min
        imax = imin + width(iv)
    elseif imax > limits.max
        imax = limits.max
        imin = imax - width(iv)
    end
    Interval(imin, imax) & limits
end

@doc """
`iv = fullview(limits)` returns an `Interval` `iv` that
encompases the full view as permitted by `limits`.

If `limits == nothing`, then `fullview` returns `nothing`.

The simplest effectual `limits` object is another `Interval`
representing the "whole canvas" along the chosen axis. If you need
more sophisticated behavior, you can extend this function to work with
custom types of `limits` objects.
""" ->
fullview(::Void) = nothing

fullview(limits::Interval) = limits

@doc """
```jl
panzoom(c)
panzoom(c, viewxlimits, viewylimits)
panzoom(c, viewxlimits, viewylimits, viewx, viewy)
```
sets up the Canvas `c` for panning and zooming. The arguments may be
2-tuples, 2-vectors, Intervals, or `nothing`.

`panzoom` creates the `:view[x|y]`, `:view[x|y]limits` properties of
`c`:

- `:viewx`, `:viewy` are two `AbstractState`s (for horizontal and
    vertical, respectively), each holding an Interval specifying
    the current "view" limits. This might be the entire area, or it
    might be a subregion due to a previous zoom event.

- `:viewxlimits`, `:viewylimits` encode the maximum allowable viewing
    region; in most cases these will also be `State{Interval}`s, but
    any object that supports `interior` and `fullview` may be used.
    Use `nothing` to indicate unlimited range.

If `c` is the only argument to `panzoom`, then the current user-coordinate
limits of `c` are used.
""" ->
panzoom(c, viewxlimits::Interval, viewylimits::Interval) =
    panzoom(c, State(viewxlimits), State(viewylimits))

panzoom(c, viewxlimits::VecLike, viewylimits::VecLike) = panzoom(c, iv(viewxlimits), iv(viewylimits))

panzoom(c, viewxlimits::Union{VecLike,Void}, viewylimits::Union{VecLike,Void}, viewx::VecLike, viewy::VecLike) = panzoom(c, State(iv(viewxlimits)), State(iv(viewylimits)), State(iv(viewx)), State(iv(viewy)))

function panzoom(c, viewxlimits::AbstractState, viewylimits::AbstractState, viewx::AbstractState = similar(viewxlimits), viewy::AbstractState = similar(viewylimits))
    guidata[c, :viewx] = viewx
    guidata[c, :viewy] = viewy
    guidata[c, :viewxlimits] = viewxlimits
    guidata[c, :viewylimits] = viewylimits
    link(viewx, c)
    link(viewy, c)
    nothing
end

function panzoom(c)
    xmin, ymin = device_to_user(c, 0, 0)
    xmax, ymax = device_to_user(c, width(c), height(c))
    panzoom(c, (xmin, xmax), (ymin, ymax))
end

iv(x) = Interval{Float64}(x...)
iv(x::Void) = x

pan(iv, frac::Real, limits) = interior(shift(iv, frac*width(iv)), limits)

zoom(iv, s::Real, limits) = interior(s*iv, limits)

@doc """
`id = add_pan_key(c; kwargs...)` initializes panning-by-keypress for a
canvas `c`. `c` is expected to have the four `guidata` properties
described in `panzoom`.

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
    panzoom(c, (0,1), (0,1))
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
        viewx = guidata[c, :viewx]
        viewy = guidata[c, :viewy]
        viewxlimits = guidata[c, :viewxlimits]
        viewylimits = guidata[c, :viewylimits]
        if keymatch(event, panleft)
            viewx = pan(viewx, -0.1, viewxlimits)
        elseif keymatch(event, panright)
            viewx = pan(viewx,  0.1, viewxlimits)
        elseif keymatch(event, panup)
            viewy = pan(viewy, -0.1, viewylimits)
        elseif keymatch(event, pandown)
            viewy = pan(viewy,  0.1, viewylimits)
        elseif keymatch(event, panleft_big)
            viewx = pan(viewx, -1, viewxlimits)
        elseif keymatch(event, panright_big)
            viewx = pan(viewx,  1, viewxlimits)
        elseif keymatch(event, panup_big)
            viewy = pan(viewy, -1, viewylimits)
        elseif keymatch(event, pandown_big)
            viewy = pan(viewy,  1, viewylimits)
        end
        guidata[c, :viewx] = viewx
        guidata[c, :viewy] = viewy
        nothing
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
    panzoom(c, (0,1), (0,1))
    id = add_pan_mouse(c)
```
""" ->
function add_pan_mouse(c;
                       panhoriz = SHIFT,
                       panvert  = 0)
    add_events(c, SCROLL)
    signal_connect(c, :scroll_event) do widget, event
        viewx = guidata[c, :viewx]
        viewy = guidata[c, :viewy]
        viewxlimits = guidata[c, :viewxlimits]
        viewylimits = guidata[c, :viewylimits]
        s = 0.1*scrollpm(event.direction)
        if     event.state == @compat(UInt32(panhoriz))
            viewx = pan(viewx, s, viewxlimits)
        elseif event.state == @compat(UInt32(panvert))
            viewy = pan(viewy, s, viewylimits)
        end
        guidata[c, :viewx] = viewx
        guidata[c, :viewy] = viewy
        nothing
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
    panzoom(c, (0,1), (0,1))
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
        viewx = guidata[c, :viewx]
        viewy = guidata[c, :viewy]
        viewxlimits = guidata[c, :viewxlimits]
        viewylimits = guidata[c, :viewylimits]
        s = 1.0
        if keymatch(event, in)
            s = 0.5
        elseif keymatch(event, out)
            s = 2.0
        end
        viewx = zoom(viewx, s, viewxlimits)
        viewy = zoom(viewy, s, viewylimits)
        guidata[c, :viewx] = viewx
        guidata[c, :viewy] = viewy
        nothing
    end
end

@doc """
`id = add_zoom_mouse(c; kwargs...)` initializes zooming-by-rubberband
selection and zooming-by-mouse-scroll for a canvas `c`.

Zooming-by-scroll is accompanied by a modifier key, which is
configurable through keyword arguments.  The keywords and their
defaults are:
```
    mod       = CONTROL,     # hold down the ctrl-key while scrolling
    focus     = :pointer
    factor    = 2.0
    initiate  = BUTTON_PRESS # start a rubberband selection for zoom
    reset     = DOUBLE_BUTTON_PRESS    # go back to original limits
```
CONTROL, BUTTON_PRESS, and DOUBLE_BUTTON_PRESS are defined in
`Gtk.GConstants.GdkModifierType`.

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
    panzoom(c, (0,1), (0,1))
    id = add_zoom_mouse(c)
```
`id` will be a single integer if `reset = nothing` (which disables
resetting), or a 2-tuple corresponding to the handlers for scroll and
reset, respectively.
""" ->
function add_zoom_mouse(c;
                        mod = CONTROL,
                        focus::Symbol = :pointer,
                        factor = 2.0,
                        initiate = BUTTON_PRESS,
                        reset = DOUBLE_BUTTON_PRESS)
    add_events(c, SCROLL)
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    id1 = signal_connect(zoom_mouse_button_cb, c, "button-press-event", Cint, (Ptr{Gtk.GdkEventButton},), false, (initiate,reset))
    id2 = signal_connect(zoom_mouse_scroll_cb, c, "scroll-event", Cint, (Ptr{Gtk.GdkEventScroll},), false, (mod, focus, factor))
    (id1, id2)
end

function zoom_mouse_button_cb(widgetp::Ptr, eventp::Ptr, actions)
    widget = convert(Gtk.GtkCanvas, widgetp)
    event = unsafe_load(eventp)
    initiate, reset = actions
    if event.event_type == initiate
        rubberband_start(widget, event.x, event.y, (widget, bb) -> (guidata[widget, :viewx] = (bb.xmin,bb.xmax); guidata[widget, :viewy] = (bb.ymin,bb.ymax)))
        return Cint(1)
    elseif event.event_type == reset
        zoom_reset(widget)
        return Cint(1)
    end
    return Cint(0)
end

function zoom_mouse_scroll_cb(widgetp::Ptr, eventp::Ptr, kws)
    widget = convert(Gtk.GtkCanvas, widgetp)
    event = unsafe_load(eventp)
    mod, focus, factor = kws
    if event.state == @compat(UInt32(mod))
        s = factor
        if event.direction == UP
            s = 1/s
        end
        zoom_focus(widget, s, event; focus=focus)
        return Cint(1)
    end
    return Cint(0)
end

function zoom_focus(c, s, event; focus::Symbol=:pointer)
    viewx = guidata[c, :viewx]
    viewy = guidata[c, :viewy]
    viewxlimits = guidata[c, :viewxlimits]
    viewylimits = guidata[c, :viewylimits]
    if focus == :pointer
        w, h = width(c), height(c)
        fx, fy = event.x/w, event.y/h
        w, h = width(viewx), width(viewy)
        centerx, centery = viewx.min+fx*w, viewy.min+fy*h
        wbb, hbb = s*w, s*h
        viewx = interior(Interval(centerx-fx*wbb,centerx+(1-fx)*wbb), viewxlimits)
        viewy = interior(Interval(centery-fy*hbb,centery+(1-fy)*hbb), viewylimits)
    elseif focus == :center
        viewx = zoom(viewx, s, viewxlimits)
        viewy = zoom(viewy, s, viewylimits)
    end
    getindex(guidata, c, :viewx; raw=true).value = viewx
    getindex(guidata, c, :viewy; raw=true).value = viewy
    trigger(c, (:viewx, :viewy))
    c
end

function zoom_reset(c)
    vxlim, vylim = guidata[c, :viewxlimits], guidata[c, :viewylimits]
    vxlim != nothing && (getindex(guidata, c, :viewx; raw=true).value = vxlim)
    vylim != nothing && (getindex(guidata, c, :viewy; raw=true).value = vylim)
    trigger(c, (:viewx, :viewy))
    c
end

end # module
