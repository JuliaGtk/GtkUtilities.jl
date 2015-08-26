VERSION >= v"0.4.0-dev+6521" && __precompile__()

module GtkUtilities

if VERSION < v"0.4.0-dev"
    using Docile, Base.Graphics
else
    using Graphics
end
using Cairo, Gtk.ShortNames

export rubberband_start, guidata,
    add_pan_key,
    add_pan_mouse,
    add_zoom_key,
    add_zoom_mouse

include("rubberband.jl")
include("guidata.jl")
using .GuiData
include("panzoom.jl")
using .PanZoom

@doc """
Summary of features in GtkUtilities:

- `rubberband_start`: initiate rubber band selection
- `guidata`: associate user data with on-screen elements

Each of these has detailed help available, e.g., `?guidata`.
""" -> GtkUtilities

end # module
