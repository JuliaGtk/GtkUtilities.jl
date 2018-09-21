module PanZoom

using Gtk
import Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
import Gtk.GConstants.GdkModifierType: SHIFT, CONTROL, MOD1
import Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL
import Gtk.GdkEventType: BUTTON_PRESS, DOUBLE_BUTTON_PRESS
import Gtk.GConstants.GdkScrollDirection: UP, DOWN, LEFT, RIGHT
import Base: *, &

using Graphics

using ..GtkUtilities.Link
import ..guidata, ..trigger, ..rubberband_start
import ..Link: AbstractState

const VecLike = Union{AbstractVector,Tuple}

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
    panzoom_key,
    panzoom_mouse,
    zoom_reset

const ALT = MOD1

"""
An `Interval` is a `(min,max)` pair. It is the one-dimensional analog
of a `BoundingBox`.
"""
struct Interval{T}
    min::T
    max::T
end

Base.convert(::Type{Interval{T}}, v::Interval{T}) where T = v
Base.convert(::Type{Interval{T}}, v::Interval)  where T = Interval{T}(v.min, v.max)
function Base.convert(::Type{Interval{T}}, v::VecLike) where T
    v1, v2 = first(v), last(v)
    Interval{T}(min(v1,v2), max(v1,v2))
end

Graphics.width(iv::Interval) = iv.max-iv.min
(&)(iv1::Interval, iv2::Interval) = Interval(max(iv1.min, iv2.min),
                                             min(iv1.max, iv2.max))
Graphics.shift(iv::Interval, dx) = deform(iv, dx, dx)
function (*)(s::Real, iv::Interval)
    dx = 0.5*(s - 1)*width(iv)
    deform(iv, -dx, dx)
end
(*)(iv::Interval, s::Real) = s*iv
Graphics.deform(iv::Interval, dmin, dmax) = Interval(iv.min+dmin, iv.max+dmax)

"""
`ivnew = interior(iv, limits)` returns a new version of `iv`, an
`Interval`, which is inside the region allowd by `limits`. One
should prefer "shifting" `iv` over "shrinking" `iv` (if possible, the
width of `iv` should be preserved).

If `limits == nothing`, then `iv` is unconstrained and `ivnew == iv`.

The simplest effectual `limits` object is another `Interval`
representing the full view interval across the chosen axis. If you
need more sophisticated behavior, you can extend this function to work
with custom types of `limits` objects.
"""
interior(iv, ::Nothing) = iv

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

"""
`iv = fullview(limits)` returns an `Interval` `iv` that
encompases the full view as permitted by `limits`.

If `limits == nothing`, then `fullview` returns `nothing`.

The simplest effectual `limits` object is another `Interval`
representing the "whole canvas" along the chosen axis. If you need
more sophisticated behavior, you can extend this function to work with
custom types of `limits` objects.
"""
fullview(::Nothing) = nothing

fullview(limits::Interval) = limits

"""
```jl
panzoom(c)
panzoom(c, xviewlimits, yviewlimits)
panzoom(c, xviewlimits, yviewlimits, xview, yview)
panzoom(c2, c1)
```
sets up the Canvas `c` for panning and zooming. The arguments may be
2-tuples, 2-vectors, Intervals, or `nothing`.

`panzoom` creates the `:view[x|y]`, `:view[x|y]limits` properties of
`c`:

- `:xview`, `:yview` are two `AbstractState`s (for horizontal and
    vertical, respectively), each holding an Interval specifying
    the current "view" limits. This might be the entire area, or it
    might be a subregion due to a previous zoom event.

- `:xviewlimits`, `:yviewlimits` encode the maximum allowable viewing
    region; in most cases these will also be `State{Interval}`s, but
    any object that supports `interior` and `fullview` may be used.
    Use `nothing` to indicate unlimited range.

If `c` is the only argument to `panzoom`, then the current user-coordinate
limits of `c` are used.  Note that this invocation works only if the
Canvas has been drawn at least once; if that is not the case, you need
to specify the limits manually.

`panzoom(c2, c1)` sets canvas `c2` to share pan/zoom state with canvas
`c1`.  Panning or zooming in either one will cause the same action in
the other.
"""
panzoom(c, xviewlimits::Interval, yviewlimits::Interval) =
    panzoom(c, State(xviewlimits), State(yviewlimits))

