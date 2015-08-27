using Gtk.ShortNames
using GtkUtilities, GtkUtilities.Graphics

c = @Canvas()
win = @Window(c, "PanZoomCanvas")
bb = BoundingBox(0,1,0,1)
guidata[c, :viewlimits] = bb
guidata[c, :viewbb] = bb
draw(c) do widget
    ctx = getgc(c)
    h = height(c)
    w = width(c)
    bb = guidata[c, :viewbb]
    set_coords(ctx, BoundingBox(0, w, 0, h), bb)
    # Paint red rectangle
    rectangle(ctx, 0, 0, 0.5, 0.5)
    set_source_rgb(ctx, 1, 0, 0)
    fill(ctx)
    # Paint blue rectangle
    rectangle(ctx, 0.5, 0, 0.5, 0.5)
    set_source_rgb(ctx, 0, 0, 1)
    fill(ctx)
    # Paint white rectangle
    rectangle(ctx, 0, 0.5, 1, 0.75)
    set_source_rgb(ctx, 1, 1, 1)
    fill(ctx)
    # Paint green rectangle
    rectangle(ctx, 0, 0.75, 1, 0.25)
    set_source_rgb(ctx, 0, 1, 0)
    fill(ctx)
end

showall(c)

add_pan_key(c)
add_pan_mouse(c)
add_zoom_key(c)
add_zoom_mouse(c)

# Select zoom region with rubberband, and zoom all the way out
# with a double-click
c.mouse.button1press = (widget, event) -> begin
    if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
        rubberband_start(c, event.x, event.y, (c, bb) -> (guidata[c, :viewbb]=bb; draw(c)))
    elseif event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        guidata[c, :viewbb] = fullview(guidata[c, :viewlimits])
        draw(c)
    end
end

nothing
