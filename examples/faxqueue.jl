using EventSimulation
using Distributions
using Printf

# flow of fax states
# WAITING ---> ENTRY ---> MOVED ---> SPECIAL
#                |                      |
#                |                      v
#                +-----------------> FINISHED
# WAITING   : fax waiting in entry queue
# ENTRY     : fax processed in entry service
# MOVED     : fax waiting in special queue
# SPECIAL   : fax processed in special service
# FINISHED  : fax left the system
@enum STATE WAITING ENTRY MOVED SPECIAL FINISHED

mutable struct Fax
    tin::Float64  # time when customer entered the system
    tout::Float64 # time when customer left the system
    special::Bool # did customer require special queue?
    state::STATE  # current state of the customer
end

mutable struct ServiceCenter <: AbstractState
    ia::Dict{Float64,Exponential{Float64}} # inter arrival distribution
    entry::Uniform{Float64}   # distribution of entry processing time in hours
    special::Uniform{Float64} # distribution of specia processing time in hours
    special_prob::Float64     # probability that fax requires special clerk
    entry_queue::SimQueue{Fax}   # entry queue
    special_queue::SimQueue{Fax} # special queue
    faxes::Vector{Fax}        # archive of all processed faxes

    function ServiceCenter()
        raw_ar = Dict(8.0 => 4.37, 9.0 => 6.24, 10.0 => 5.29, 11.0 => 2.97,
                      12.0 => 2.03, 13.0 => 2.79, 14.0 => 2.36, 15.0 => 1.04)
        ia = Dict(k => Exponential(1/v/60) for (k,v) in raw_ar)
        entry = Uniform(0.5/60, 4.5/60)
        special = Uniform(2.0/60, 6.0/60)
        special_prob = 0.2
        new(ia, entry, special, special_prob,
            SimQueue{Fax}(), SimQueue{Fax}(), Vector{Fax}())
    end
end

# new fax arrivals
function arrival(s)
    s.now > 16.0 && return # stopped when we close the shop!
    fax = Fax(s.now, NaN, false, WAITING) # new fax arrived
    push!(s.state.faxes, fax) # archive it
    provide!(s, s.state.entry_queue, fax) # add to entry queue
    # and schedule arrival of next fax
    register!(s, arrival, rand(s.state.ia[floor(s.now)]))
end

# at 12:00 a new shift is planned
function change_shift(s, ec2, sc2)
    # all morning clerks leave
    # but what is in process at 12:00 is finished by morning clerks
    empty!(s.state.entry_queue.requests)
    empty!(s.state.special_queue.requests)
    # afternoon clerks are scheduled
    # they have to finish processing all faxes even after 16:00
    for i in 1:ec2
        request!(s, s.state.entry_queue, (x,y) -> serve_entry(x, y, Inf))
    end
    for i in 1:sc2
        request!(s, s.state.special_queue, (x,y) -> serve_special(x, y, Inf))
    end
end

# start service of entry clerk that ends the shift at endtime
function serve_entry(s, fax, endtime)
    fax.state = ENTRY
    register!(s, x -> finish_entry(x, fax, endtime), rand(s.state.entry))
end

# finish service of entry clerk that ends the shift at endtime
function finish_entry(s, fax, endtime)
    # was the fax hard - if yes move it to special queue
    if rand() < s.state.special_prob
        fax.special = true
        fax.state = MOVED
        provide!(s, s.state.special_queue, fax)
    else
        fax.state = FINISHED
        fax.tout = s.now
    end

    # if shift is not finished request another fax
    if s.now < endtime
        request!(s, s.state.entry_queue, (x,y) -> serve_entry(x, y, endtime))
    end
end

# start service of special clerk that ends the shift at endtime
function serve_special(s, fax, endtime)
    fax.state = SPECIAL
    register!(s, x -> finish_special(x, fax, endtime), rand(s.state.special))
end

# finish service of special clerk that ends the shift at endtime
function finish_special(s, fax, endtime)
    fax.tout = s.now
    fax.state = FINISHED
    if s.now < endtime
        request!(s, s.state.special_queue, (x,y) -> serve_special(x, y, endtime))
    end
end

# produce a snapshot of simulation state
# if final is true additionaly print summary statistics
function report(s, final=false)
    x = s.state.faxes
    println("time: ", s.now)
    for inst in instances(STATE)
        print("\t", lpad(inst,8),": ", count(y -> y.state == inst, x))
    end
    print("\n\t\t\t   idle:  ", length(s.state.entry_queue.requests))
    println("\t\t\t idle:\t  ", length(s.state.special_queue.requests))
    if final
        @printf("%% special:\t%6.4f\n",
                mean(f.special for f in x))
        @printf("avg normal:\t%6.4f\n",
                mean(f.tout-f.tin for f in x if !f.special))
        @printf("avg special:\t%6.4f\n",
                mean(f.tout-f.tin for f in x if f.special))
    end
end

# run simulation
# gets number of entry and special clerks on morning and afternoon shifts
# if tracing is true then reporting is enabled
function run(ec1, sc1, ec2, sc2, tracing::Bool=false)
    sc = ServiceCenter()
    s = Scheduler(sc)
    if tracing
        # print state every hour
        # take special care of 12:00, when there is a change of shift
        for t in [8, 9, 10, 11, 12-eps(12.0),
                  12+eps(12.0), 13, 14, 15, 16]
            register!(s, report, t)
        end
    end
    # plan to change shift at 12:00, remember that s.now is 0.0 at this point
    register!(s, x -> change_shift(x, ec2, sc2), 12.0)

    # morning clerks are scheduled; they finish job at 12:00
    for i in 1:ec1
        request!(s, sc.entry_queue, (x,y) -> serve_entry(x, y, 12.0))
    end
    for i in 1:sc1
        request!(s, sc.special_queue, (x,y) -> serve_special(x, y, 12.0))
    end

    # set time to 8:00
    s.now = 8.0
    # initiate fax arrival process
    register!(s, arrival, rand(sc.ia[8.0]))
    # and open the shop!
    # simulation will finish naturally when all faxes are processed
    go!(s, Inf)
    tracing && report(s, true)

    # return SLA statistics
    esla = mean(f.tout-f.tin<1/6 for f in sc.faxes if !f.special)
    ssla = mean(f.tout-f.tin<1/6 for f in sc.faxes if f.special)
    return esla, ssla, esla > 0.96 && ssla > 0.8
end

# example run
println("Scenario (16,6,7,3):")
run(16, 6, 7, 3, true)

# check if any other scenario with less or equal number of clerks
# ensures that SLA is met with probability higher than 99%
n = 2048
m = mean(run(17, 7, 8, 4)[3] for i in 1:n)
s = sqrt(m*(1-m)/n)
l, h = m .+ [-2s, 2s]
@printf("\nSLA prob. (95%% CI), scenario (17,7,8,4): %6.4f (%6.4f, %6.4f)", m, l, h)
