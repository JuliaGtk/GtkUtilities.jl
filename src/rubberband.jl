# For rubberband, we draw the selection region on the front canvas, and repair
# by copying from the back. Note that the front canvas has
#     user coordinates = device coordinates,
# so device_to_user doesn't do anything. The back canvas has
#     user coordinates = image pixel coordinates,
# so is the correct reference for anything dealing with image pixels.
type RubberBand
    pos1::Vec2
    pos2::Vec2
    moved::Bool
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
@doc """

`rubberband_start(c, x, y, callback_done)` starts a rubber-band
selection on Canvas `c` at position `(x,y)`.  When the user releases
the mouse button, the callback function `callback_done(c, bb)` is run,
where `bb` is the BoundingBox of the selected region.  The callback is
skipped if the user does not move the mouse.

Example:

    c.mouse.button1press = (widget, event) -> begin
        if event.event_type == Gtk.GdkEventType.BUTTON_PRESS
            GtkUtilities.rubberband_start(c, event.x, event.y, (c, bb) -> @show bb)
        end
    end

would set up a Canvas so that rubberband selection starts when the user clicks the mouse, and displays the bounding box of the selection region when finished.
""" ->
function rubberband_start(c::Canvas, x, y, callback_done::Function)
    # Copy the surface to another buffer, so we can repaint the areas obscured by the rubberband
    r = getgc(c)
    save(r)
    reset_transform(r)
    ctxcopy = copy(r)
    rb = RubberBand(Vec2(x,y), Vec2(x,y), false)
    callbacks_old = (c.mouse.button1motion, c.mouse.button1release)
    c.mouse.button1motion = (c, event) -> rubberband_move(c, rb, event.x, event.y, ctxcopy)
    c.mouse.button1release = (c, event) -> rubberband_stop(c, rb, event.x, event.y, ctxcopy, callbacks_old, callback_done)
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

function rubberband_stop(c::Canvas, rb::RubberBand, x, y, ctxcopy, callbacks_old, callback_done)
    c.mouse.button1motion = callbacks_old[1]
    c.mouse.button1release = callbacks_old[2]
    if !rb.moved
        return
    end
    r = getgc(c)
    rb_set(r, rb)
    rb_erase(r, ctxcopy)
    restore(r)
    reveal(c, false)
    x1, y1 = rb.pos1.x, rb.pos1.y
    if abs(x1-x) > 2 || abs(y1-y) > 2
        # It moved sufficiently, let's execute the callback
        xu, yu = device_to_user(r, x, y)
        x1u, y1u = device_to_user(r, x1, y1)
        bb = BoundingBox(min(x1u,xu), max(x1u,xu), min(y1u,yu), max(y1u,yu))
        callback_done(c, bb)
    end
end
