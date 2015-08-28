VERSION >= v"0.4.0-dev+6521" && __precompile__()

module GtkUtilities

using Cairo, Gtk.ShortNames

if VERSION < v"0.4.0-dev"
    using Docile, Base.Graphics
else
    using Graphics
end

export
    # GUIData
    guidata,
    # Link
    State,
    link,
    get,
    set!,
    set_quietly!,
    # Rubberband
    rubberband_start,
    # PanZoom
    interior,
    fullview,
    add_pan_key,
    add_pan_mouse,
    add_zoom_key,
    add_zoom_mouse

include("guidata.jl")
using .GuiData
include("link.jl")
using .Link
include("rubberband.jl")
include("panzoom.jl")
using .PanZoom
import .PanZoom: interior, fullview   # for extensions

@doc """
Summary of features in GtkUtilities:

- `rubberband_start`: initiate rubber band selection
- `guidata`: associate user data with on-screen elements

Each of these has detailed help available, e.g., `?guidata`.
""" -> GtkUtilities

end # module
