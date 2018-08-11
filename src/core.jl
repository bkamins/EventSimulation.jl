"""
Structure holding an information
that `what` should be executed by scheduler at time `when`;
`what` should accept one argument of type `Scheduler`.
"""
struct Action{T<:Real}
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
function pq_insert!(pq::Vector{Action{T}}, what::Function, when::T) where T<:Real
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
function pq_remove!(pq::Vector{Action{T}}) where T<:Real
    x = pq[1]
    y = pop!(pq)
    if !isempty(pq)
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
abstract type AbstractState end

"""
Simplest concrete type implementing `AbstractState`
that does not hold any data
"""
struct EmptyState <: AbstractState
end

"""
Holds information about current simulation state
Contains the following fields:
* `now`         current simulation time
* `event_queue` priority queue of `Actions` planned to be executed
* `state`       user defined subtype of `AbstractState` of the simulation
* `monitor`     function that is called before event is triggered
                must accept two arguments `Scheduler` and `Δ`, a difference
                between time of event to be executed and time of last executed event

If two `Action`s have identical `when` time in `event_queue` then
the order of their execution is undefined

When `monitor` is executed the event to happen is still on `event_queue`,
but time is updated to time when the event is to be executed (i.e. `monitor`
sees the state of the simulation just before the event is triggered).
Therefore for calculating summary statistics `monitor` may assume that
the simulation spent `Δ` time in this state.
Function `monitor` should not modify `event_queue[1]` as EventSimulation assumes
that the event to be triggered after `monitor` executes will not be modified.
Additionally it it not guaranteed that `event_queue[1]` will be executed after
`monitor` finishes because simulation might terminate earlier.
"""
mutable struct Scheduler{S<:AbstractState, T<:Real}
    now::T
    event_queue::Vector{Action{T}}
    state::S
    monitor::Function
end

# Construct empty `Scheduler`
# with `state` and time defined by type `T`
"""
    Scheduler(state, T)

A convenience constructor of `Scheduler`

Arguments:
* `state=EmptyState()` subtype of `AbstractState` to be used by `Scheduler`
* `T=Float64`          type that will be used to hold time in `Scheduler`
* `monitor=(s,Δ) -> nothing`  monitor function

By default an empty `event_queue` is created, `now` is set to `zero(T)`
and there is idle `monitor`
"""
function Scheduler(state=EmptyState(), T::Type{R}=Float64,
                   monitor::Function=(s,Δ) -> nothing) where R<:Real
    Scheduler(zero(T), Vector{Action{T}}(), state, monitor)
end

"""
    register!(s, what, Δ)

Put `what` at time `s.now+Δ` to `s.event_queue`.
`what` must accept exactly one argument of type `Scheduler`.
The function does not check if `Δ` is a valid (finite) number.
Returns inserted `Action`.
"""
function register!(s::Scheduler{S, T}, what::Function,
                   Δ::T = zero(T)) where {S<:AbstractState, T<:Real}
    when = s.now + Δ
    pq_insert!(s.event_queue, what, when)
end

"""
    repeat_register!(s, what, interval)

Put `what` to `s.event_queue` repeatedly in time intervals specified by
`interval` function, which must accept one argument of type `Scheduler`.
`what` must accept exactly one argument of type `Scheduler`.
`interval` function is called after the previous event was executed.
Returns `nothing`.
Calling `terminate!` in function `interval` will not stop the simulation.
Instead, if `interval` returns `nothing` the action
is not scheduled and `repeat_register` will effectively terminate.
"""
function repeat_register!(s::Scheduler, what::Function, interval::Function)
    function wrap_what(x)
        what(x)
        i = interval(x)
        isa(i, Nothing) || register!(x, wrap_what, i)
    end
    i = interval(s)
    isa(i, Nothing) || register!(s, wrap_what, i)
    nothing
end

"""
    bulk_register!(s, who, what, Δ, randomize)

Put event at time `s.now+Δ` to `s.event_queue`
that will execute `what(scheduler, w)` for all `w` in `who`.
If `randomize` is `false` then `who` is traversed in natural order
otherwise it is traversed in random order.
`what` must accept exactly two arguments of type `Scheduler` and `eltype(who)`.
The function does not check if `Δ` is a valid (finite) number.
Returns inserted bulk `Action`.

Function is designed to efficiently handle case when the same action
has to be executed at the same simulation time by many agents.
"""
function bulk_register!(s::Scheduler{S, T}, who::AbstractVector,
                        what::Function, Δ::T = zero(T),
                        randomize::Bool=false) where {S<:AbstractState, T<:Real}
    function bulk_what(x::Scheduler)
        if randomize
            for i in randperm(length(who))
                what(x, who[i])
            end
        else
            for w in who
                what(x, w)
            end
        end
    end
    register!(s, bulk_what, Δ)
end

"""
    repeat_bulk_register!(s, who, what, interval, randomize)

Repeat `bulk_register!` at time intervals specified by `interval` function,
which must accept `Scheduler` argument.
`interval` function is called after the previous event was executed.
`what` must accept exactly two arguments of type `Scheduler` and `typeof(who)`.
Returns `nothing`.
Calling `terminate!` in function `interval` will not stop the simulation.
Instead, if `interval` returns `nothing` the action
is not scheduled and `repeat_register` will effectively terminate.
"""
function repeat_bulk_register!(s::Scheduler, who::AbstractVector, what::Function,
                               interval::Function, randomize::Bool=false)
    function wrap_bulk_what(x)
        if randomize
            for j in randperm(length(who))
                what(x, who[j])
            end
        else
            for w in who
                what(x, w)
            end
        end
        i = interval(x)
        isa(i, Nothing) || register!(x, wrap_bulk_what, i)
    end
    i = interval(s)
    isa(i, Nothing) || register!(s, wrap_bulk_what, i)
    nothing
end

"""
    interrupt!(s, a)

First occurrence of `Action` `a` is replaced by no-op in event queue.
This way there is no need to fix heap in this operation and it is fast.
Returns `true` if `a` was found in queue and `false` otherwise.
"""
function interrupt!(s::Scheduler, a::Action)
    i = findfirst(isequal(a), s.event_queue)
    isa(i, Nothing) && return false
    s.event_queue[i] = Action(x -> nothing, s.event_queue[i].when)
    return true
end

"""
    terminate!(s)

Empties `s.event_queue` which will lead to termination of simulation
unless it is refilled before execution returns to `go!`.
Useful for event-triggered termination of simulation.
"""
function terminate!(s::Scheduler)
    empty!(s.event_queue)
end

"""
    go!(s, until)

Runs simulation defined by `s` until `s.now` is greater or equal than `until`
or `s.event_queue` is empty (i.e. nothing is left to be done).
By default `until` equals `Inf`.
"""
function go!(s::Scheduler, until::Real=Inf)
    while !isempty(s.event_queue)
        a = s.event_queue[1]
        when = a.when
        if when <= until
            Δ = when - s.now
            s.now = when
            s.monitor(s, Δ)
            pq_remove!(s.event_queue)
            a.what(s)
        else
            Δ = until - s.now
            s.now = until
            Δ > 0 && s.monitor(s, Δ)
            break
        end
    end
end
