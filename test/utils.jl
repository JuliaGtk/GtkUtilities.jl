using Gtk.ShortNames, Colors

let c = @Canvas(), win = @Window(c, "Canvas1")
    Gtk.draw(c) do widget
        fill!(widget, RGB(1,0,0))
    end
    showall(win)
end

let c = @Canvas(), win = @Window(c, "Canvas2")
    Gtk.draw(c) do widget
        w, h = Int(width(widget)), Int(height(widget))
        randcol = reinterpret(RGB{U8}, rand(0x00:0xff, 3, w, h), (w, h))
        copy!(widget, randcol)
    end
    showall(win)
end
