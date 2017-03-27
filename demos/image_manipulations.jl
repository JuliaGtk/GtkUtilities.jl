# example code for image manipulation using GtkUtilties

using  Gtk.ShortNames, Images, GtkUtilities, Graphics, TestImages

A = testimage("lighthouse")

win = Window("image")                                                 # Create Window
c = Canvas()                                                          # Create Canvas
push!(win, c)                                                         # Place Canvas in Window


yx_ranges = map(x->(first(x),last(x)), indices(A))                    # returns: yx_ranges = ((min-Y, max-Y), (min-X, max-X)). Note that y is first, since it refers to the rows of A
panzoom(c, yx_ranges[2], yx_ranges[1])                                # Initialize panzoom, with arguments for x-y yx_ranges.
panzoom_mouse(c)                                                      # Initialize mouse functions for panning/zooming


@guarded draw(c) do widget
    xview, yview = guidata[widget, :xview], guidata[widget, :yview]   #
    xv = round(Int, xview.min):round(Int, xview.max)                  #
    yv = round(Int, yview.min):round(Int, yview.max)                  #
    region_of_interest = view(A, yv, xv)                              # select subset of A according to the indices yv and xv
    copy!(widget, region_of_interest)                                 # copy the region of interest into c (widget)

    set_coordinates( getgc(widget),                                        # set_coordinates "associates" the two input intervals with the canvas "widget" (in this case, allows double zooming)
                BoundingBox(0,width(widget),                          # BoundingBox describing total viewable area in canvas (changes if you scale)
                            0,height(widget)),                        #
                BoundingBox(xview.min, xview.max,                     # BoundingBox describing current image size
                            yview.min, yview.max) )                   #

end


showall(win)
