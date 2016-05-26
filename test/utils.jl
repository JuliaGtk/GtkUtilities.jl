using Gtk.ShortNames, Colors, Reactive

let c = @Canvas(), win = @Window(c, "Canvas1")
    Gtk.draw(c) do widget
        fill!(widget, RGB(1,0,0))
    end
    showall(win)
    ks = keysignal(c)
    preserve(map(event->println(Char(event.keyval), ' ', event.state), ks))
end

let c = @Canvas(), win = @Window(c, "Canvas2")
    Gtk.draw(c) do widget
        w, h = Int(width(widget)), Int(height(widget))
        randcol = reinterpret(RGB{U8}, rand(0x00:0xff, 3, w, h), (w, h))
        copy!(widget, randcol)
    end
    showall(win)
end
