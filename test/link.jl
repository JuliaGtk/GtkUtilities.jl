using GtkUtilities, Gtk.ShortNames, Cairo, GtkUtilities.Graphics
using Test

state = State(7)
e = lEntry(state)
set_gtk_property!(e, :name, "entry")
sc = lScale(state, :h, 1:10)
set_gtk_property!(sc, :name, "scale")
box = Box(:v)
win = Window(box, "Linked")
push!(box, e)
push!(box, sc)
showall(win)

@test get(state)  == 7
@test get(e)  == 7
@test get(sc) == 7
io = IOBuffer()
show(io, state)
@test String(take!(io)) == "State(7,\"entry\",\"scale\")"
set!(state, 5)
@test get(state)  == 5
@test get(e)  == 5
@test get(sc) == 5
set!(e, 9)
@test get(state)  == 9
@test get(e)  == 9
@test get(sc) == 9
set!(sc, 4)
@test get(state)  == 4
@test get(e)  == 4
@test get(sc) == 4

s = State("hello")
l = lLabel(s)
@test get(l) == "hello"
set!(l, "Gtk")
@test get(s) == "Gtk"


module IV

mutable struct Interval
    min::Float64
    max::Float64
end

end

c = Canvas()
win = Window(c)
s = State(IV.Interval(0,1))
link(s, c)

pat = pattern_create_linear(0,0.5,1,0.5)
pattern_add_color_stop_rgb(pat, 0, 0, 1, 0)
pattern_add_color_stop_rgb(pat, 1, 1, 0, 1)
draw(c) do widget
    ctx = getgc(widget)
    h = height(widget)
    w = width(widget)
    iv = get(s)
    bb = BoundingBox(iv.min, iv.max, 0, 1)
    set_coordinates(ctx, BoundingBox(0, w, 0, h), bb)
    rectangle(ctx, 0, 0, 1, 1)
    set_source(ctx, pat)
    fill(ctx)
end

showall(win)
sleep(0.5)
set!(s, IV.Interval(0.25, 0.75))
showall(win)
