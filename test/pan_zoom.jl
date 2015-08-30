using Gtk.ShortNames
using GtkUtilities, GtkUtilities.Graphics

c = @Canvas()
win = @Window(c, "PanZoomCanvas")
panzoom(c, (0,1), (0,1))
draw(c) do widget
    ctx = getgc(widget)
    h = height(widget)
    w = width(widget)
    xview, yview = guidata[widget, :viewx], guidata[widget, :viewy]
    set_coords(ctx, BoundingBox(0, w, 0, h), BoundingBox(xview.min, xview.max, yview.min, yview.max))
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
        rubberband_start(widget, event.x, event.y, (widget, bb) -> (guidata[widget, :viewx] = (bb.xmin,bb.xmax); guidata[widget, :viewy] = (bb.ymin,bb.ymax)))
    elseif event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        guidata[widget, :viewx] = guidata[c, :viewxlimits]
        guidata[widget, :viewy] = guidata[c, :viewylimits]
    end
end

nothing