panzoom(c, xviewlimits::VecLike, yviewlimits::VecLike) = panzoom(c, iv(xviewlimits), iv(yviewlimits))

panzoom(c, xviewlimits::Union{VecLike,Nothing}, yviewlimits::Union{VecLike,Nothing}, xview::VecLike, yview::VecLike) = panzoom(c, State(iv(xviewlimits)), State(iv(yviewlimits)), State(iv(xview)), State(iv(yview)))

function panzoom(c, xviewlimits::AbstractState, yviewlimits::AbstractState, xview::AbstractState = similar(xviewlimits), yview::AbstractState = similar(yviewlimits))
    panzoom_disconnect(c)
    if !haskey(guidata, c)
        guidata[c, :xview] = xview
    end
    d = guidata[c]
    d[:xview] = xview
    d[:yview] = yview
    d[:xviewlimits] = xviewlimits
    d[:yviewlimits] = yviewlimits
    link(xview, c)
    link(yview, c)
    nothing
end

const empty_view = State(Interval(0.0, -1.0))

function panzoom(c2, c1)
    panzoom_disconnect(c2)
    d1, d2 = guidata[c1], guidata[c2]
    for s in (:xview, :yview, :xviewlimits, :yviewlimits)
        d2[s] = d1[s]
    end
    link(d2[:xview], c2)
    link(d2[:yview], c2)
    nothing
end

function panzoom(c)
    gc = getgc(c)
    xmin, ymin = device_to_user(gc, 0, 0)
    xmax, ymax = device_to_user(gc, width(c), height(c))
    panzoom(c, (xmin, xmax), (ymin, ymax))
end

function panzoom_disconnect(c)
    for s in (:xview, :yview)
        v = get(guidata, (c, s), empty_view; raw=true)
        if v != empty_view
            disconnect(v, c)
        end
    end
    nothing
end

iv(x) = Interval{Float64}(x...)
iv(x::Interval) = convert(Interval{Float64}, x)
iv(x::State) = iv(get(x))
iv(x::Nothing) = x

pan(iv, frac::Real, limits) = interior(shift(iv, frac*width(iv)), limits)

zoom(iv, s::Real, limits) = interior(s*iv, limits)

"""
`id = panzoom_key(c; kwargs...)` initializes panning- and
zooming-by-keypress for a canvas `c`. `c` is expected to have the four
`guidata` properties described in `panzoom`.

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
    pandown_big  = (GDK_KEY_Down,SHIFT),
    xpanflip     = false,
    ypanflip     = false
    zoomin       = (GDK_KEY_Up,  CONTROL)
    zoomout      = (GDK_KEY_Down,CONTROL)
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
    c = Canvas()
    panzoom(c, (0,1), (0,1))
    id = panzoom_key(c)
```
The `draw` method for `c` should take account of `:viewbb`.
"""
function panzoom_key(c;
                     panleft  = (GDK_KEY_Left,0),
                     panright = (GDK_KEY_Right,0),
                     panup    = (GDK_KEY_Up,0),
                     pandown  = (GDK_KEY_Down,0),
                     panleft_big  = (GDK_KEY_Left,SHIFT),
                     panright_big = (GDK_KEY_Right,SHIFT),
                     panup_big    = (GDK_KEY_Up,SHIFT),
                     pandown_big  = (GDK_KEY_Down,SHIFT),
                     xpanflip     = false,
                     ypanflip     = false,
                     zoomin       = (GDK_KEY_Up,  CONTROL),
                     zoomout      = (GDK_KEY_Down,CONTROL))
    add_events(c, KEY_PRESS)
    set_gtk_property!(c, :can_focus, true)
    set_gtk_property!(c, :has_focus, true)
    signal_connect(key_cb, c, :key_press_event, Cint, (Ptr{Gtk.GdkEventKey},),
                   false, (panleft, panright, panup, pandown, panleft_big,
                           panright_big, panup_big, pandown_big, xpanflip,
                           ypanflip, zoomin, zoomout))
end

