# GtkUtilities

[![Build Status](https://travis-ci.org/timholy/GtkUtilities.jl.svg?branch=master)](https://travis-ci.org/timholy/GtkUtilities.jl)

This package is a collection of extensions to
[Gtk](https://github.com/JuliaLang/Gtk.jl) that make interactive
graphics easier.  For example, it allows you to:
- "attach" user data to widgets or any other object
- perform rubber-band selection
- use pan and zoom

Planned capabilities include:
- support for hit testing (selecting objects like points or lines)

Possible extensions (likely via separate packages):
- interactive color picker
- on-screen drawing

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

Zooming and panning a Canvas `c` are performed using two `guidata`
objects, `guidata[c, :viewbb]` and `guidata[c, :viewlimits]`.
`:viewbb` expresses the current view region, which includes effects of
any previous zoom and pan operations.  `:viewlimits` corresponds to an
object which can act to prevent panning or zooming from going beyond an
allowable area; most commonly this is just another bounding box, but
any object for which you implement `interior` can serve as a valid
`:viewlimits` object. (See `?interior` for more information.)

It is crucial that the `draw` method for your Canvas makes use of the
`:viewbb` property and renders only over the selected view region.
In the simplest cases, you might achieve this with
```jl
ctx = getgc(c)
h = height(c)
w = width(c)
bb = guidata[c, :viewbb]
set_coords(ctx, BoundingBox(0, w, 0, h), bb)
```
and then rendering the entire canvas in units of the original
"full-view" `bb` (e.g., `:viewlimits`).

You intialize panning and zooming with
```
id1 = add_pan_key(c)
id2 = add_pan_mouse(c)
id3 = add_zoom_key(c)
id4 = add_zoom_mouse(c)
```

This sequence will implement panning and zooming with either the
keyboard or wheel-mouse.  You can specify the keys and modifiers, as
well as the behavior of scroll-zooming relative to the mouse pointer
location, via keyword arguments to these functions. See each
individual function (e.g., `?add_pan_key`) for more information.

The returned `id` can be disabled or enabled via
`signal_handler_block` and `signal_handler_unblock`, respectively, or
removed with `signal_handler_disconnect`.

## Help

Each function has its own help, e.g., `?rubberband_start`.
