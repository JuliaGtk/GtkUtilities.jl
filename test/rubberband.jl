using Gtk.ShortNames
import GtkUtilities
using GtkUtilities.Graphics

c = @Canvas()
win = @Window(c, "RubberBandCanvas")
draw(c) do widget
    ctx = getgc(c)
    h = height(c)
    w = width(c)
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

# Set up a rubberband-on-click
c.mouse.button1press = (widget, event) -> begin
    if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
        GtkUtilities.rubberband_start(c, event.x, event.y, (c, bb) -> @show bb)
    end
end

show(c)
