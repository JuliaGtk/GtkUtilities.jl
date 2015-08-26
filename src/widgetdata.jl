module WidgetData

using Gtk, Compat
import Gtk: GtkWidget

export widgetdata

immutable Widgetdata
    data::Dict{GtkWidget,Dict{Symbol,Any}}
end

Widgetdata() = Widgetdata(Dict{GtkWidget,Dict{Symbol,Any}}())

const empty_widgetdata = Dict{Symbol,Any}()

Base.getindex(wd::Widgetdata, w::GtkWidget) = wd.data[w]
Base.getindex(wd::Widgetdata, w::GtkWidget, s::Symbol) = wd.data[w][s]
Base.getindex(wd::Widgetdata, ws::@compat(Tuple{GtkWidget,Symbol})) = wd[ws[1], ws[2]]

function Base.setindex!(wd::Widgetdata, val, w::GtkWidget, s::Symbol)
    d = get(wd.data, w, empty_widgetdata)
    if d == empty_widgetdata
        d = wd.data[w] = Dict{Symbol,Any}()
        signal_connect(w, "destroy") do widget
            delete!(wd.data, w)
        end
    end
    d[s] = val
end

Base.setindex!(wd::Widgetdata, val, ws::@compat(Tuple{GtkWidget,Symbol})) = wd.data[ws[1],ws[2]] = val

function Base.get(wd::Widgetdata, ws::@compat(Tuple{GtkWidget,Symbol}), default)
    d = get(wd.data, ws[1], empty_widgetdata)
    d == empty_widgetdata ? default : get(d, ws[2], default)
end

function Base.delete!(wd::Widgetdata, ws::@compat(Tuple{GtkWidget,Symbol}))
    d = get(wd.data, ws[1], empty_widgetdata)
    d == empty_widgetdata ? wd : (delete!(d, ws[2]); wd)
end

Base.delete!(wd::Widgetdata, w::GtkWidget) = delete!(wd.data, w)

Base.show(io::IO, wd::Widgetdata) = print(io, "widgetdata")

const widgetdata = Widgetdata()

end
