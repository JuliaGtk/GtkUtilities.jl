module GuiData

using Gtk, Compat
if VERSION < v"0.4.0-dev"
    macro doc(ex)
        esc(ex.args[2])
    end
end

import ..GtkUtilities.Link: AbstractState, set!

export guidata

immutable GUIData{T}
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
Base.getindex{T}(wd::GUIData{T}, ws::@compat(Tuple{T,Symbol})) = wd[ws[1], ws[2]]

function Base.setindex!(wd::GUIData, val, w, s::Symbol; raw::Bool=false)
    d = get(wd.data, w, empty_guidata)
    if d == empty_guidata
        d = wd.data[w] = Dict{Symbol,Any}()
        if isa(w, Gtk.GtkWidget)
            signal_connect(w, "destroy") do widget
                delete!(wd.data, w)
            end
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

Base.setindex!{T}(wd::GUIData, val, ws::@compat(Tuple{T,Symbol})) = wd.data[ws[1],ws[2]] = val

function Base.get{T}(wd::GUIData, ws::@compat(Tuple{T,Symbol}), default; raw::Bool=false)
    d = get(wd.data, ws[1], empty_guidata)
    val = d == empty_guidata ? default : get(d, ws[2], default)
    if !raw && isa(val, AbstractState)
        return get(val)
    end
    val
end

function Base.delete!{T}(wd::GUIData, ws::@compat(Tuple{T,Symbol}))
    d = get(wd.data, ws[1], empty_guidata)
    d == empty_guidata ? wd : (delete!(d, ws[2]); wd)
end

Base.delete!(wd::GUIData, w) = delete!(wd.data, w)

Base.show(io::IO, wd::GUIData) = print(io, "GUIdata")

const guidata = GUIData()

@doc """
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

    c = @Canvas()
    panzoom(c, (0,1), (0,1))
    viewx = guidata[c, :viewx]
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
""" -> guidata

end
