module Link

using Gtk.ShortNames

export
    # Types
    State,
    # Functions
    link,
    get,
    set!,
    set_quietly!


abstract AbstractState{T}
abstract AbstractLinkedWidget{T,W<:Gtk.GtkWidget}

### AbstractState objects hold values and sync to UI elements
# They have at least two fields: `value` and `widgets`

Base.eltype{T}(::Type{AbstractState{T}}) = T
Base.eltype{S<:AbstractState}(::Type{S}) = eltype(super(S))

Base.get(state::AbstractState) = state.value

add_widget!(state::AbstractState, w) = push!(state.widgets, w)

function Base.show(io::IO, state::AbstractState)
    print(io, typeof(state).name.name, "(", state.value)
    for w in state.widgets
        n = getproperty(w.widget, :name, ByteString)
        if !isempty(n)
            print(io, ",\"", n, "\"")
        end
    end
    print(io, ")")
end

### State

type State{T} <: AbstractState{T}
    value::T
    widgets::Vector
end

State{T}(value::T, widgets::Vector = Array(AbstractLinkedWidget{T},0)) = State{T}(value, widgets)

function set!{T}(state::State{T}, value)
    state.value = value
    for w in state.widgets
        set_quietly!(w, value)
    end
    state
end

# Set the value, skipping the input widget
function set!{T}(state::State{T}, widget::AbstractLinkedWidget)
    value = get(widget)
    state.value = value
    for w in state.widgets
        w == widget && continue
        set_quietly!(w, value)
    end
    state
end

### Widgets linked to AbstractState objects

type LinkedWidget{T,W} <: AbstractLinkedWidget{T,W}
    widget::W
    id::UInt
end

# For types like Label that don't have signals usable for set!
type LinkedWidgetStored{T,W,S<:AbstractState} <: AbstractLinkedWidget{T,W}
    widget::W
    id::UInt
    state::S
end

@doc """
`set(w, val)` sets the value of the linked widget `w` and fires
the callback, thereby updating all other linked widgets.
""" ->
function set!(w::AbstractLinkedWidget, val)
    _set!(w, val)  # this might fire the callback, depending on the widget
    emit(w)        # provide this method for those that need explicit firing
    w
end

set!(w::LinkedWidgetStored, val) = set!(w.state, val)

emit(w::AbstractLinkedWidget) = nothing   # fallback method

@doc """
`set_quietly!(w, val)` sets the value of the linked widget `w` without
firing the callback.
""" ->
function set_quietly!(w::AbstractLinkedWidget, val)
    id = w.id
    id != 0 && signal_handler_block(w.widget, w.id)
    _set!(w, val)
    id != 0 && signal_handler_unblock(w.widget, w.id)
    w
end

@doc """
`wlinked = link(state, widget)` links the value of the user-interface
element `widget` to the value of the `AbstractState` `state`. The two
will henceforth be synchronized: calling `get(state)` or
`get(wlinked)` returns the current value, and `set!(state, val)` or
`set!(wlinked, val)` will change the value for all mutually-linked
objects.
"""
function link{T}(val::AbstractState{T}, widget::Gtk.GtkWidget)
    w = LinkedWidget{T,typeof(widget)}(widget, 0)
    _link(val, w)
end

function _link{T}(val::AbstractState{T}, w::AbstractLinkedWidget)
    _set!(w, get(val))
    id = link(val, w)
    w.id = id
    add_widget!(val, w)
    w
end

function Base.show(io::IO, w::AbstractLinkedWidget)
    print(io, typeof(w).name.name, " ", typeof(w.widget).name.name, "(", get(w), ")")
    n = getproperty(w.widget, :name, ByteString)
    if !isempty(n)
        print(io, ",\"", n, "\"")
    end
end


## Label

function link{T}(val::AbstractState{T}, w::Label)
    w = LinkedWidgetStored{T,typeof(w),typeof(val)}(w, 0, val)
    _link(val, w)
end

function link{T,W<:Label}(val::AbstractState{T}, w::LinkedWidgetStored{T,W})
    0
end

function Base.get{T<:AbstractString,W<:Label}(w::LinkedWidgetStored{T,W})
    val = getproperty(w.widget, :label, ByteString)
    convert(T, val)::T
end

function Base.get{T<:Number,W<:Label}(w::LinkedWidgetStored{T,W})
    val = getproperty(w.widget, :label, ByteString)
    parse(T, val)::T
end

function _set!{T,W<:Label}(w::LinkedWidgetStored{T,W}, value)
    setproperty!(w.widget, :label, string(value))
end

## Entry

function link{T,W<:Entry}(val::AbstractState{T}, w::LinkedWidget{T,W})
    signal_connect(w.widget, :activate) do widget
        set!(val, get(w))
    end
end

function Base.get{T<:AbstractString,W<:Entry}(w::LinkedWidget{T,W})
    val = getproperty(w.widget, :text, ByteString)
    convert(T, val)::T
end

function Base.get{T<:Number,W<:Entry}(w::LinkedWidget{T,W})
    val = getproperty(w.widget, :text, ByteString)
    parse(T, val)::T
end

function _set!{T,W<:Entry}(w::LinkedWidget{T,W}, value)
    setproperty!(w.widget, :text, string(value))
end

emit{T,W<:Entry}(w::LinkedWidget{T,W}) = signal_emit(w.widget, :activate, Void)

## Scale

function link{T,W<:Scale}(val::AbstractState{T}, w::LinkedWidget{T,W})
    signal_connect(w.widget, "value-changed") do widget
#        @schedule set!(val, w)    # Gtk.jl #161
        set!(val, w)
    end
end

function Base.get{T,W<:Scale}(w::LinkedWidget{T,W})
    adj = @Adjustment(w.widget)
    val = getproperty(adj, :value, Int)
    convert(T, val)::T
end

function _set!{T,W<:Scale}(w::LinkedWidget{T,W}, value)
    adj = @Adjustment(w.widget)
    setproperty!(adj, :value, value)
end

end
