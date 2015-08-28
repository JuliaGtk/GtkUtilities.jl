using GtkUtilities, Gtk.ShortNames, Cairo, GtkUtilities.Graphics
using Base.Test

e = @Entry()
setproperty!(e, :name, "entry")
sc = @Scale(false, 1:10)
setproperty!(sc, :name, "scale")
hbox = @Box(:v)
win = @Window(hbox, "Hi there!")
push!(hbox, e)
push!(hbox, sc)
showall(win)

state = State(7)
elink  = link(state, e)
sclink = link(state, sc)
@test get(state)  == 7
@test get(elink)  == 7
@test get(sclink) == 7
io = IOBuffer()
show(io, state)
@test takebuf_string(io) == "State(7,\"entry\",\"scale\")"
set!(state, 5)
@test get(state)  == 5
@test get(elink)  == 5
@test get(sclink) == 5
set!(elink, 9)
@test get(state)  == 9
@test get(elink)  == 9
@test get(sclink) == 9
set!(sclink, 4)
@test get(state)  == 4
@test get(elink)  == 4
@test get(sclink) == 4

l = @Label("hello")
s = State("world")
llink = link(s, l)
@test get(llink) == "world"
set!(llink, "Gtk")
@test get(s) == "Gtk"


module IV

type Interval
    min::Float64
    max::Float64
end

end

c = @Canvas()
win = @Window(c)
s = State(IV.Interval(0,1))
link(s, c)

pat = pattern_create_linear(0,0.5,1,0.5)
pattern_add_color_stop_rgb(pat, 0, 0, 1, 0)
pattern_add_color_stop_rgb(pat, 1, 1, 0, 1)
draw(c) do widget
    ctx = getgc(c)
    h = height(c)
    w = width(c)
    iv = get(s)
    bb = BoundingBox(iv.min, iv.max, 0, 1)
    set_coords(ctx, BoundingBox(0, w, 0, h), bb)
    rectangle(ctx, 0, 0, 1, 1)
    set_source(ctx, pat)
    fill(ctx)
end

showall(win)
sleep(0.5)
set!(s, IV.Interval(0.25, 0.75))
showall(win)