@guarded Cint(false) function key_cb(widgetp, eventp, user_data)
    c = convert(GtkCanvas, widgetp)
    event = unsafe_load(eventp)
    (panleft, panright, panup, pandown, panleft_big, panright_big,
     panup_big, pandown_big, xpanflip, ypanflip, zoomin, zoomout) = user_data
    xview = guidata[c, :xview]
    yview = guidata[c, :yview]
    xviewlimits = guidata[c, :xviewlimits]
    yviewlimits = guidata[c, :yviewlimits]
    xsign = xpanflip ? -1 : 1
    ysign = ypanflip ? -1 : 1
    handled = Cint(true)
    ret = Cint(false)
    if keymatch(event, panleft)
        guidata[c, :xview] = pan(xview, -0.1*xsign, xviewlimits)
        ret = handled
    elseif keymatch(event, panright)
        guidata[c, :xview] = pan(xview,  0.1*xsign, xviewlimits)
        ret = handled
    elseif keymatch(event, panup)
        guidata[c, :yview] = pan(yview, -0.1*ysign, yviewlimits)
        ret = handled
    elseif keymatch(event, pandown)
        guidata[c, :yview] = pan(yview,  0.1*ysign, yviewlimits)
        ret = handled
    elseif keymatch(event, panleft_big)
        guidata[c, :xview] = pan(xview, -1*xsign, xviewlimits)
        ret = handled
    elseif keymatch(event, panright_big)
        guidata[c, :xview] = pan(xview,  1*xsign, xviewlimits)
        ret = handled
    elseif keymatch(event, panup_big)
        guidata[c, :yview] = pan(yview, -1*ysign, yviewlimits)
        ret = handled
    elseif keymatch(event, pandown_big)
        guidata[c, :yview] = pan(yview,  1*ysign, yviewlimits)
        ret = handled
    elseif keymatch(event, zoomin)
        xview = zoom(xview, 0.5, xviewlimits)
        yview = zoom(yview, 0.5, yviewlimits)
        setboth(c, xview, yview)
        ret = handled
    elseif keymatch(event, zoomout)
        xview = zoom(xview, 2.0, xviewlimits)
        yview = zoom(yview, 2.0, yviewlimits)
        setboth(c, xview, yview)
        ret = handled
    end
    ret
end

keymatch(event, keydesc) = event.keyval == keydesc[1] && event.state == UInt32(keydesc[2])

"""
`panzoom_mouse(c; kwargs...)` initializes panning-by-mouse-scroll and mouse
control over zooming for a canvas `c`.

zooming or panning (along either x or y) is selected by modifier keys,
which are configurable through keyword arguments.  The default
settings are:

```
    # Panning
    xpan      = SHIFT     # hold down the shift key
    ypan      = 0
    xpanflip  = false
    ypanflip  = false
    # Zooming
    zoom      = CONTROL     # hold down the ctrl-key while scrolling
    focus     = :pointer    # zoom around the position under the mouse pointer
    factor    = 2.0
    initiate  = BUTTON_PRESS # start a rubberband selection for zoom
    reset     = DOUBLE_BUTTON_PRESS    # go back to original limits
```
where 0 means no modifier. SHIFT, CONTROL, BUTTON_PRESS, and
DOUBLE_BUTTON_PRESS are defined in `Gtk.GConstants.GdkModifierType`.

The `focus` keyword controls how the zooming progresses as you scroll
the mouse wheel. `:pointer` means that whatever feature of the canvas
is under the pointer will stay there as you zoom in or out. The other
choice, `:center`, keeps the canvas centered on its current location.
These behaviors are subject to modification by the canvas'
`:viewlimits` data.

An additional keyword is `user_to_data`, for which you may supply
a function
```
    user_to_data_fcn(c, x, y) -> (datax, datay)
```
that converts canvas user-coordinates to "data coordinates" before
setting the values of :xview and :yview.

For important additional information, see `panzoom_key`. To disable mouse
panning and zooming, use
```
    pop!((c.mouse, :scroll))
    pop!((c.mouse, :button1press))
```

Example:
```
    c = Canvas()
    panzoom(c, (0,1), (0,1))
    panzoom_mouse(c)
```
"""
function panzoom_mouse(c;
                       # Panning
                       xpan = SHIFT,
                       ypan  = 0,
                       xpanflip = false,
                       ypanflip  = false,
                       # Zooming
                       zoom = CONTROL,
                       focus::Symbol = :pointer,
                       factor = 2.0,
                       initiate = BUTTON_PRESS,
                       reset = DOUBLE_BUTTON_PRESS,
                       user_to_data = (c,x,y)->(x,y))
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    # Scroll events
    scrollfun = (widget, event) -> begin
        s = 0.1*scrollpm(event.direction)
        xscroll = (event.direction == LEFT) || (event.direction == RIGHT)
        if xpan != nothing && (event.state == UInt32(xpan) || xscroll)
            xview = guidata[c, :xview]
            xviewlimits = guidata[c, :xviewlimits]
            guidata[c, :xview] = pan(xview, (xpanflip ? -1 : 1) * s, xviewlimits)
        elseif ypan != nothing && event.state == UInt32(ypan)
            yview = guidata[c, :yview]
            yviewlimits = guidata[c, :yviewlimits]
            guidata[c, :yview] = pan(yview, (ypanflip  ? -1 : 1) * s, yviewlimits)
        elseif zoom != nothing && event.state == UInt32(zoom)
            s = factor
            if event.direction == UP
                s = 1/s
            end
            zoom_focus(widget, s, event; focus=focus, user_to_data=user_to_data)
        end
    end
    # Click events
    clickfun = (widget, event) -> begin
        set_gtk_property!(widget, :is_focus, true)
        if event.event_type == initiate
            rubberband_start(widget, event.x, event.y, (widget, bb) -> zoom_bb(widget, bb, user_to_data))
        elseif event.event_type == reset
            zoom_reset(widget)
        end
    end
    push!((c.mouse, :scroll), scrollfun)
    push!((c.mouse, :button1press), clickfun)
    nothing
