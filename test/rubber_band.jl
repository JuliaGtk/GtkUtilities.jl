using Gtk.ShortNames
using GtkUtilities, GtkUtilities.Graphics

c = Canvas()
win = Window(c, "RubberBandCanvas")
draw(c) do widget
    ctx = getgc(widget)
    h = height(widget)
    w = width(widget)
    # Paint red rectangle
    rectangle(ctx, 0, 0, w, h/2)
    set_source_rgb(ctx, 1, 0, 0)
    fill(ctx)
    # Paint white rectangle
    rectangle(ctx, 0, h/2, w, 3h/4)
    set_source_rgb(ctx, 1, 1, 1)
    fill(ctx)
    # Paint blue rectangle
    rectangle(ctx, 0, 3h/4, w, h/4)
    set_source_rgb(ctx, 0, 0, 1)
    fill(ctx)
end

# Set up a rubberband-on-click. Note that `panzoom.jl` shows an
# alternative way to set this up, one that doesn't mess with
# any pre-existing `button1press` function that the user
# may have defined.
c.mouse.button1press = (widget, event) -> begin
    if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
        rubberband_start(widget, event.x, event.y, (widget, bb) -> @show bb)
    end
end

showall(c)
