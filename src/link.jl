module Link

using Gtk.ShortNames

export
    # Types
    AbstractState,
    State,
    # Functions
    link,
    disconnect,
    get,
    set!,
    set_quietly!,
    widget,
    id,
    lLabel,
    lEntry,
    lScale


abstract type AbstractState{T} end
abstract type AbstractLinkedWidget{T,W<:Gtk.GtkWidget} end

### AbstractState objects hold values and sync to UI elements
# They have at least three fields: `value`, `widgets`, and `canvases`

Base.eltype(::Type{AbstractState{T}}) where T = T
Base.eltype(::Type{S}) where {S<:AbstractState} = eltype(super(S))

Base.get(state::AbstractState) = state.value

add_widget!(state::AbstractState, w) = push!(state.widgets, w)
add_canvas!(state::AbstractState, w) = push!(state.canvases, w)

function Base.show(io::IO, state::AbstractState)
    print(io, typeof(state).name.name, "(", state.value)
    for w in state.widgets
        n = get_gtk_property(w.widget, :name, String)
        if !isempty(n)
            print(io, ",\"", n, "\"")
        end
    end
    print(io, ")")
end

### State

mutable struct State{T} <: AbstractState{T}
    value::T
    widgets::Vector
    canvases::Vector{Canvas}
end

function State(value::T;
         widgets::Vector = Array{AbstractLinkedWidget{T}}(undef,0),
         canvases::Vector{Canvas} = Array{Canvas}(undef,0)) where T
    State{T}(value, widgets, canvases)
end

function Base.similar(s::State)
    v = get(s)
    if !isimmutable(v)
        v = copy(v)
    end
    State(v, copy(s.widgets), copy(s.canvases))
end

function set!(state::State{T}, value) where {T}
    state.value = value
    for w in state.widgets
        set_quietly!(w, state.value)
    end
    for c in state.canvases
        draw(c)
    end
    state
end

# Set the value, skipping the input widget
function set!(state::State{T}, widget::AbstractLinkedWidget) where {T}
    value = get(widget)
    state.value = value
    for w in state.widgets
        w == widget && continue
        set_quietly!(w, state.value)
    end
    for c in state.canvases
        draw(c)
    end
    state
end

### Widgets linked to AbstractState objects

mutable struct LinkedWidget{T,W,S<:AbstractState} <: AbstractLinkedWidget{T,W}
    widget::W
    id::UInt
    state::S
end

widget(w::AbstractLinkedWidget) = w.widget
id(w::AbstractLinkedWidget) = w.id

Gtk.get_gtk_property(w::AbstractLinkedWidget, s, ::Type{T}) where {T} = get_gtk_property(widget(w), s, T)
Gtk.set_gtk_property!(w::AbstractLinkedWidget, s, val) = (set_gtk_property!(widget(w), s, val); w)
Base.push!(c::Gtk.GtkRadioButtonGroup, w::LinkedWidget) = push!(c, widget(w))  # ambiguity
Base.push!(c::Gtk.GtkContainer, w::LinkedWidget) = push!(c, widget(w))

"""
`set(w, val)` sets the value of the linked widget `w` and fires
the callback, thereby updating all other linked widgets.
"""
function set!(w::AbstractLinkedWidget, val)
    _set!(w, val)  # this might fire the callback, depending on the widget
    emit(w)        # provide this method for those that need explicit firing
    w
end

set!(w::LinkedWidget, val) = set!(w.state, val)

emit(w::AbstractLinkedWidget) = nothing   # fallback method

"""
`set_quietly!(w, val)` sets the value of the linked widget `w` without
firing the callback.
"""
function set_quietly!(w::AbstractLinkedWidget, val)
    ID = id(w)
    ID != 0 && signal_handler_block(w.widget, ID)
    _set!(w, val)
    ID != 0 && signal_handler_unblock(w.widget, ID)
    w
end

