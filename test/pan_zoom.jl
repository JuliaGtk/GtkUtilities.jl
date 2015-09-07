using Gtk.ShortNames
using GtkUtilities, GtkUtilities.Graphics

c = @Canvas()
win = @Window(c, "PanZoomCanvas")
showall(win)
panzoom(c, (0,1), (0,1))

draw(c) do widget
    xview, yview = guidata[widget, :viewx], guidata[widget, :viewy]
    ctx = getgc(widget)
    set_coords(ctx, xview, yview)
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

idpan_key    = add_pan_key(c)
idpan_mouse  = add_pan_mouse(c)
idzoom_key   = add_zoom_key(c)
idzoom_mouse = add_zoom_mouse(c)

nothing
