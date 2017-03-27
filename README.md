# GtkUtilities

[![Build Status](https://travis-ci.org/timholy/GtkUtilities.jl.svg?branch=master)](https://travis-ci.org/timholy/GtkUtilities.jl)

# Alternatives

New users are encouraged to consider [GtkReactive](https://github.com/JuliaGizmos/GtkReactive.jl) instead.

# What is GtkUtilities?

This package is a collection of extensions to
[Gtk](https://github.com/JuliaLang/Gtk.jl) that make interactive
graphics easier.  For example, it allows you to:
- "attach" user data to widgets or any other object
- perform rubber-band selection
- use pan and zoom
- synchronize state across multiple UI widgets and canvases

## Installation

Install via
```jl
Pkg.add("GtkUtilities")
```

## Usage

### `guidata`: associating user data with widgets

Given a widget (Button, Canvas, Window, etc.) or other graphical object
`w`, a value `val` can be associated with ("stored in") `w` using
```jl
guidata[w, :name] = val
```
where `:name` is the name (a Symbol) you've assigned to `val` for the
purposes of storage.

The value can be retrieved with
```jl
val = guidata[w, :name]
```
Here are some other things you can do with `guidata`:
```jl
alldata = guidata[w]           # fetch all data associated with w
val = get(guidata, (w,:name), default)   # returns default if :name not defined
delete!(guidata, (w,:name))    # deletes the value associated with :name
delete!(guidata, w)            # deletes all data associated with w
```

If `w` is a `GtkWidget`, the associated data are automatically deleted
when the object is destroyed.

Example:
```jl
    c = @Canvas()
    bb = BoundingBox(0, 1, 0, 1)
    guidata[c, :zoombb] = bb
```

### Rubber band selection

`rubberband_start(c, x, y, callback_done; minpixels=2)` starts a rubber-band
selection on Canvas `c` at position `(x,y)`.  When the user releases
the mouse button, the callback function `callback_done(c, bb)` is run,
where `bb` is the BoundingBox of the selected region.  To reduce the
likelihood that clicks used to raise windows will result in
rubber banding, the callback is not executed unless the user drags
the mouse by at least `minpixels` pixels (default value 2).

Example:
```jl
    c.mouse.button1press = (widget, event) -> begin
        if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
            GtkUtilities.rubberband_start(c, event.x, event.y, (c, bb) -> @show bb)
        end
    end
```
sets up a Canvas so that rubberband selection starts when the
user clicks the mouse; when the button is released, it prints the
bounding box of the selection region.

### Zooming and panning

Zooming and panning a Canvas `c` are performed using four `guidata`
objects, named `:xview`, `:yview`, `:xviewlimits`, `:yviewlimits`.
The first two express the current view region, which includes
effects of any previous zoom and pan operations.  The second two
encode the allowable area, representing the largest-sized region
that may be viewed.

You intialize panning and zooming with
```
panzoom(c, [xviewlimits, yviewlimits], [xview, yview])
panzoom_mouse(c)
id = panzoom_key(c)
```
This sequence will implement panning and zooming with either the
keyboard or wheel-mouse.  You can specify the keys and modifiers, as
well as the behavior of scroll-zooming relative to the mouse pointer
location, via keyword arguments to these functions. See each
individual function (e.g., `?panzoom_key`) for more information.

The `draw` method for your Canvas must make use of the
`:xview`, `:yview` properties.
In the simplest cases, you might achieve this with
```jl
draw(c) do widget
ctx = getgc(c)
h = height(c)
w = width(c)

xviewlimits, yviewlimits = guidata[c, :xviewlimits], guidata[c, :yviewlimits]
bb = BoundingBox( xviewlimits.min, xviewlimits.max, yviewlimits.min, yviewlimits.max)  # you can create bb outside of the draw method instead, by using explicity values for xview/yview-limits. However, 'guidata' will not work unless 'c' has already been fully defined.
set_coordinates(ctx, BoundingBox(0, w, 0, h), bb)

xview, yview = guidata[c, :xview], guidata[c, :yview]
...
# use xview and yview to manipulate the content of your canvas
...
end
```

The returned `id` can be disabled or enabled via
`signal_handler_block` and `signal_handler_unblock`, respectively, or
removed with `signal_handler_disconnect`.

### Managing state

**Note**: this component will be rebased on Reactive.jl after
https://github.com/JuliaLang/Reactive.jl/pull/65 merges, hopefully
via https://github.com/jverzani/GtkInteract.jl. This
interface is deprecated.

Suppose you have a slider (a `Scale`) and an `Entry` box as two
alternative mechanisms for specifying a single number, and you want to
use that number in some calculations when you render a `Canvas`.
Who "owns" the number? Does the `Entry` callback have to be aware of
the `Scale` callback, and vice-versa?

You can centralize your handling of this piece of information by using
a `State` object and `link`ing it to the UI elements:

```jl
state = State(5)

e = @Entry()
s = @Scale(false, 1:10)
c = @Canvas()
draw(c) do widget
   ...   # make use of state in here somewhere
end

elink = link(state, e)
slink = link(state, s)
link(state, c)

get(elink)               # returns 5
set!(state, 7)           # wow, the Canvas redraws and the Entry & Scale change!
get(state)               # returns 7
get(slink)               # returns 7
set!(slink, 4)           # everything updates again
```

Note that in this example we didn't have to write any callbacks at
all: just `link`ing the widget to the `State` object creates the
callback we need, and any changes are automatically propagated for
you.


## Help

Each function has its own help, e.g., `?rubberband_start`.
