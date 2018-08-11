"""
Internal structure that remembers that `quantity` was requested by `request`.
"""
struct ResourceRequest{Q<:Real}
    quantity::Q
    request::Function
end

"""
Resource type for holding numeric values (like amount of liquid).
It stores current `quantity` of matter and its allowed `lo` and `hi` amounts.
Servers can get matter from the resource with optional maximum number of
requests pending for fulfillment.

Fields:
* `quantity`       current quantity in resource
* `lo`            minimum quantity of resource
* `hi`            maximum quantity of resource
* `fifo_requests` if `true` `requests` is FIFO, otherwise LIFO
* `max_requests`  maximum `requests` size
* `requests`      vector of request and requested quantity

Functions in `requests` must accept one argument `Scheduler`, so they should
know the amount they requested. When resource arrives to a queue there is a try
to immediately dispatch it to pending requests. When new request arrives there
is a try to immediately fulfill it.

Initially an empty `SimResource` with no requests is constructed.
Initial `quantity`, `lo` and `hi` may be provided. By default `SimResource` is
empty, and has minimum quantity of zero and unbounded maximum.
"""
mutable struct SimResource{Q<:Real} <: AbstractReservoir
    quantity::Q
    lo::Q
    hi::Q
    fifo_requests::Bool
    max_requests::Int
    requests::Vector{ResourceRequest{Q}}

    function SimResource{Q}(;quantity::Q=zero(Q), lo::Q=zero(Q), hi::Q=typemax(Q),
                      fifo_requests::Bool=true,
                      max_requests::Int=typemax(Int)) where Q
        lo <= quantity <= hi || error("wrong quantity/lo/hi combination")
        max_requests > 0 || error("max_requests must be positive")
        new(quantity, lo, hi, fifo_requests, max_requests,
            Vector{ResourceRequest{Q}}())
    end
end

function dispatch!(s::Scheduler, r::SimResource)
    # while is needed as large provide! can fulfill many requests
    while (!isempty(r.requests) &&
           r.lo <= r.quantity - r.requests[end].quantity <= r.hi)
        req = pop!(r.requests)
        r.quantity -= req.quantity
        register!(s, req.request)
    end
end

function request!(s::Scheduler, r::SimResource{Q}, quantity::Q,
                  request::Function) where Q
    rr = ResourceRequest{Q}(quantity, request)
    length(r.requests) < r.max_requests || return false, rr
    qend = r.fifo_requests ? pushfirst! : push!
    qend(r.requests, rr)
    dispatch!(s, r)
    return true, rr
end

function waive!(r::SimResource{Q}, res_request::ResourceRequest{Q}) where Q
    idx = findfirst(isequal(res_request), r.requests)
    isa(idx, Nothing) && return false
    deleteat!(r.requests, idx)
    return true
end

function provide!(s::Scheduler, r::SimResource{Q}, quantity::Q) where Q
    startq = r.quantity
    # we do not want to oveflow the container, but allow large provisions
    r.quantity = clamp(startq+quantity, r.lo, r.hi)
    added = r.quantity - startq
    dispatch!(s, r)
    return added # return how much was added
end
