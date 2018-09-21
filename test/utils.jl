using Gtk, Gtk.ShortNames, Colors, FixedPointNumbers

let c = Canvas(), win = Window(c, "Canvas1")
    Gtk.draw(c) do widget
        fill!(widget, RGB(1,0,0))
    end
    showall(win)
end

let c = Canvas(), win = Window(c, "Canvas2")
    Gtk.draw(c) do widget
        w, h = Int(width(widget)), Int(height(widget))
        randcol = reshape(reinterpret(RGB{N0f8}, rand(0x00:0xff, 3, w*h)), w, h)
        copy!(widget, randcol)
    end
    showall(win)
end

let c = Canvas(), win = Window(c, "Canvas3")
    Gtk.draw(c) do widget
        w, h = Int(width(widget)), Int(height(widget))
        randnum = reshape(reinterpret(N0f8, rand(0x00:0xff, w*h)),w,h)
        copy!(widget, randnum)
    end
    showall(win)
end

let c = Canvas(), win = Window(c, "Canvas4")
    Gtk.draw(c) do widget
        w, h = Int(width(widget)), Int(height(widget))
        img = zeros(w, h)
        img[1,1] = 1.5
        @test_throws ArgumentError copy!(widget, img)
    end
    showall(win)
end
