__precompile__()

"""
EventSimulation is an event-based discrete event simulation engine.
"""
module EventSimulation

using Random

export # core.jl
       Action, AbstractState, EmptyState, Scheduler,
       register!, repeat_register!,
       bulk_register!, repeat_bulk_register!,
       interrupt!, terminate!, go!,

       # resource.jl, queue.jl
       AbstractReservoir, # defined in this file
       ResourceRequest, SimResource, SimQueue,
       request!, waive!, provide!, withdraw!,

       # prioritytime.jl
       PriorityTime


include("core.jl")

"""
Abstract class for reservoirs.
`SimQueue` and `SimResource` are concrete types implementing it.
"""
abstract type AbstractReservoir end

"""
    dispatch!(s, r)
    dispatch!(s, q)

Internal function used for dispatching requests in `SimResource` and
`SimQueue`. Puts appropriate `Action`s in `s` immediately.
"""
function dispatch! end

"""
    request!(s, r, quantity, request)
    request!(s, q, request)

Function used to register request for resource in `SimResource`
or object from `SimQueue`.


In `SimResource` requested `quantity` must be provided and
`request` accepts only `Scheduler` argument (it must know what it wanted).
Returns tuple of:
* `true` if successfull and `false` when too many requests were made
* `ResourceRequest` object created

In `SimResource` function `request` must accept one argument `Scheduler`.
In `SimQueue` function `request` must accept two arguments `Scheduler` and object.
"""
function request! end

"""
    waive!(r, res_request)
    waive!(q, request)

Allows to remove first occurence that would be served
of `res_request` from `SimResource` or `request` from `SimQueue`.

Returns `true` on success and `false` if `res_request`
or `request` respectively was not found.
"""
function waive! end

"""
    provide!(s, r, quantity)
    provide!(s, q, object)

Allows to fill `SimResource` with `quantity` or `SimQueue` with `object`.

In `SimResource` changes the balance of `r.quantity`. Given quantity may be
any number, but the balance of `SimResource` will be changed
only in `lo`-`hi` range. Returns the actual change in `SimResource` balance.

In `SimQueue` adds `object` to `q.queue`. Returns `true` on success and
`false` if there were too many objects in queue already.
"""
function provide! end

include("resource.jl")
include("queue.jl")
include("prioritytime.jl")

end # module