end

scrollpm(direction::Integer) =
    direction == UP ? -1 :
    direction == DOWN ? 1 :
    direction == RIGHT ? 1 :
    direction == LEFT ? -1 : error("Direction ", direction, " not recognized")


function zoom_focus(c, s, event; focus::Symbol=:pointer, user_to_data=(c,x,y)->(x,y))
    xview = guidata[c, :xview]
    yview = guidata[c, :yview]
    xviewlimits = guidata[c, :xviewlimits]
    yviewlimits = guidata[c, :yviewlimits]
    if focus == :pointer
        ux, uy = device_to_user(getgc(c), event.x, event.y)
        centerx, centery = user_to_data(c, ux, uy)
        w, h = width(xview), width(yview)
        fx, fy = (centerx-xview.min)/w, (centery-yview.min)/h
        wbb, hbb = s*w, s*h
        xview = interior(Interval(centerx-fx*wbb,centerx+(1-fx)*wbb), xviewlimits)
        yview = interior(Interval(centery-fy*hbb,centery+(1-fy)*hbb), yviewlimits)
        setboth(c, xview, yview)
    elseif focus == :center
        xview = zoom(xview, s, xviewlimits)
        yview = zoom(yview, s, yviewlimits)
        setboth(c, xview, yview)
    end
    c
end

function setboth(c, xview, yview)
    getindex(guidata, c, :xview; raw=true).value = xview
    getindex(guidata, c, :yview; raw=true).value = yview
    trigger(c, (:xview, :yview))
end

# We don't take the step of setting new coordinates on the Canvas
# because we need to let the user be in charge of that. (For example,
# in plots you want to zoom in on the data but leave the axes
# visible.) But see set_coordinates below. So we content ourselves with
function zoom_bb(widget, bb::BoundingBox, user_to_data=(c,x,y)->(x,y))
    xmin, ymin = user_to_data(widget, bb.xmin, bb.ymin)
    xmax, ymax = user_to_data(widget, bb.xmax, bb.ymax)
    setboth(widget, (xmin,xmax), (ymin,ymax))
    widget
end

function zoom_reset(widget)
    xvlim, yvlim = guidata[widget, :xviewlimits], guidata[widget, :yviewlimits]
    xvlim != nothing && (getindex(guidata, widget, :xview; raw=true).value = xvlim)
    yvlim != nothing && (getindex(guidata, widget, :yview; raw=true).value = yvlim)
    trigger(widget, (:xview, :yview))
    widget
end

# For completely mysterious reasons, these are borked
# function Graphics.set_coordinates(ctx::GraphicsContext, bb::BoundingBox)
#     set_coordinates(ctx, BoundingBox(0,width(ctx),0,height(ctx)), bb)
# end
# function Graphics.set_coordinates(widget, bb::BoundingBox)
#     set_coordinates(getgc(widget), bb)
# end
function Graphics.set_coordinates(ctx::GraphicsContext, ix::Interval, iy::Interval)
    set_coordinates(ctx, BoundingBox(0,width(ctx),0,height(ctx)), BoundingBox(ix.min, ix.max, iy.min, iy.max))
end

end # module
