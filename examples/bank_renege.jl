using EventSimulation
using Distributions

@enum CUSTOMER_STATE WAITING CASHING RENEGED FINISHED

type Customer
    name::String
    state::CUSTOMER_STATE
    arrival_time::Float64
end

type BankState <: AbstractState
    all_cust::Int
    n::Int
    reneged_count::Int
    arrival::Exponential{Float64}
    patience::Uniform{Float64}
    cashing::Exponential{Float64}
    counter::Queue{Customer}
    report::Bool
end

function source(s::Scheduler)
    s.state.n += 1
    c = Customer(string("Customer", s.state.n), WAITING, s.now)
    s.state.report && @printf("%6.4f %s: Here I am\n", s.now, c.name)
    provide!(s, s.state.counter, c)
    register!(s, x -> renege(x, c), rand(s.state.patience))
    if s.state.n < s.state.all_cust
        register!(s, source, rand(s.state.arrival))
    end
end

function renege(s, c)
    if c.state == WAITING
        s.state.reneged_count += 1
        c.state = RENEGED
        s.state.report && @printf("%6.4f %s: RENEGED after %6.4f\n",
                           s.now, c.name, s.now-c.arrival_time)
    end
end

function serve(s, c)
    if c.state == WAITING
        s.state.report && @printf("%6.4f %s: waited %6.4f\n",
                                  s.now, c.name, s.now-c.arrival_time)
        c.state = CASHING
        register!(s, x -> finish(x, c), rand(s.state.cashing))
    else
        request!(s, s.state.counter, serve)
    end
end

function finish(s, c)
    s.state.report && @printf("%6.4f %s: Finished\n", s.now, c.name)
    c.state = FINISHED
    request!(s, s.state.counter, serve)
end

function run(ccount, report)
    bs = BankState(ccount, 0, 0, Exponential(10.0),
                   Uniform(1.0, 3.0), Exponential(12.0),
                   Queue{Customer}(), report)
    report && println("Bank renege")
    s = Scheduler(bs)
    request!(s, bs.counter, serve)
    source(s)
    go!(s, Inf)
    println("Renege probability: ", bs.reneged_count / bs.all_cust)
end

@time run(10, true)
@time run(1_000_000, false)