"""
`w_linked = link(state, widget)` links the value of the user-interface
element `widget` to the value of the `AbstractState` `state`. The two
will henceforth be synchronized: calling `get(state)` or
`get(w_linked)` returns the current value, and `set!(state, val)` or
`set!(w_linked, val)` will change the value for all mutually-linked
objects.

`link(state, c)`, where `c` is a `Canvas`, makes `c` a
listener for `state`. There is no return value.
"""
function link(val::AbstractState{T}, widget::Gtk.GtkWidget) where {T}
    w = LinkedWidget{T,typeof(widget),typeof(val)}(widget, 0, val)
    _link(val, w)
end

function link(val::AbstractState{T}, c::Canvas) where {T}
    add_canvas!(val, c)
    nothing
end

function _link(val::AbstractState{T}, w::AbstractLinkedWidget) where {T}
    w.id = create_callback(val, w)
    _set!(w, get(val))
    add_widget!(val, w)
    w
end

function disconnect(val::AbstractState)
    for w in val.widgets
        signal_handler_disconnect(w.widget, w.id)
    end
end

function disconnect(val::AbstractState, c::Canvas)
    index = findfirst(val.canvases, c)
    if index != 0
        deleteat!(val.canvases, index)
    end
    index
end

function Base.show(io::IO, w::LinkedWidget)
    print(io, "Linked ", typeof(w.widget).name.name, "(", get(w), ")")
    n = get_gtk_property(w.widget, :name, String)
    if !isempty(n)
        print(io, ",\"", n, "\"")
    end
end


## Label

function create_callback(val::AbstractState{T}, w::LinkedWidget{T,W}) where {T,W<:Label}
    0
end

function Base.get(w::LinkedWidget{T,W}) where {T<:AbstractString,W<:Label}
    val = get_gtk_property(w.widget, :label, String)
    convert(T, val)::T
end

function Base.get(w::LinkedWidget{T,W}) where {T<:Number,W<:Label}
    val = get_gtk_property(w.widget, :label, String)
    parse(T, val)::T
end

function _set!(w::LinkedWidget{T,W}, value) where {T,W<:Label}
    set_gtk_property!(w.widget, :label, string(value))
end

function lLabel(state::AbstractState)
    lbl = Label(string(get(state)))
    link(state, lbl)
end

## Entry

function create_callback(val::AbstractState{T}, w::LinkedWidget{T,W}) where {T,W<:Entry}
    signal_connect(w.widget, :activate) do widget
        set!(val, get(w))
    end
end

function Base.get(w::LinkedWidget{T,W}) where {T<:AbstractString,W<:Entry}
    val = get_gtk_property(w.widget, :text, String)
    convert(T, val)::T
end

function Base.get(w::LinkedWidget{T,W}) where {T<:Number,W<:Entry}
    val = get_gtk_property(w.widget, :text, String)
    parse(T, val)::T
end

function _set!(w::LinkedWidget{T,W}, value) where {T,W<:Entry}
    set_gtk_property!(w.widget, :text, string(value))
end

emit(w::LinkedWidget{T,W}) where {T,W<:Entry} = signal_emit(w.widget, :activate, Nothing)

function lEntry(state::AbstractState; kwargs...)
    e = Entry(;kwargs...)
    link(state, e)
end

## Scale

# To avoid a segfault, we have to use a low-level approach. See Gtk issue #161
function scale_cb(scaleptr::Ptr, state)
    widget = convert(Scale, scaleptr)
    v = G_.value(widget)
    set!(state, v)
    nothing
end

function create_callback(val::AbstractState{T}, w::LinkedWidget{T,W}) where {T,W<:Scale}
    signal_connect(scale_cb, w.widget, "value-changed", Nothing, (), false, val)
end

function Base.get(w::LinkedWidget{T,W}) where {T,W<:Scale}
    adj = Adjustment(w.widget)
    val = get_gtk_property(adj, :value, Int)
    convert(T, val)::T
end

function _set!(w::LinkedWidget{T,W}, value) where {T,W<:Scale}
    adj = Adjustment(w.widget)
    set_gtk_property!(adj, :value, value)
end

function lScale(state::AbstractState, args...)
    sc = Scale(args...)
    link(state, sc)
end

end
