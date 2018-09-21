module GuiData

using Gtk

import ..GtkUtilities.Link: AbstractState, disconnect, set!, set_quietly!

export guidata, trigger

struct GUIData{T}
    data::Dict{T,Dict{Symbol,Any}}
end

GUIData() = GUIData(Dict{Any,Dict{Symbol,Any}}())

const empty_guidata = Dict{Symbol,Any}()

# guidata[w, :name] strips the State wrapper, unless requested by keyword
# Likewise, guidata[w, :name] = val set!s the State rather than replacing it,
# unless requested by keyword.

Base.getindex(wd::GUIData, w) = wd.data[w]
function Base.getindex(wd::GUIData, w, s::Symbol; raw::Bool=false)
    ret = wd.data[w][s]
    if !raw && isa(ret, AbstractState)
        return get(ret)
    end
    ret
end
Base.getindex(wd::GUIData{T}, ws::Tuple{T,Symbol}) where T = wd[ws[1], ws[2]]

function Base.setindex!(wd::GUIData, val, w, s::Symbol; raw::Bool=false)
    d = get(wd.data, w, empty_guidata)
    if d == empty_guidata
        d = wd.data[w] = Dict{Symbol,Any}()
        if isa(w, Gtk.GtkWidget)
            signal_connect(destroy_callback, w, "destroy", Nothing, (), false, (w,wd))
        end
    end
    if !raw
        obj = get(d, s, nothing)
        if isa(obj, AbstractState)
            set!(obj, val)
            return val
        end
    end
    d[s] = val
end

@guarded function destroy_callback(widgetptr::Ptr, user_data)
    widget, wd = user_data
    dct = wd.data[widget]
    for (k,v) in dct
        if isa(v, AbstractState)
            disconnect(v)
        end
    end
    delete!(wd.data, widget)
    nothing
end

Base.setindex!(wd::GUIData, val, ws::Tuple{T,Symbol}) where T = wd.data[ws[1],ws[2]] = val

Base.haskey(wd::GUIData, key) = haskey(wd.data, key)

function Base.get(wd::GUIData, ws::Tuple{T,Symbol}, default; raw::Bool=false) where T
    d = get(wd.data, ws[1], empty_guidata)
    val = d == empty_guidata ? default : get(d, ws[2], default)
    if !raw && isa(val, AbstractState)
        return get(val)
    end
    val
end

function Base.delete!(wd::GUIData, ws::Tuple{T,Symbol}) where T
    d = get(wd.data, ws[1], empty_guidata)
    d == empty_guidata ? wd : (delete!(d, ws[2]); wd)
end

Base.delete!(wd::GUIData, w) = delete!(wd.data, w)
Base.show(io::IO, wd::GUIData) = print(io, "GUIdata")

const guidata = GUIData()

"""
`trigger(widgets, symbols)` is used when you want to set several
state variables simultaneously, but don't want to refresh the screen
more frequently than necessary. You can set the `.value` parameter of
the state variables directly, then call `trigger` to synchronize the
GUI.
"""
function trigger(widgets, syms)
    dct = Dict{Gtk.GtkWidget,Any}()
    canvases = Set{Gtk.GtkCanvas}()
    for widget in widgets, sym in syms
        state = get(guidata, (widget, sym), nothing; raw=true)
        if state != nothing
            for w in state.widgets
                dct[w] = get(state)
            end
            for c in state.canvases
                push!(canvases, c)
            end
        end
    end
    for (w,val) in dct
        set_quietly!(w, val)
    end
    for c in canvases
        draw(c)
    end
end

trigger(widget::Gtk.GtkWidget, sym::Symbol) = trigger((widget,), (sym,))
trigger(widget::Gtk.GtkWidget, syms)        = trigger((widget,), syms)
trigger(widgets,               sym::Symbol) = trigger(widgets, (sym,))

"""
Given a widget (Button, Canvas, Window, etc.) or other graphical object
`w`, a value `val` can be associated with ("stored in") `w` using
```
guidata[w, :name] = val
```
where `:name` is the name (a Symbol) you've assigned to `val` for the
purposes of storage.

The value can be retrieved with
```
val = guidata[w, :name]
```
Here are some other things you can do with `guidata`:
```
alldata = guidata[w]           # fetch all data associated with w
val = get(guidata, (w,:name), default)   # returns default if :name not defined
delete!(guidata, (w,:name))    # deletes the value associated with :name
delete!(guidata, w)            # deletes all data associated with w

Example:

    c = Canvas()
    panzoom(c, (0,1), (0,1))
    xview = guidata[c, :xview]
```

Note that if `:name` corresponds to a `State` object, `guidata` will
get/set the **value** of the State object, transparently stripping the
wrapper itself.  This means that you change the value without
destroying any links you have set up.  If you need the state object
itself, use the `raw` keyword:
```jl
    state = getindex(guidata, c, :name; raw=true)     # retrieves a state object
    setindex!(guidata, newstate, c, :name; raw=true)  # replaces the old state object
```
"""
guidata

end
