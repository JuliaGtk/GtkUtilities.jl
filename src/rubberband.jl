module RubberBands

using Graphics, Gtk.ShortNames

export rubberband_start

# For rubberband, we draw the selection region on the front canvas, and repair
# by copying from the back. Note that the front canvas has
#     user coordinates = device coordinates,
# so device_to_user doesn't do anything. The back canvas has
#     user coordinates = image pixel coordinates,
# so is the correct reference for anything dealing with image pixels.
mutable struct RubberBand
    pos1::Vec2
    pos2::Vec2
    moved::Bool
    minpixels::Int
end

const dash   = Float64[3.0,3.0]
const nodash = Float64[]

function rb_erase(r::GraphicsContext, ctxcopy)
    # Erase the previous rubberband by copying from back surface to front
    set_source(r, ctxcopy)
    set_line_width(r, 3)
    set_dash(r, nodash)
    stroke(r)
end

function rb_draw(r::GraphicsContext, rb::RubberBand)
    rb_set(r, rb)
    set_line_width(r, 1)
    set_dash(r, dash, 3.0)
    set_source_rgb(r, 1, 1, 1)
    stroke_preserve(r)
    set_dash(r, dash, 0.0)
    set_source_rgb(r, 0, 0, 0)
    stroke_preserve(r)
end

rb_set(r::GraphicsContext, rb::RubberBand) = rectangle(r, rb.pos1.x, rb.pos1.y, rb.pos2.x-rb.pos1.x, rb.pos2.y-rb.pos1.y)

# callback_done is executed when the user finishes drawing the rubberband.
# Its syntax is callback_done(canvas, boundingbox), where the boundingbox is
# in user coordinates.
"""
`rubberband_start(c, x, y, callback_done; minpixels=2)` starts a rubber-band
selection on Canvas `c` at position `(x,y)`.  When the user releases
the mouse button, the callback function `callback_done(c, bb)` is run,
where `bb` is the BoundingBox of the selected region.  To reduce the
likelihood that clicks used to raise windows will result in
rubber banding, the callback is not executed unless the user drags
the mouse by at least `minpixels` pixels (default value 2).

Example:

    c.mouse.button1press = (widget, event) -> begin
        if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
            GtkUtilities.rubberband_start(c, event.x, event.y, (c, bb) -> @show bb)
        end
    end

would set up a Canvas so that rubberband selection starts when the user clicks the mouse; when the button is released, it displays the bounding box of the selection region.
"""
function rubberband_start(c::Canvas, x, y, callback_done::Function; minpixels::Int=2, update_signal=:button1motion, stop_signal=:button1release)
    # Copy the surface to another buffer, so we can repaint the areas obscured by the rubberband
    r = getgc(c)
    save(r)
    reset_transform(r)
    ctxcopy = copy(r)
    rb = RubberBand(Vec2(x,y), Vec2(x,y), false, minpixels)
    push!((c.mouse, update_signal),  (c, event) -> rubberband_move(c, rb, event.x, event.y, ctxcopy))
    push!((c.mouse, :motion), Gtk.default_mouse_cb)
    push!((c.mouse, stop_signal), (c, event) -> rubberband_stop(c, rb, event.x, event.y, ctxcopy, callback_done; update_signal=update_signal, stop_signal=stop_signal))
    nothing
end

function rubberband_move(c::Canvas, rb::RubberBand, x, y, ctxcopy)
    r = getgc(c)
    if rb.moved
        rb_erase(r, ctxcopy)
    end
    rb.moved = true
    # Draw the new rubberband
    rb.pos2 = Vec2(x, y)
    rb_draw(r, rb)
    reveal(c, false)
end

function rubberband_stop(c::Canvas, rb::RubberBand, x, y, ctxcopy, callback_done; update_signal=:button1motion, stop_signal=:button1release)
    pop!((c.mouse, update_signal))
    pop!((c.mouse, :motion))
    pop!((c.mouse, stop_signal))
    if !rb.moved
        return
    end
    r = getgc(c)
    rb_set(r, rb)
    rb_erase(r, ctxcopy)
    restore(r)
    reveal(c, false)
    x1, y1 = rb.pos1.x, rb.pos1.y
    if abs(x1-x) > rb.minpixels || abs(y1-y) > rb.minpixels
        # It moved sufficiently, let's execute the callback
        xu, yu = device_to_user(r, x, y)
        x1u, y1u = device_to_user(r, x1, y1)
        bb = BoundingBox(min(x1u,xu), max(x1u,xu), min(y1u,yu), max(y1u,yu))
        callback_done(c, bb)
    end
end

end # module
