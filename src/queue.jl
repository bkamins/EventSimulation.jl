"""
SimQueue type for holding arbitrary objects `O`. It allows objects to be waiting
in a queue with optional maximum queue size. Servers can get objects from the
queue with optional maximum number of requests pending for fulfillment.

Fields:
* `fifo_queue`    if `true` `queue` is FIFO, otherwise LIFO
* `max_queue`     maximum `queue` size
* `queue`         vector of objects in a queue
* `fifo_requests` if `true` `requests` is FIFO, otherwise LIFO
* `max_requests`  maximum `requests` size
* `requests`      vector of request functions

Functions in `requests` must accept two arguments `Scheduler` and `O`. When `O`
arrives to a queue there is a try to immediately feed it to pending requests.
When new request arrives there is a try to immediately provide it with `O`.

Initially an empty `SimQueue` with no requests is constructed.
By default `queue` and `requests` have FIFO policy and are unbounded.
"""
mutable struct SimQueue{O} <: AbstractReservoir
    fifo_queue::Bool
    max_queue::Int
    queue::Vector{O}
    fifo_requests::Bool
    max_requests::Int
    requests::Vector{Function}

    function SimQueue{O}(;fifo_queue::Bool=true, max_queue::Int=typemax(Int),
                         fifo_requests::Bool=true,
                         max_requests::Int=typemax(Int)) where O
        max_queue > 0 || error("max_queue must be positive")
        max_requests > 0 || error("max_requests must be positive")
        new(fifo_queue, max_queue, Vector{O}(),
            fifo_requests, max_requests, Vector{Function}())
    end
end

function dispatch!(s::Scheduler, q::SimQueue)
    # technically could be if as it should never happen that
    # the loop executes more than once, but user might tweak the internals ...
    while !isempty(q.requests) && !isempty(q.queue)
        req = pop!(q.requests)
        obj = pop!(q.queue)
        register!(s, x -> req(x, obj)) # plan to execute request immediately
    end
end

function request!(s::Scheduler, q::SimQueue, request::Function)
    length(q.requests) < q.max_requests || return false
    qend = q.fifo_requests ? pushfirst! : push!
    qend(q.requests, request)
    dispatch!(s, q)
    return true
end

function waive!(q::SimQueue, request::Function)
    idx = findfirst(isequal(request), q.requests)
    isa(idx, Nothing) && return false
    deleteat!(q.requests, idx)
    return true
end

function provide!(s::Scheduler, q::SimQueue{O}, object::O) where O
    if length(q.queue) < q.max_queue
        qend = q.fifo_queue ? pushfirst! : push!
        qend(q.queue, object)
        dispatch!(s, q)
        return true
    end
    return false
end

"""
    withdraw!(q, object)

Allows to remove first occurrence that would be served of `object` from `SimQueue`.

Returns `true` on success and `false` if `object` was not found.
"""
function withdraw!(q::SimQueue{O}, object::O) where O
    idx = findfirst(isequal(object), q.queue)
    isa(idx, Nothing) && return false
    deleteat!(q.queue, idx)
    return true
end
