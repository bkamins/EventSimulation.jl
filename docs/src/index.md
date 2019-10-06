# EventSimulation.jl

*An event based Discrete Event Simulation engine for Julia.*

Intended as a support library for teaching basic principles of Discrete Event Simulation.

## Package features

* register/interrupt execution of events
* resource (continuous homogenous good) reservoir
* queue (arbitrary objects) reservoir

## Examples

A quick start tutorial can be found [here](@ref tutorial).

Examples contained in `/examples/` directory:
* `mm1_minimal.jl`: a minimal M/M/1 queue implementaton
* `gg1_minimal.jl`: a minimal G/G/1 queue implementaton
* `mms_example.jl`: comparison of several implementations of M/M/s queue
* `mm1_example.jl`: basic implementation of M/M/1 queue with use of monitor
* `bank_renege_1.jl`: bank renege model (reimplementation of SimPy example)
* `bank_renege_2.jl`: bank renege model (reimplementation of SimPy example)
* `movie_renege.jl`: movie renege model (reimplementation of SimPy example)
* `faxqueue.jl`: a two-stage fax queue model;
  adaptation of B. Nelson (2013): *Foundations and Methods of Stochastic Simulation*,
  chap. 4.6, example
* `seq_queue.jl`: Experiment 4.1 from:
  C.-H. Chen, L.H. Lee (2011): *Stochastic Simulation Optimization*
* `repair.jl`: a rewrite of SimJulia.jl example of
  S. Ross (2012): *Simulation*, 5th edition, Section 7.7, p. 124-126
* `computer.jl`: Example 2.5 from A. Law (2013): *Simulation Modeling and Analysis*, 5ed
* `lookup.jl`: model with s queues and s servers with different queue choice policies

The models that are reimplemnetation of SimPy run an order of magnitude (>20x)
faster than in [SimPy](https://bitbucket.org/simpy/simpy/) or
[SimJulia](https://github.com/BenLauwens/SimJulia.jl)
process oriented DES engines.

# Quck overview of EventSimulation functionality

General functionality

* `Action`: information that a given function should be executed at given
  time
* `AbstractState`: abstract type used for holding global simulation state
* `EmptyState`: simplest empty concrete subtype of `AbstractState`
* `Scheduler`: central object in the library jused to store information about
  event queue
* `register!`: puts `Action` into `Scheduler` queue
* `repeat_register!`: puts `Action` into `Scheduler` queue repeatedly
* `bulk_register!`: puts `Action` into `Scheduler` that will affect
  multiple objects
* `repeat_bulk_register!`: puts `Action` into `Scheduler` that will affect
  multiple objects repeatedly
* `interrupt!`: removes one given event from `Scheduler` queue
* `terminate!`: removes all events from `Scheduler` queue
* `go!`: executes the simulation

Containers

* `AbstractReservoir`: abstract type for defining reservoirs
* `SimResource`: reservoir for divisible and homogeneous matter
* `ResourceRequest`: information about request for a resource
* `SimQueue`: reservoir for objects having unique identity
* `request!`: registers demand for a resource/object
* `waive!`: remove registered request from waiting list
* `provide!`: add resource/object to reservoir
  (or remove resource from `SimResource`)
* `withdraw!`: remove object from `SimQueue`
* `length`: number of objects in `SimQueue`

Utilities

* `PriorityTime`: custom subtype of `Real` providing additional attribute
  `priority` to normal time. Useful for giving execution priority of events
  happening at the same time.

Full documentation of types and functions defined in EventSimulation package
can be found [here](@ref reference).
