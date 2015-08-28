using GtkUtilities, Gtk.ShortNames
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
