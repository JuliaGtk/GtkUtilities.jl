# GtkUtilities

[![Build Status](https://travis-ci.org/timholy/GtkUtilities.jl.svg?branch=master)](https://travis-ci.org/timholy/GtkUtilities.jl)

This package is a collection of extensions to
[Gtk](https://github.com/JuliaLang/Gtk.jl) that make interactive
graphics easier.  For example, it allows you to:
- easily add rubber-band selection to a Canvas
- "attach" user data to widgets or any other object

Planned capabilities include:
- support for pan and zoom
- support for hit testing (selecting objects like points or lines)

Possible extensions (likely via separate packages):
- interactive color picker
- on-screen drawing

## Exported functions

### `rubberband_start`: implements rubber band selection

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
would set up a Canvas so that rubberband selection starts when the
user clicks the mouse; when the button is released, it displays the
bounding box of the selection region.

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

Example:
```jl
    c = @Canvas()
    bb = BoundingBox(0, 1, 0, 1)
    guidata[c, :zoombb] = bb
```

## Help

Each function has its own help, e.g., `?rubberband_start`.
