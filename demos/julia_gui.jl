using Colors, GtkUtilities, Gtk.ShortNames, Graphics, Reactive

include("julia_set.jl")

# Create the window and canvas
win = @Window("julia", 400, 400)
c = @Canvas()
push!(win, c)

# Set up computation buffers
s, z_r, z_i, col = alloc(Float32, width(win))

# This is called for every drawing event (resizing the window,
# changing the zoom/pan)
@guarded Gtk.ShortNames.draw(c) do widget
    # Retrieve the display region
    cur_roi = value(guidata[widget, :cur_roi])
	xview = cur_roi.xview
	yview = cur_roi.yview
    set_coords(getgc(widget), xview, yview)
    # Render the image for this region
    iterate!(s, z_r, z_i, (xview.min,xview.max), (yview.min,yview.max))
    colorize!(col, s, z_r, z_i)
    # Blit it to the screen
    copy!(widget, col)
end

# Initialize panning & zooming
lim = (-2.0,2.0)
panzoom(c, lim, lim)
#panzoom_mouse(c, factor=1.1)
panzoom_key(c)

# Activate the application
showall(win)
