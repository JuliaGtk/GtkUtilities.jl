using Colors, FixedPointNumbers, GtkUtilities, Gtk.ShortNames, Graphics

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
    xview, yview = guidata[widget, :xview], guidata[widget, :yview]
    set_coordinates(getgc(widget), xview, yview)
    # Render the image for this region
    iterate!(s, z_r, z_i, (yview.min,yview.max), (xview.min,xview.max))
    colorize!(col, s, z_r, z_i)
    # Blit it to the screen
    copy!(widget, col)
end

# Initialize panning & zooming
lim = (-2.0,2.0)
panzoom(c, lim, lim)
panzoom_mouse(c, factor=1.1)
panzoom_key(c)

# Activate the application
showall(win)
