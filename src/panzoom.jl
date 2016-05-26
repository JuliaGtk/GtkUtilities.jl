module PanZoom

using Gtk, Compat, Graphics, Reactive
import Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
import Gtk.GConstants.GdkModifierType: SHIFT, CONTROL, MOD1
import Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL
import Gtk.GdkEventType: BUTTON_PRESS, DOUBLE_BUTTON_PRESS
import Gtk.GConstants.GdkScrollDirection: UP, DOWN, LEFT, RIGHT
import Base: *
import Reactive
import Reactive: value, map, bind!, foreach
using ..GtkUtilities.Link
import ..guidata, ..trigger, ..rubberband_start
#import ..Link: AbstractState

typealias VecLike Union{AbstractVector,Tuple}

export
    # Types
    Interval,
    ViewROI,
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
    iv = Interval(min, max)
    iv = Interval(v)

An `Interval` is a `(min,max)` pair. It is the one-dimensional analog
of a `BoundingBox`. You can create an interval using two numbers,
tuples, ranges, or any other `AbstractVector`; in the latter cases,
just the first and last entries, respectively, are used.
"""
immutable Interval{T}
    min::T
    max::T
end

Base.convert{T}(::Type{Interval{T}}, v::Interval{T}) = v
Base.convert{T}(::Type{Interval{T}}, v::Interval) = Interval{T}(v.min, v.max)
Base.zero{I<:Interval}(::Type{I}) = I(0,0)

function Base.convert{T}(::Type{Interval{T}}, v::VecLike)
    v1, v2 = first(v), last(v)
    Interval{T}(v1, v2)
end
Base.convert{T}(::Type{Interval}, v::Tuple{T,T}) = convert(Interval{T}, v)

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

"""
    roi = ViewROI(xview, yview)

creates an object that stores intervals along x and y that represent a
rectangular region. The arguments may be `Interval`s or anything which
may be converted to an `Interval`.

The `roi` has two fields, called `xview` and `yview`, which are both
`Interval`s.
"""
immutable ViewROI # Tuple{Interval, Interval} #hold off on this for now
    xview::Interval
    yview::Interval
end

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

"""
`iv = fullview(limits)` returns an `Interval` `iv` that
encompases the full view as permitted by `limits`.

If `limits == nothing`, then `fullview` returns `nothing`.

The simplest effectual `limits` object is another `Interval`
representing the "whole canvas" along the chosen axis. If you need
more sophisticated behavior, you can extend this function to work with
custom types of `limits` objects.
"""
fullview(::Void) = nothing

fullview(limits::Interval) = limits


"""
    sigviewlimits, sigview = panzoom(viewlimits)
    sigviewlimits, sigview = panzoom(viewlimits, view)

Creates two Reactive signals that encode the zoom region.
`viewlimits` encodes the maximum allowable viewing region (in
user-coordinates); `view` encodes the current view. Both of these must
be `ViewROI` objects.

To enact zooming, pass `sigview, sigviewlimits` to `panzoom_key`
and/or `panzoom_mouse`.
"""
panzoom(viewlimits::ViewROI, view::ViewROI) = Signal(viewlimits), Signal(view)
panzoom(viewlimits::ViewROI) = panzoom(viewlimits, viewlimits)

"""
    sigviewlimits, sigview = panzoom(c)

