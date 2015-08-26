module GuiData

using Gtk, Compat

export guidata

immutable GUIData{T}
    data::Dict{T,Dict{Symbol,Any}}
end

GUIData() = GUIData(Dict{Any,Dict{Symbol,Any}}())

const empty_guidata = Dict{Symbol,Any}()

Base.getindex{T}(wd::GUIData{T}, w::T) = wd.data[w]
Base.getindex{T}(wd::GUIData{T}, w::T, s::Symbol) = wd.data[w][s]
Base.getindex{T}(wd::GUIData{T}, ws::@compat(Tuple{T,Symbol})) = wd[ws[1], ws[2]]

function Base.setindex!{T}(wd::GUIData{T}, val, w::T, s::Symbol)
    d = get(wd.data, w, empty_guidata)
    if d == empty_guidata
        d = wd.data[w] = Dict{Symbol,Any}()
        if isa(w, Gtk.GtkWidget)
            signal_connect(w, "destroy") do widget
                delete!(wd.data, w)
            end
        end
    end
    d[s] = val
end

Base.setindex!{T}(wd::GUIData{T}, val, ws::@compat(Tuple{T,Symbol})) = wd.data[ws[1],ws[2]] = val

function Base.get{T}(wd::GUIData{T}, ws::@compat(Tuple{T,Symbol}), default)
    d = get(wd.data, ws[1], empty_guidata)
    d == empty_guidata ? default : get(d, ws[2], default)
end

function Base.delete!{T}(wd::GUIData{T}, ws::@compat(Tuple{T,Symbol}))
    d = get(wd.data, ws[1], empty_guidata)
    d == empty_guidata ? wd : (delete!(d, ws[2]); wd)
end

Base.delete!{T}(wd::GUIData{T}, w::T) = delete!(wd.data, w)

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
    bb = BoundingBox(0, 1, 0, 1)
    guidata[c, :zoombb] = bb
```
""" -> guidata

end
