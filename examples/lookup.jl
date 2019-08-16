using EventSimulation
using Distributions

mutable struct Customer
    tin::Float64
    tout::Float64
end

mutable struct Server
    queue::SimQueue{Customer}
    customer::Union{Customer, Nothing}
end

mutable struct State <: AbstractState
    servers::Vector{Server}
    left_customers::Vector{Customer}
    shortest::Bool
    ad::Exponential{Float64}
    sd::Exponential{Float64}
end

function arrival(s)
    if s.state.shortest
        qlen = [length(s.queue) for s in s.state.servers]
        idleserver = isnothing.(s.customer for s in s.state.servers)
        i = argmin(qlen .- idleserver)
        q = s.state.servers[i].queue
    else
        q = rand(s.state.servers).queue
    end
    provide!(s, q, Customer(s.now, NaN))
end

function request_service(server)
    function start_service(s, customer)
        @assert isnothing(server.customer)
        server.customer = customer
        register!(s, finish_service, rand(s.state.sd))
    end

    function finish_service(s)
        server.customer.tout = s.now
        push!(s.state.left_customers, server.customer)
        server.customer = nothing
        request!(s, server.queue, request_service(server))
    end
    start_service
end

function runsim(ar::Number, sr::Number, n::Integer, shortest::Bool)
    servers = [Server(SimQueue{Customer}(), nothing) for i in 1:n]
    ss = State(servers, Customer[],
               shortest, Exponential(1/ar), Exponential(1/sr))
    s = Scheduler(ss)
    repeat_register!(s, arrival, x -> rand(ss.ad))
    for server in ss.servers
        request!(s, server.queue, request_service(server))
    end
    go!(s, 1_000_000)
    mean(c.tout - c.tin for c in s.state.left_customers)
end

@show runsim(1, 0.4, 3, true)
@show runsim(1, 0.4, 3, false)
