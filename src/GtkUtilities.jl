module GtkUtilities

if VERSION < v"0.4.0"
    using Docile, Base.Graphics
else
    using Graphics
end
using Cairo, Gtk.ShortNames

export rubberband_start

include("rubberband.jl")

end # module
