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

idpan_key    = add_pan_key(c)
idpan_mouse  = add_pan_mouse(c)
idzoom_key   = add_zoom_key(c)
idzoom_mouse = add_zoom_mouse(c)

nothing