Creates two Reactive signals that encode the current and maximal view
regions. The maximal view region is inferred from the user-coordinates
of the canvas.  Note that this invocation works only if the Canvas has
been drawn at least once; if that is not the case, you need to specify
the limits manually.
"""
function panzoom(c)
    gc = getgc(c)
    xmin, ymin = device_to_user(gc, 0, 0)
    xmax, ymax = device_to_user(gc, width(c), height(c))
    panzoom(ViewROI((xmin, xmax), (ymin, ymax)))
end

pan(iv, frac::Real, limits) = interior(shift(iv, frac*width(iv)), limits)

zoom(iv, s::Real, limits) = interior(s*iv, limits)

#signals needed for ImagePlayer to work:
#mouse buttons and mouse position (might have to limit sample rate of position)
#key signals for each key necessary.
#a derived signal that is the ROI being displayed
#a derived signal that is the data buffer being displayed (this can be implemented in ImagePlayer)
"""
    sigpz = panzoom_key(sigkey, sigviewlimits, sigviewview; kwargs...)`

initializes panning and zooming by keypress. `sigkey` can be created
for a canvas using `keysignal`. The last two arguments come from
`panzoom`.  You do not typically need to manipulate the outpu, but you
do need to hold on to it to prevent it from being garbage-collected.

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
"""
function panzoom_key(sigkey,
                     sigviewlimits,
                     sigview;
                     panleft  = (GDK_KEY_Left,0),
                     panright = (GDK_KEY_Right,0),
                     panup    = (GDK_KEY_Up, 0),
                     pandown  = (GDK_KEY_Down,0),
                     panleft_big  = (GDK_KEY_Left,SHIFT),
                     panright_big = (GDK_KEY_Right,SHIFT),
                     panup_big    = (GDK_KEY_Up,SHIFT),
                     pandown_big  = (GDK_KEY_Down,SHIFT),
                     xpanflip     = false,
                     ypanflip     = false,
                     zoomin       = (GDK_KEY_Up,  CONTROL),
                     zoomout      = (GDK_KEY_Down,CONTROL))
    xsign = xpanflip ? -1 : 1
    ysign = ypanflip ? -1 : 1
    #Set up key event signals.  They will be updated be the panzoom_key_cb callback functionn passed to GTK below
    sigpz = map(sigkey) do event
        roi = value(sigview)
        limits = value(sigviewlimits)
        matched = true
        if keymatch(event, panleft)
            push!(sigview, ViewROI(pan(roi.xview, -0.1*xsign, limits.xview), roi.yview))
        elseif keymatch(event, panright)
            push!(sigview, ViewROI(pan(roi.xview, +0.1*xsign, limits.xview), roi.yview))
        elseif keymatch(event, panup)
            push!(sigview, ViewROI(roi.xview, pan(roi.yview, -0.1*ysign, limits.yview)))
        elseif keymatch(event, pandown)
            push!(sigview, ViewROI(roi.xview, pan(roi.yview, +0.1*ysign, limits.yview)))
        elseif keymatch(event, panleft_big)
            push!(sigview, ViewROI(pan(roi.xview, -xsign, limits.xview), roi.yview))
        elseif keymatch(event, panright_big)
            push!(sigview, ViewROI(pan(roi.xview, xsign, limits.xview), roi.yview))
        elseif keymatch(event, panup_big)
            push!(sigview, ViewROI(roi.xview, pan(roi.yview, -ysign, limits.yview)))
        elseif keymatch(event, pandown_big)
            push!(sigview, ViewROI(roi.xview, pan(roi.yview, ysign, limits.yview)))
        elseif keymatch(event, zoomin)
            push!(sigview, ViewROI(zoom(roi.xview, 0.5, limits.xview),
                                   zoom(roi.yview, 0.5, limits.yview)))
        elseif keymatch(event, zoomout)
            push!(sigview, ViewROI(zoom(roi.xview, 2.0, limits.xview),
                                   zoom(roi.yview, 2.0, limits.yview)))
	end
    end
    return sigpz
end

keymatch(event, keydesc) = event.keyval == @compat(UInt32(keydesc[1])) && event.state == @compat(UInt32(keydesc[2]))

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
    c = @Canvas()
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
        if xpan != nothing && (event.state == (@compat(UInt32(xpan))) || xscroll)
            xview = guidata[c, :xview]
            xviewlimits = guidata[c, :xviewlimits]
            guidata[c, :xview] = pan(xview, (xpanflip ? -1 : 1) * s, xviewlimits)
        elseif ypan != nothing && event.state == @compat(UInt32(ypan))
            yview = guidata[c, :yview]
            yviewlimits = guidata[c, :yviewlimits]
            guidata[c, :yview] = pan(yview, (ypanflip  ? -1 : 1) * s, yviewlimits)
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
        setproperty!(widget, :is_focus, true)
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
# visible.) But see set_coords below. So we content ourselves with
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
