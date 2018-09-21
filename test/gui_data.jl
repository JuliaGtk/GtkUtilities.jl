using Test, Gtk.ShortNames, GtkUtilities

win = Window("New title") |> (f = Frame("A frame"))
hbox = Box(:h)  # :h makes a horizontal layout, :v a vertical layout
push!(f, hbox)
cancel = Button("Cancel")
ok = Button("OK")
push!(hbox, cancel)
push!(hbox, ok)

line = rand(5)
guidata[win,:line] = line
l = guidata[win,:line]
@test l == line
@test_throws KeyError guidata[win,:lyne]
@test length(guidata[win]) == 1

destroy(win)
@test_throws KeyError guidata[win,:line]
@test_throws KeyError guidata[win]

nothing
