using Gtk.ShortNames
using GtkUtilities, GtkUtilities.Graphics

c = @Canvas()
win = @Window(c, "PanZoomCanvas")
panzoom(c, (0,1), (0,1))
draw(c) do widget
    ctx = getgc(c)
    h = height(c)
    w = width(c)
    xview, yview = get(guidata[c, :viewx]), get(guidata[c, :viewy])
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
        rubberband_start(c, event.x, event.y, (c, bb) -> (set!(guidata[c, :viewx], (bb.xmin,bb.xmax)); set!(guidata[c, :viewy], (bb.ymin,bb.ymax))))
    elseif event.event_type == Gtk.GdkEventType.DOUBLE_BUTTON_PRESS
        set!(guidata[c, :viewx], get(guidata[c, :viewxlimits]))
        set!(guidata[c, :viewy], get(guidata[c, :viewylimits]))
    end
end

nothing
