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

### Widgets linked to AbstractState objects

type LinkedWidget{T,W} <: AbstractLinkedWidget{T,W}
    widget::W
    id::UInt
end

@doc """
`set(w, val)` sets the value of the linked widget `w` and fires
the callback, thereby updating all other linked widgets.
""" ->
function set!(w::LinkedWidget, val)
    _set!(w, val)  # this might fire the callback, depending on the widget
    emit(w)        # provide this method for those that need explicit firing
    w
end

emit(w::LinkedWidget) = nothing   # fallback method

@doc """
`set_quietly!(w, val)` sets the value of the linked widget `w` without
firing the callback.
""" ->
function set_quietly!(w::LinkedWidget, val)
    signal_handler_block(w.widget, w.id)
    _set!(w, val)
    signal_handler_unblock(w.widget, w.id)
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
function link{T}(val::AbstractState{T}, w::Gtk.GtkWidget)
    w = LinkedWidget{T,typeof(w)}(w, 0)
    _set!(w, get(val))
    id = link(val, w)
    w.id = id
    add_widget!(val, w)
    w
end

function Base.show(io::IO, w::LinkedWidget)
    print(io, "Linked ", typeof(w.widget).name.name, "(", get(w), ")")
    n = getproperty(w.widget, :name, ByteString)
    if !isempty(n)
        print(io, ",\"", n, "\"")
    end
end

## Scale

function link{T,W<:Scale}(val::AbstractState{T}, w::LinkedWidget{T,W})
    signal_connect(w.widget, :value_changed) do widget
        set!(val, get(w))
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

end
