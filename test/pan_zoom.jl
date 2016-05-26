using Gtk.ShortNames
using GtkUtilities, GtkUtilities.Graphics, Reactive
using Base.Test

# Pure-Reactive tests
# Handling panzoom with keypresses
function typecmp(a, b, name)
    va = getfield(a, name)
    vb = getfield(b, name)
    abs(va-vb) < eps(abs(va)+abs(vb))
end
function Base.Test.test_approx_eq(va::ViewROI, vb::ViewROI, astr, bstr)
    typecmp(va.xview, vb.xview, :min) &&
    typecmp(va.xview, vb.xview, :max) &&
    typecmp(va.yview, vb.yview, :min) &&
    typecmp(va.yview, vb.yview, :max) ||
    error("mismatch: ",
          "\n  ", astr, " = ", va,
          "\n  ", bstr, " = ", vb)
end

function keyevent(keyval, state=0)
    uz32 = UInt32(0)
    Gtk.GdkEventKey(Gtk.GEnum(0),  # event_type
                    C_NULL,    # gdk_window
                    Int8(0),   # send_event
                    uz32,      # time
                    state,
                    keyval,
                    Int32(0),  # length
                    C_NULL,    # string
                    UInt16(0), # hardware_keycode
                    0x00,      # group
                    uz32)      # flags
end
sigviewlimits, sigview = panzoom(ViewROI((0,1), (0,1)), ViewROI((0.4,0.5),(0.6,0.7)))
sigkey = Signal(keyevent('z'))
sigpz = panzoom_key(sigkey, sigviewlimits, sigview; panleft = ('j',0), panright = ('l',0), panup = ('i',0), pandown = ('k',0))
@test_approx_eq value(sigview) ViewROI((0.4,0.5),(0.6,0.7))
push!(sigkey, keyevent('l'))  # panright
yield()
@test_approx_eq value(sigview) ViewROI((0.41,0.51),(0.6,0.7))
push!(sigkey, keyevent('i'))  # panup
yield()
@test_approx_eq value(sigview) ViewROI((0.41,0.51),(0.59,0.69))
push!(sigkey, keyevent('k'))  # pandown
yield()
@test_approx_eq value(sigview) ViewROI((0.41,0.51),(0.6,0.7))
push!(sigkey, keyevent('j'))  # panleft
yield()
@test_approx_eq value(sigview) ViewROI((0.4,0.5),(0.6,0.7))

c = @Canvas()
win = @Window(c, "PanZoomCanvas")
showall(win)
panzoom(c, (0,1), (0,1))

draw(c) do widget
    xview, yview = guidata[widget, :xview], guidata[widget, :yview]
    ctx = getgc(widget)
    set_coords(ctx, xview, yview)
    # Paint red rectangle
    rectangle(ctx, 0, 0, 0.5, 0.5)
    set_source_rgb(ctx, 1, 0, 0)
    fill(ctx)
    # Paint blue rectangle
    rectangle(ctx, 0.5, 0, 0.5, 0.5)
    set_source_rgb(ctx, 0, 0, 1)
    fill(ctx)
    # Paint white rectangle
    rectangle(ctx, 0, 0.5, 1, 0.75)
    set_source_rgb(ctx, 1, 1, 1)
    fill(ctx)
    # Paint green rectangle
    rectangle(ctx, 0, 0.75, 1, 0.25)
    set_source_rgb(ctx, 0, 1, 0)
    fill(ctx)
end

panzoom_key(c)
panzoom_mouse(c)

nothing
