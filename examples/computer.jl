# Example 2.5 from A. Law (2013): Simulation Modeling and Analysis, 5ed

using EventSimulation
using Distributions   # Exponential distribution
using StatsBase       # weighted mean
using DataFrames      # nicer ouptut of results

mutable struct Job
    tin::Float64  # time when job entered the system
    tout::Float64 # time when job left the system
    ttrue::Float64 # time needed without cycling
    remaining::Float64 # time remaining to finish the job
end

mutable struct SharedComputer <: AbstractState
    a::Exponential{Float64}    # arrival time distribution
    p::Exponential{Float64}    # processing time distribution
    τ::Float64                 # switching time
    q::Float64                 # processing quantum time
    n::Int                     # number of terminals
    reps::Int                  # number of finished jobs to collect
    job_queue::Vector{Job}     # queue of jobs waiting for processing
    finished_jobs::Vector{Job} # list of finished jobs
    job::Union{Job, Nothing}  # current job on computer
    # this structure holds information for reporting
    # for each perior between events it holds the length of queue,
    # if the computer were busy and the length of time period
    state_chunks::Vector{Tuple{Int, Bool, Float64}}
    SharedComputer(a, p, τ, q, n, reps) =
        new(Exponential(a), Exponential(p), τ, q, n, reps,
            Job[], Job[], nothing, Tuple{Int, Bool, Float64}[])
end

function arrival(s)
    ttrue = rand(s.state.p)
    j = Job(s.now, NaN, ttrue, ttrue)
    isnothing(s.state.job) && register!(s, start_compute, 0.0)
    push!(s.state.job_queue, j)
end

function start_compute(s)
    j = popfirst!(s.state.job_queue)
    s.state.job = j
    processed = j.remaining < s.state.q ? j.remaining : s.state.q
    j.remaining -= processed
    register!(s, stop_compute, processed + s.state.τ)
end

function stop_compute(s)
    j = s.state.job
    s.state.job = nothing
    if j.remaining == 0
        j.tout = s.now
        push!(s.state.finished_jobs, j)
        register!(s, arrival, rand(s.state.a))
    else
        push!(s.state.job_queue, j)
    end
    isempty(s.state.job_queue) || register!(s, start_compute, 0.0)
    length(s.state.finished_jobs) == s.state.reps && terminate!(s)
end

monitor(s, Δ) =
    push!(s.state.state_chunks,
          (length(s.state.job_queue), !isnothing(s.state.job), Δ))

function run(a, p, τ, q, n, reps)
    sc = SharedComputer(a, p, τ, q, n, reps)
    s = Scheduler(sc, Float64, monitor)
    for _ in 1:n
        register!(s, arrival, rand(sc.a))
    end
    go!(s)
    chunks = s.state.state_chunks
    (n=n,
     response=mean(j.tout - j.tin for j in s.state.finished_jobs),
     queue=mean(getindex.(chunks, 1), Weights(getindex.(chunks, 3))),
     CPU=mean(getindex.(chunks, 2), Weights(getindex.(chunks, 3))))
end

DataFrame([run(25.0, 0.8, 0.015, 0.1, n, 1000) for n in 10:10:80])
