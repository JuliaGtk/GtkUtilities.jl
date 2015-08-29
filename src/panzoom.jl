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
import ..guidata
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
Base.convert{T}(::Type{Interval{T}}, v::VecLike)  = Interval{T}(v...)

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
panzoom(c, viewxlimits, viewylimits)
panzoom(c, viewxlimits, viewylimits, viewx, viewy)
```
sets up the Canvas `c` for panning and zooming. The arguments may be
2-tuples, 2-vectors, or Intervals.

`panzoom` creates the `:view[x|y]`, `:view[x|y]limits` properties of
`c`:

- `:viewx`, `:viewy` are two `AbstractState`s (for horizontal and
    vertical, respectively), each holding an Interval specifying
    the current "view" limits. This might be the entire area, or it
    might be a subregion due to a previous zoom event.

- `:viewxlimits`, `:viewylimits` encode the maximum allowable viewing
    region; in most cases these will also be `State{Interval}`s, but
    any object that supports `interior` and `fullview` may be used.

""" ->
panzoom(c, viewxlimits::Interval, viewylimits::Interval) =
    panzoom(c, State(viewxlimits), State(viewylimits))

panzoom(c, viewxlimits::VecLike, viewylimits::VecLike) = panzoom(c, iv(viewxlimits), iv(viewylimits))

panzoom(c, viewxlimits::VecLike, viewylimits::VecLike, viewx::VecLike, viewy::VecLike) = panzoom(c, iv(viewxlimits), iv(viewylimits), iv(viewx), iv(viewy))

function panzoom(c, viewxlimits::AbstractState, viewylimits::AbstractState, viewx::AbstractState = similar(viewxlimits), viewy::AbstractState = similar(viewylimits))
    guidata[c, :viewx] = viewx
    guidata[c, :viewy] = viewy
    guidata[c, :viewxlimits] = viewxlimits
    guidata[c, :viewylimits] = viewylimits
    link(viewx, c)
    link(viewy, c)
    nothing
end

iv(x) = Interval{Float64}(x...)


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
        viewx_s = guidata[c, :viewx]
        viewy_s = guidata[c, :viewy]
        viewx, viewy = get(viewx_s), get(viewy_s)
        viewxlimits = get(guidata[c, :viewxlimits])
        viewylimits = get(guidata[c, :viewylimits])
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
        set!(viewx_s, viewx)
        set!(viewy_s, viewy)
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
        viewx_s = guidata[c, :viewx]
        viewy_s = guidata[c, :viewy]
        viewx, viewy = get(viewx_s), get(viewy_s)
        viewxlimits = get(guidata[c, :viewxlimits])
        viewylimits = get(guidata[c, :viewylimits])
        s = 0.1*scrollpm(event.direction)
        if     event.state == @compat(UInt32(panhoriz))
            viewx = pan(viewx, s, viewxlimits)
        elseif event.state == @compat(UInt32(panvert))
            viewy = pan(viewy, s, viewylimits)
        end
        set!(viewx_s, viewx)
        set!(viewy_s, viewy)
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
        viewx_s = guidata[c, :viewx]
        viewy_s = guidata[c, :viewy]
        viewx, viewy = get(viewx_s), get(viewy_s)
        viewxlimits = get(guidata[c, :viewxlimits])
        viewylimits = get(guidata[c, :viewylimits])

        s = 1.0
        if keymatch(event, in)
            s = 0.5
        elseif keymatch(event, out)
            s = 2.0
        end
        viewx = zoom(viewx, s, viewxlimits)
        viewy = zoom(viewy, s, viewylimits)
        set!(viewx_s, viewx)
        set!(viewy_s, viewy)
        nothing
    end
end

@doc """
`id = add_zoom_mouse(c; kwargs...)` initializes zooming-by-mouse-scroll
for a canvas `c`.

Zooming is selected by a modifier key, which is configurable through
keyword arguments.  The keywords and their defaults are:
```
    mod       = CONTROL,     # hold down the ctrl-key
    focus     = :pointer
```
CONTROL is defined in `Gtk.GConstants.GdkModifierType`.

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
""" ->
function add_zoom_mouse(c;
                        mod = CONTROL,
                        focus::Symbol = :pointer)
    add_events(c, SCROLL)
    focus == :pointer || focus == :center || error("focus must be :pointer or :center")
    signal_connect(c, :scroll_event) do widget, event
        viewx_s = guidata[c, :viewx]
        viewy_s = guidata[c, :viewy]
        viewx, viewy = get(viewx_s), get(viewy_s)
        viewxlimits = get(guidata[c, :viewxlimits])
        viewylimits = get(guidata[c, :viewylimits])
        if event.state == @compat(UInt32(mod))
            s = 0.5
            if event.direction == DOWN
                s = 1/s
            end
            if focus == :pointer
                w, h = width(c), height(c)
                fx, fy = event.x/w, event.y/h
                w, h = width(bb), height(bb)
                centerx, centery = viewx.min+fx*w, viewy.min+fy*h
                wbb, hbb = s*w, s*h
                viewx = interior(Interval(centerx-fx*wbb,centerx+(1-fx)*wbb), viewxlimits)
                viewy = interior(Interval(centery-fy*hbb,centery+(1-fy)*hbb), viewylimits)
            elseif focus == :center
                viewx = zoom(viewx, s, viewxlimits)
                viewy = zoom(viewy, s, viewylimits)
            end
        end
        set!(viewx_s, viewx)
        set!(viewy_s, viewy)
        nothing
    end
end

end
