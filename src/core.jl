"""
Internal structure holding an information
that `what` should be executed by scheduler at time `when`
`what` should accept one argument of type `Scheduler`.
"""
immutable Action{T<:Real}
    what::Function
    when::T
end

"""
    pq_insert!(pq, what, when)

Specialized core Julia code for insertion to priority queue `pq`
Not exported
Put `Action(what, when)` to `pq`.
Return inserted `Action`
"""
function pq_insert!{T<:Real}(pq::Vector{Action{T}}, what::Function, when::T)
    p = Action(what, when)
    push!(pq, p)
    i = length(pq)
    @inbounds while (j = div(i, 2)) >= 1
        if when < pq[j].when
            pq[i] = pq[j]
            i = j
        else
            break
        end
    end
    pq[i] = p
end

"""
    pq_remove!(pq)

Specialized core Julia code for getting top element from priority queue `pq`
Not exported
Return `Action`
"""
function pq_remove!{T<:Real}(pq::Vector{Action{T}})
    x = pq[1]
    y = pop!(pq)
    if !isempty(pq)
        pq[1] = y
        i = 1
        len = length(pq)
        @inbounds while (l = 2i) <= len
            r = 2i + 1
            j = r > len || pq[l].when < pq[r].when ? l : r
            if pq[j].when < y.when
                pq[i] = pq[j]
                i = j
            else
                break
            end
        end
        pq[i] = y
    end
    return x
end

"""
Abstract type for holding state of the simulation
"""
abstract AbstractState

"""
Simplest concrete type implementing `AbstractState`
that does not hold any data
"""
immutable EmptyState <: AbstractState
end

"""
Holds information about current simulation state
Contains three fields:
* `now`         current simulation time
* `event_queue` priority queue of `Actions` planned to be executed
* `state`       user defined subtype of `AbstractState` of the simulation

If two `Action`s have identical `when` time in `event_queue` then
the order of their execution is undefined
"""
type Scheduler{S <: AbstractState, T <: Real}
    now :: T
    event_queue :: Vector{Action{T}}
    state :: S
end

# Construct empty `Scheduler`
# with `state` and time defined by type `T`
"""
    Scheduler(state, T)

A convenience constructor of `Scheduler`

Arguments:
* `state=EmptyState()` subtype of `AbstractState` to be used by `Scheduler`
* `T=Float64`          type that will be used to hold time in `Scheduler`

By default an empty `event_queue` is created and `now` is set to `zero(T)`
"""
function Scheduler{R<:Real}(state = EmptyState(); T::Type{R} = Float64)
    Scheduler(zero(T), Vector{Action{T}}(), state)
end

# plan to do `what` in `Δ` time from `now` in scheduler `s`
"""
    register!(s, what, Δ)

Put `what` at time `s.now+Δ` to `s.event_queue`.
`what` must accept exactly one argument of type `Scheduler`
"""
function register!{S<:AbstractState, T<:Real}(s::Scheduler{S, T},
                                              what::Function,
                                              Δ::T = zero(T))
    when = s.now + Δ
    pq_insert!(s.event_queue, what, when)
end

"""
    bulk_register!(s, what, Δ, randomize)

Put event at time `s.now+Δ` to `s.event_queue`
that will execute `what(scheduler, w)` for all `w` in `who`.
If `randomize` is `false` then `who` is traversed in natural order
otherwise it is traversed in random order.

`what` must accept exactly tow arguments of type `Scheduler` and `typeof(who)`

Function is designed to efficiently handle case when the same action
has to be executed at the same simulation time by many agents.
"""
function bulk_register!{S<:AbstractState, T<:Real}(s::Scheduler{S, T},
                                                   who::AbstractVector,
                                                   what::Function,
                                                   Δ::T = zero(T),
                                                   randomize::Bool=false)
    function bulk_what(x::Scheduler)
        if randomize
            for i in randperm(length(who))
                what(x, who[i])
            end
        else
            for w in who
                what(x, who[i], x)
            end
        end
    end

    register!(s, bulk_what, Δ)
end

"""
    terminate!(s)

Empties `s.event_queue` which will lead to termination of simulation
unless it is refilled before execution returns to `go!`.
Useful for event-triggered termination of simulation
"""
function terminate!(s::Scheduler)
    empty!(s.event_queue)
end

"""
    go!(s, until)

Runs simulation defined by `s` until `s.now` is greater or equal than `until`
or `s.event_queue` is empty (i.e. nothing is left to be done).
"""
function go!(s::Scheduler, until)
    while s.now < until && !isempty(s.event_queue)
        a = pq_remove!(s.event_queue)
        s.now = a.when
        a.what(s)
    end
end

