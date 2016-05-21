module PanZoom

using Gtk, Compat
import Gtk.GConstants: GDK_KEY_Left, GDK_KEY_Right, GDK_KEY_Up, GDK_KEY_Down
import Gtk.GConstants.GdkModifierType: SHIFT, CONTROL, MOD1
import Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL
import Gtk.GdkEventType: BUTTON_PRESS, DOUBLE_BUTTON_PRESS
import Gtk.GConstants.GdkScrollDirection: UP, DOWN, LEFT, RIGHT
import Base: *
import Reactive
import Reactive: value, map, bind!, foreach

if VERSION < v"0.4.0-dev"
    using Docile, Base.Graphics
else
    using Graphics
end

using ..GtkUtilities.Link
import ..guidata, ..trigger, ..rubberband_start
#import ..Link: AbstractState

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
similar{T}(interval::Interval{T}) = Interval(zero(T), zero(T))

function Base.convert{T}(::Type{Interval{T}}, v::VecLike)
    v1, v2 = first(v), last(v)
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

type KeySignal #kind of matches the pattern of a Widget, but in this case it's more appropriately called a signal
	c  #the canvas that the KeySignal listens to
	key::Tuple{Integer,Integer} #key should match the form the keypress event returned by GDK. It's a tuple of identifier and state.  You can find identifiers by typing Gtk.GConstants.GDK_KEY_ and hitting tab
	signal::Reactive.Signal #true if pressed (actually true all the time, but we're only using the signal update right now.  At some point we can add a GTK key release signal to make this the true status of the key)
end
Reactive.push!(ks::KeySignal, val) = Reactive.push!(ks.signal, val)
signal(ks::KeySignal) = ks.signal
Reactive.value(ks::KeySignal) = Reactive.value(ks.signal)
canvas(ks::KeySignal) = ks.c
key(ks::KeySignal) = ks.key
Reactive.map(f, ks::KeySignal) = Reactive.map(f, signal(ks))
Reactive.foreach(f, ks::KeySignal) = Reactive.foreach(f, signal(ks))
#Base.start(ks::KeySignal) = ks #this seems necessary for calling Reactive.map with do syntax
#Base.done(ks::KeySignal, state) = true #this seems necessary for calling Reactive.map with do syntax

keysignal(c,key::Tuple{Integer,Integer}) = KeySignal(c, key, Reactive.Signal(false))

type ViewROI # Tuple{Interval, Interval} #hold off on this for now
	xview::Interval
	yview::Interval
end
similar(roi::ViewROI) = ViewROI(similar(roi.xview), similar(roi.yview))

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


#Eliminate panzoom in favor of panzoom_key or panzoommouse? Can call it internally when those functions are invoked.
@doc """
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
""" ->
panzoom(c, xviewlimits::Interval, yviewlimits::Interval) =
    panzoom(c, ViewROI(xviewlimits, yviewlimits))


panzoom(c, xviewlimits::VecLike, yviewlimits::VecLike) = panzoom(c, iv(xviewlimits), iv(yviewlimits))

panzoom(c, xviewlimits::Union{VecLike,Void}, yviewlimits::Union{VecLike,Void}, xview::VecLike, yview::VecLike) = panzoom(c, ViewROI(iv(xviewlimits), iv(yviewlimits)), ViewROI(iv(xview), iv(yview)))

function panzoom(c, max_roi::ViewROI, cur_roi = deepcopy(max_roi))
    if !haskey(guidata, c)
        guidata[c, :cur_roi] = Reactive.Signal(cur_roi)
    end
    d = guidata[c]
    d[:cur_roi] = Reactive.Signal(cur_roi)  #overwrites the signal just created if c wasn't stored in guidata before.  I guess that's okay
    d[:max_roi] = max_roi
    nothing
end

function panzoom(c2, c1) #assumes c1 already has panzoom set up, and that both c1 and c2 have been stored in guidata
    d1, d2 = guidata[c1], guidata[c2]
	d2[:max_roi] = d1[:max_roi] #should max_roi be a signal too?  Probably would be better for flexibility
	d2[:cur_roi] = Reactive.Signal(value(d1[:cur_roi])) #is this unsafe?  If d2 already had a :cur_roi signal, then I suppose any signals depending on it can now be corrupted?  have to look at Reactive internals to see.
	#given question above, may be better to make this a one-way binding (but even that may not totally solve the problem)
	d2[:cur_roi] = Reactive.bind!(d2[:cur_roi], d1[:cur_roi], true) #two-way binding
    nothing
end

function panzoom(c)
    gc = getgc(c)
    xmin, ymin = device_to_user(gc, 0, 0)
    xmax, ymax = device_to_user(gc, width(c), height(c))
    panzoom(c, (xmin, xmax), (ymin, ymax))
end

iv(x) = Interval{Float64}(x...)
iv(x::Interval) = convert(Interval{Float64}, x)
iv(x::State) = iv(get(x))
iv(x::Void) = x

pan(iv, frac::Real, limits) = interior(shift(iv, frac*width(iv)), limits)

zoom(iv, s::Real, limits) = interior(s*iv, limits)

