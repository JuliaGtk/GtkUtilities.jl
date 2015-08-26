VERSION >= v"0.4.0-dev+6521" && __precompile__()

module GtkUtilities

if VERSION < v"0.4.0-dev"
    using Docile, Base.Graphics
else
    using Graphics
end
using Cairo, Gtk.ShortNames

export rubberband_start, guidata

include("rubberband.jl")
include("guidata.jl")
using .GuiData

@doc """
Summary of features in GtkUtilities:

- `rubberband_start`: initiate rubber band selection
- `guidata`: associate user data with on-screen elements

Each of these has detailed help available, e.g., `?guidata`.
""" -> GtkUtilities

end # module
