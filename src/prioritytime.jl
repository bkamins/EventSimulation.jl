import Base: +, -, ==, <, <=, convert, hash, promote_rule, isfinite

"""
Subtype of `Real` defining a lexicographically comparable pair of `Real`.
It is designed to be used by `Scheduler` where standard real numbers run to a
problem of undefined order of undefined order of removal from priority queue.

`PriorityTime` two fields `time` and `priority` may have different types,
but both have to be subtypes of `Real`.
`priority` should be used to determine order of execution of `Action`s that
have the same time. Two actions with identical `time` and `priority`
have undefined oreder of execution so this should be avoided.

`PriorityTime` type has defined lexicographic order and `+`, `-`.
It is immutable, has a custom `hash` function and conversions from `Real` types.
"""
struct PriorityTime{T1<:Real, T2<:Real}<:Real
    time::T1
    priority::T2
end

"""
    PriorityTime(time)

Construct `PriorityTime` with `priority` randomly generated using `rand()`.
"""
PriorityTime(time::T1) where T1<:Real = PriorityTime{T1,Float64}(time, rand())

# need to define conversion from PriorityTime to PriorityTime to avoid recursion
# as PriorityTime is a subtype of Real
function convert(T::Type{PriorityTime{T1,T2}},
                 x::PriorityTime{T3,T4}) where {T1<:Real, T2<:Real, T3<:Real, T4<:Real}
    PriorityTime{T1,T2}(convert(T1, x.time), convert(T2, x.priority))
end

# Reals other than PriorityTime convert with priority equal to zero of their type
function convert(T::Type{PriorityTime{T1,T2}}, x::T3) where {T1<:Real, T2<:Real, T3<:Real}
    PriorityTime{T1,T2}(convert(T1, x), zero(T2))
end

# need to define promotion from PriorityTime to PriorityTime to avoid recursion
# as PriorityTime is a subtype of Real
function promote_rule(::Type{PriorityTime{T1,T2}},
                      ::Type{PriorityTime{T3,T4}}) where {T1<:Real, T2<:Real, T3<:Real, T4<:Real}
    PriorityTime{promote_type(T1,T3),promote_type(T2,T4)}
end

# Reals other than PriorityTime assume that they are converted to time field.
# Result of promotion is PriorityTime
function promote_rule(::Type{PriorityTime{T1,T2}},
                      ::Type{T3}) where {T1<:Real, T2<:Real, T3<:Real}
    PriorityTime{promote_type(T1,T3),T2}
end

# Need to also handle the case when PriorityTime is a second argument in promotion.
function promote_rule(::Type{T3},
                      ::Type{PriorityTime{T1,T2}}) where {T1<:Real, T2<:Real, T3<:Real}
    PriorityTime{promote_type(T1,T3),T2}
end

# We use tuple hashing algorithm.
function hash(x::PriorityTime{T1,T2}, h::UInt) where {T1<:Real, T2<:Real}
    hash((x.time, x.priority), h)
end

# in addition and subtraction both fields are updated
# so that the operations are commutative
function +(x::PriorityTime{T1,T2}, y::PriorityTime{T1,T2}) where {T1<:Real, T2<:Real}
    PriorityTime{T1,T2}(x.time+y.time, x.priority+y.priority)
end

function -(x::PriorityTime{T1,T2}, y::PriorityTime{T1,T2}) where {T1<:Real, T2<:Real}
    PriorityTime{T1,T2}(x.time-y.time, x.priority-y.priority)
end

# we define lexicographic order on PriorityTime
# where both objectives are maximized and time is more important
function ==(x::PriorityTime{T1,T2}, y::PriorityTime{T1,T2}) where {T1<:Real, T2<:Real}
    x.time==y.time && x.priority==y.priority
end

function <(x::PriorityTime{T1,T2}, y::PriorityTime{T1,T2}) where {T1<:Real, T2<:Real}
    x.time < y.time && return true
    x.time == y.time && x.priority < y.priority && return true
    return false
end

function <=(x::PriorityTime{T1,T2}, y::PriorityTime{T1,T2}) where {T1<:Real, T2<:Real}
    x.time < y.time && return true
    x.time == y.time && x.priority <= y.priority && return true
    return false
end