#signals needed for ImagePlayer to work:
#mouse buttons and mouse position (might have to limit sample rate of position)
#key signals for each key necessary.
#a derived signal that is the ROI being displayed
#a derived signal that is the data buffer being displayed (this can be implemented in ImagePlayer)
@doc """
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
    c = @Canvas()
    panzoom(c, (0,1), (0,1))
    id = panzoom_key(c)
```
The `draw` method for `c` should take account of `:cur_roi`.
""" ->
function panzoom_key(c;panleft  = (GDK_KEY_Left,0),
                     panright = (GDK_KEY_Right,0),
                     #panup    = (GDK_KEY_Up, 0),
                     panup    = (GDK_KEY_UP, CONTROL),
                     #pandown  = (GDK_KEY_Down,0),
                     pandown  = (GDK_KEY_Down, CONTROL),
                     panleft_big  = (GDK_KEY_Left,SHIFT),
                     panright_big = (GDK_KEY_Right,SHIFT),
                     panup_big    = (GDK_KEY_Up,SHIFT),
                     pandown_big  = (GDK_KEY_Down,SHIFT),
                     xpanflip     = false,
                     ypanflip     = false,
                     #zoomin       = (GDK_KEY_Up,  CONTROL),
                     zoomin       = (GDK_KEY_Up, 0),
                     #zoomout      = (GDK_KEY_Down,CONTROL))
                     zoomout      = (GDK_KEY_Down, 0))
	xsign = xpanflip ? -1 : 1
	ysign = ypanflip ? -1 : 1
	#Set up key event signals.  They will be updated be the panzoom_key_cb callback functionn passed to GTK below
    add_events(c, KEY_PRESS)
    setproperty!(c, :can_focus, true)
    setproperty!(c, :has_focus, true)
	panleftsig = keysignal(c, panleft)
	panrightsig = keysignal(c, panright)
	panupsig = keysignal(c, panup)
	pandownsig = keysignal(c, pandown)
	panleft_bigsig = keysignal(c, panright)
	panright_bigsig = keysignal(c, panright)
	panup_bigsig = keysignal(c, panright)
	pandown_bigsig = keysignal(c, panright)
	zoominsig = keysignal(c, zoomin)
	zoomoutsig = keysignal(c, zoomout)
	#Tell GTK to update signals when keys are pressed
	#alternatively we could pass signal_connect just one "allkeys" signal.  Then have the other signals filter that signal.  But I'm not sure how this will
	#work if multiple keys are pressed at the same time.  This may be first and foremost a GTK question (is it multithreaded?) and secondly a Reactive question.
    id = signal_connect(panzoom_key_cb, c, :key_press_event, Cint, (Ptr{Gtk.GdkEventKey},),
                   false, (panleftsig, panrightsig, panupsig, pandownsig, panleft_bigsig,
                           panright_bigsig, panup_bigsig, pandown_bigsig,
                           zoominsig, zoomoutsig)) #the callback is fed a pointer to the widget (in this case a canvas) a pointer to the event, and the last argument of signal_connect (user data) 
	#Grab the ViewROI signal from guidata (later we may change or remove guidata altogether)
	roisig = guidata[c, :cur_roi] #a ViewROI signal
	max_roi = guidata[c, :max_roi] #just a ViewROI, but may make this a signal too
	xviewlimits = max_roi.xview
	yviewlimits = max_roi.yview

	#Map handled keypress signals to ViewROI updates
	Reactive.foreach(panleftsig) do s #currently not using the value of the keypress signal.  This could be changed at some point to allow continuous panning by holding down the key.
		print("panning left\n")
		cur_roi = Reactive.value(roisig)
		cur_roi.xview = pan(cur_roi.xview, -0.1*xsign, xviewlimits) #TODO?  modify pan function to pan!(roi, "x", frac, limits)
		Reactive.push!(roisig, cur_roi)  #if we do modify pan to pan! as mentioned above, is there a way to trigger a signal update without the Reactive.push! statement? (I assume push! involves an unnecessary copy)
	end
	Reactive.foreach(panrightsig) do s
		print("panning right\n")
		cur_roi = value(roisig)
		cur_roi.xview = pan(cur_roi.xview, 0.1*xsign, xviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(panupsig) do s
		print("panning up\n")
		cur_roi = value(roisig)
		cur_roi.yview = pan(cur_roi.yview, -0.1*ysign, yviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(pandownsig) do s
		print("panning down\n")
		cur_roi = value(roisig)
		cur_roi.yview = pan(cur_roi.yview,  0.1*ysign, yviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(panleft_big) do s
		cur_roi = value(roisig)
		cur_roi.xview = pan(cur_roi.xview,  -1*xsign, xviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(panright_big) do s
		cur_roi = value(roisig)
		cur_roi.xview = pan(cur_roi.xview,  1*xsign, xviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(panup_big) do s
		cur_roi = value(roisig)
		cur_roi.yview = pan(cur_roi.yview,  -1*ysign, yviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(pandown_big) do s
		cur_roi = value(roisig)
		cur_roi.yview = pan(cur_roi.yview,  1*ysign, yviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(zoominsig) do s
		print("zooming in\n")
		cur_roi = value(roisig)
		cur_roi.xview = zoom(cur_roi.xview, 0.5, xviewlimits)
		cur_roi.yview = zoom(cur_roi.yview, 0.5, yviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	Reactive.foreach(zoomoutsig) do s
		print("zooming out\n")
		cur_roi = value(roisig)
		cur_roi.xview = zoom(cur_roi.xview, 2.0, xviewlimits)
		cur_roi.yview = zoom(cur_roi.yview, 2.0, yviewlimits)
		Reactive.push!(roisig, cur_roi)
	end
	return id
end

keymatch(event, keydesc) = event.keyval == keydesc[1] && event.state == @compat(UInt32(keydesc[2]))

@guarded Cint(false) function panzoom_key_cb(widgetp, eventp, user_data) #user_data is filled with KeySignals
    c = convert(GtkCanvas, widgetp)
    event = unsafe_load(eventp)
    handled = Cint(true)
    ret = Cint(false)
	for s in user_data
		if keymatch(event, key(s))
			print("match found\n")
			push!(s, true)
			ret = handled
			#break  #may want to break if multiple keypresses can't be handled gracefully
		end
	end
	ret
end

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
