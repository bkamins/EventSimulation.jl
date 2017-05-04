"""
Internal structure that remembers that `quantity` was requested by `request`.
"""
immutable ResourceRequest{Q<:Real}
    quantity::Q
    request::Function
end

"""
Resource type for holding numeric values (like amount of liquid).
It stores current `quantity` of matter and its allowed `lo` and `hi` amounts.
Servers can get objects from the queue with optional maximum number of requests
pending for fulfillment.

Fields:
* `quantiy   `    current quantity in resource
* `lo`            minimum quantity of resource
* `hi`            maximum quantity of resource
* `fifo_requests` if `true` `requests` is fifo, otherwise lifo
* `max_requests`  maximum `requests` size
* `requests`      vector of request and requested quantity

Functions in `requests` must accept one argument `Scheduler`, so they should
know the amount they requested.
When resource arrives to a queue there is a try to immediately dispatch it
to pending requests.
When new request arrives there is a try to immediately fulfill it.

Initially an empty `Resource` with no requests is constructed.
Initial `quantity`, `lo` and `hi` may be provided. By default `Resource` is
empty, and has minimum quantity of zero and unbounded maximum.
"""
type Resource{Q<:Real}
    quantity::Q
    lo::Q
    hi::Q
    fifo_requests::Bool
    max_requests::Int
    requests::Vector{ResourceRequest{Q}}

    function Resource(;quantity::Q=zero(Q), lo::Q=zero(Q), hi::Q=typemax(Q),
                      fifo_requests::Bool=true,
                      max_requests::Int=typemax(Int))
        lo <= quantity <= hi || error("wrong quantity/lo/hi combination")
        max_requests > 0 || error("max_requests must be positive")
        new(quantity, lo, hi, fifo_requests, max_requests, Vector{ResourceRequest{Q}}())
    end
end

function dispatch!{S<:AbstractState, T<:Real, Q<:Real}(s::Scheduler{S,T}, r::Resource{Q})
    # here while is needed - a large provide! can fulfill many requests
    while (!isempty(r.requests) &&
           r.lo <= r.quantity - r.requests[end].quantity <= r.hi)
        req = pop!(r.requests)
        r.quantity -= req.quantity
        register!(s, req.request)
    end
end

function request!{Q<:Real, S<:AbstractState, T<:Real}(s::Scheduler{S,T}, r::Resource{Q}, quantity::Q, request::Function)
    length(r.requests) < r.max_requests || return false
    qend = r.fifo_requests ? unshift! : push!
    qend(r.requests, ResourceRequest{Q}(quantity, request))
    dispatch!(s, r)
    return true
end

function provide!{Q<:Real, S<:AbstractState, T<:Real}(s::Scheduler{S,T}, r::Resource{Q}, quantity::Q)
    startq = r.quantity
    # we do not want to oveflow the container, but allow large provisions
    r.quantity = clamp(startq+quantity, r.lo, r.hi)
    added = r.quantity - startq
    dispatch!(s, r)
    return added # return how much was added
end

