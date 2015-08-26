using Base.Test, Gtk.ShortNames, GtkUtilities

win = @Window("New title") |> (f = @Frame("A frame"))
hbox = @Box(:h)  # :h makes a horizontal layout, :v a vertical layout
push!(f, hbox)
cancel = @Button("Cancel")
ok = @Button("OK")
push!(hbox, cancel)
push!(hbox, ok)

line = rand(5)
widgetdata[win,:line] = line
l = widgetdata[win,:line]
@test l == line
@test_throws KeyError widgetdata[win,:lyne]
@test length(widgetdata[win]) == 1

destroy(win)
@test_throws KeyError widgetdata[win,:line]
@test_throws KeyError widgetdata[win]

nothing
