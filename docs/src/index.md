# EventSimulation.jl

*An event based Discrete Event Simulation engine for Julia.*

## Package features
* register/interrupt execution of events
* resource (continuous homogenous good) reservoir
* queue (arbitrary objects) reservoir

## Examples

Examples contained in `/examples/` directory:
* `mms_example.jl`: comparison of several implementations of M/M/s queue
* `mm1_example.jl`: basic implementation of M/M/1 queue with use of monitor
* `bank_renege_1.jl`: bank renege model (reimplementation of SimPy example)
* `bank_renege_2.jl`: bank renege model (reimplementation of SimPy example)
* `movie_renege.jl`: movie renege model (reimplementation of SimPy example)
* `faxqueue.jl`: a two-stage fax queue model;
  adaptation of Nelson (2013): *Foundations and Methods of Stochastic Simulation*,
  chap. 4.6, example

The models that are reimplemnetation of SimPy run an order of magnitude (>20x)
faster than in [SimPy](https://bitbucket.org/simpy/simpy/) or
[SimJulia](https://github.com/BenLauwens/SimJulia.jl)
process oriented DES engines.

# Types and functions defined in EventSimulation package

```@docs
EventSimulation
Action
AbstractState
EmptyState
Scheduler
register!
repeat_register!
bulk_register!
repeat_bulk_register!
interrupt!
terminate!
go!
AbstractReservoir
ResourceRequest
Resource
Queue
request!
waive!
provide!
withdraw!
PriorityTime
```

