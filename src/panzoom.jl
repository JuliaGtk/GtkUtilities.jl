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
    panzoom_key,
    panzoom_mouse,
    zoom_reset

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
`id = panzoom_key(c; kwargs...)` initializes panning-by-keypress for a
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
    c = @Canvas()
    panzoom(c, (0,1), (0,1))
    id = panzoom_key(c)
```
The `draw` method for `c` should take account of `:viewbb`.
""" ->
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
    setproperty!(c, :can_focus, true)
    setproperty!(c, :has_focus, true)
    signal_connect(c, :key_press_event) do widget, event
        viewx = guidata[c, :viewx]
        viewy = guidata[c, :viewy]
        viewxlimits = guidata[c, :viewxlimits]
        viewylimits = guidata[c, :viewylimits]
        xsign = xpanflip ? -1 : 1
        ysign = ypanflip ? -1 : 1
        if keymatch(event, panleft)
            viewx = pan(viewx, -0.1*xsign, viewxlimits)
        elseif keymatch(event, panright)
            viewx = pan(viewx,  0.1*xsign, viewxlimits)
        elseif keymatch(event, panup)
            viewy = pan(viewy, -0.1*ysign, viewylimits)
        elseif keymatch(event, pandown)
            viewy = pan(viewy,  0.1*ysign, viewylimits)
        elseif keymatch(event, panleft_big)
            viewx = pan(viewx, -1*xsign, viewxlimits)
        elseif keymatch(event, panright_big)
            viewx = pan(viewx,  1*xsign, viewxlimits)
        elseif keymatch(event, panup_big)
            viewy = pan(viewy, -1*ysign, viewylimits)
        elseif keymatch(event, pandown_big)
            viewy = pan(viewy,  1*ysign, viewylimits)
        elseif keymatch(event, zoomin)
            viewx = zoom(viewx, 0.5, viewxlimits)
            viewy = zoom(viewy, 0.5, viewylimits)
        elseif keymatch(event, zoomout)
            viewx = zoom(viewx, 2.0, viewxlimits)
            viewy = zoom(viewy, 2.0, viewylimits)
        end
        guidata[c, :viewx] = viewx
        guidata[c, :viewy] = viewy
        nothing
    end
end

keymatch(event, keydesc) = event.keyval == keydesc[1] && event.state == @compat(UInt32(keydesc[2]))

@doc """
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
setting the values of :viewx and :viewy.

For important additional information, see `panzoom_key`. To disable mouse
panning and zooming, use
```
    pop!((c.mouse, :scroll))
    pop!((c.mouse, :button1press))
```

Example:
```
    c = @Canvas()
    panzoom(c, (0,1), (0,1))
    panzoom_mouse(c)
```
""" ->
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
        if  xpan != nothing && event.state == @compat(UInt32(xpan))
            viewx = guidata[c, :viewx]
            viewxlimits = guidata[c, :viewxlimits]
            guidata[c, :viewx] = pan(viewx, (xpanflip ? -1 : 1) * s, viewxlimits)
        elseif ypan != nothing && event.state == @compat(UInt32(ypan))
            viewy = guidata[c, :viewy]
            viewylimits = guidata[c, :viewylimits]
            guidata[c, :viewy] = pan(viewy, (ypanflip  ? -1 : 1) * s, viewylimits)
        elseif zoom != nothing && event.state == @compat(UInt32(zoom))
            s = factor
            if event.direction == UP
                s = 1/s
            end
            zoom_focus(widget, s, event; focus=focus, user_to_data=user_to_data)
        end
    end
    # Click events
    clickfun = (widget, event) -> begin
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
    direction == DOWN ? 1 : error("Direction ", direction, " not recognized")


function zoom_focus(c, s, event; focus::Symbol=:pointer, user_to_data=(c,x,y)->(x,y))
    viewx = guidata[c, :viewx]
    viewy = guidata[c, :viewy]
    viewxlimits = guidata[c, :viewxlimits]
    viewylimits = guidata[c, :viewylimits]
    if focus == :pointer
        ux, uy = device_to_user(getgc(c), event.x, event.y)
        centerx, centery = user_to_data(c, ux, uy)
        w, h = width(viewx), width(viewy)
        fx, fy = (centerx-viewx.min)/w, (centery-viewy.min)/h
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

# We don't take the step of setting new coordinates on the Canvas
# because we need to let the user be in charge of that. (For example,
# in plots you want to zoom in on the data but leave the axes
# visible.) But see set_coords below. So we content ourselves with
function zoom_bb(widget, bb::BoundingBox, user_to_data=(c,x,y)->(x,y))
    xmin, ymin = user_to_data(widget, bb.xmin, bb.ymin)
    xmax, ymax = user_to_data(widget, bb.xmax, bb.ymax)
    getindex(guidata, widget, :viewx; raw=true).value = (xmin, xmax)
    getindex(guidata, widget, :viewy; raw=true).value = (ymin, ymax)
    trigger(widget, (:viewx, :viewy))
    widget
end

function zoom_reset(widget)
    vxlim, vylim = guidata[widget, :viewxlimits], guidata[widget, :viewylimits]
    vxlim != nothing && (getindex(guidata, widget, :viewx; raw=true).value = vxlim)
    vylim != nothing && (getindex(guidata, widget, :viewy; raw=true).value = vylim)
    trigger(widget, (:viewx, :viewy))
    widget
end

# For completely mysterious reasons, these are borked
# function Graphics.set_coords(ctx::GraphicsContext, bb::BoundingBox)
#     set_coords(ctx, BoundingBox(0,width(ctx),0,height(ctx)), bb)
# end
# function Graphics.set_coords(widget, bb::BoundingBox)
#     set_coords(getgc(widget), bb)
# end
function Graphics.set_coords(ctx::GraphicsContext, ix::Interval, iy::Interval)
    set_coords(ctx, BoundingBox(0,width(ctx),0,height(ctx)), BoundingBox(ix.min, ix.max, iy.min, iy.max))
end

end # module
