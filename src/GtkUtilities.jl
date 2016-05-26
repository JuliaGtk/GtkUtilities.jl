__precompile__()

module GtkUtilities

using Cairo, Gtk.ShortNames, Colors, Reactive, Graphics
import Gtk.GConstants.GdkEventMask: KEY_PRESS, SCROLL

export
    # general
    keysignal,
    mouseposition,
    # GUIData
    guidata,
    trigger,
    # Rubberband
    rubberband_start,
    # PanZoom
    Interval,
    ViewROI,
    interior,
    fullview,
    panzoom,
    panzoom_key,
    panzoom_mouse,
    set_coords

include("link.jl")
using .Link
include("guidata.jl")
using .GuiData
include("rubberband.jl")
using .RubberBands
include("panzoom.jl")
using .PanZoom
import .PanZoom: interior, fullview   # for extensions

"""
    signal = keysignal(widget, [setfocus=true])

Create a signal for monitoring keypresses on a canvas or other
`widget`. The signal fires every time a key is pressed. At least for
some widgets (e.g., canvases), `setfocus` must be true or the widget
will not process key press events.

The signal value is a GdkEventKey; the `keyval` and `state` fields can
be used to monitor the pressed key and any held modifiers,
respectively.
"""
function keysignal(widget::Gtk.GtkWidget, setfocus::Bool=true)
    add_events(widget, KEY_PRESS)
    if setfocus
        setproperty!(widget, :can_focus, true)
        setproperty!(widget, :has_focus, true)
    end
    evt = Gtk.GdkEventKey()
    sig = Signal(evt)
    id = signal_connect(widget, :key_press_event) do widget, event
        push!(sig, event)
    end
    return sig
end

"""
    signal = mouseposition(canvas)

Creates a Reactive signal that updates whenever the mouse pointer
position changes within the canvas.
"""

function Base.copy!{C<:Colorant}(ctx::CairoContext, img::AbstractArray{C})
    save(ctx)
    Cairo.reset_transform(ctx)
    image(ctx, image_surface(img), 0, 0, width(ctx), height(ctx))
    restore(ctx)
end
Base.copy!(c::Canvas, img) = copy!(getgc(c), img)
function Base.fill!(c::Canvas, color::Colorant)
    ctx = getgc(c)
    w, h = width(c), height(c)
    rectangle(ctx, 0, 0, w, h)
    set_source(ctx, color)
    fill(ctx)
end

image_surface{C<:Color}(img::AbstractArray{C}) = CairoImageSurface(reinterpret(UInt32, convert(Matrix{RGB24}, img)), Cairo.FORMAT_RGB24, flipxy=false)
image_surface{C<:Colorant}(img::AbstractArray{C}) = CairoImageSurface(reinterpret(UInt32, convert(Matrix{ARGB32}, img)), Cairo.FORMAT_ARGB32, flipxy=false)

"""
Summary of features in GtkUtilities:

- `rubberband_start`: initiate rubber band selection
- `guidata`: associate user data with on-screen elements

Each of these has detailed help available, e.g., `?guidata`.
""" GtkUtilities

end # module
