include("transfo_modular.jl")

function p_variable_timesub!(ts, p, p_ocp, v, q, vv; components_names=nothing)
    original_name = vv.value
    if q == 1
        return :($original_name ∈ R, variable)
    end
    return :($original_name ∈ R^$q, variable)
end

#ne fonctionne pas si t0 ou tf temps libre
function p_time_timesub!(ts, p, p_ocp, t, t0, tf)
    println("timesub time")
    t0 = clean_name(t0)
    tf = clean_name(tf)
    ts.k = (tf - t0) / (ts.tf - ts.t0)
    return :($t ∈ [$(ts.t0), $(ts.tf)], time)
end

function p_state_timesub!(ts, p, p_ocp, x, n, xx; components_names=nothing)
    println(p.line)
    println(p_ocp)
    println(x)
    println(n)
    println(xx)
    println(components_names)
    original_name = xx.value
    if n == 1
        return :($original_name ∈ R, state)
    end
    return :($original_name ∈ R^$n, state)
end

function p_constraint_timesub!(ts, p, p_ocp, e1, e2, e3, c_type, label)
    println(e1)
    println(e2)
    println(e3)
    println(c_type)
    println(label)
    return Meta.parse(p.line)
end

@with_kw mutable struct TimeSubstitution <: AbstractTransformation
    t0::Int64
    tf::Int64
    k::Union{Float64,Nothing} = nothing
    backend::TransfoBackend = TransfoBackend(name=:time_substitution)
end

# t = new_t0 + ($original_tf - $original_t0) / ($new_tf - $new_t0) * (s - new_t0)
function TimeSubstitution(t0::Int64, tf::Int64)
    ts = TimeSubstitution(t0=t0, tf=tf)
    ts.backend.transfo_dict[:time] = (args...) -> p_time_timesub!(ts, args...)
    ts.backend.transfo_dict[:constraint] = (args...) -> p_constraint_timesub!(ts, args...)
    # ts.backend.transfo_dict[:variable] = (args...) -> p_variable_timesub!(ts, args...)
    # ts.backend.transfo_dict[:state] = (args...) -> p_state_timesub!(ts, args...)
    add_backend!(ts.backend)
    return ts
end

ocp = @def begin
    t ∈ [0, 1], time
    x ∈ R², state
    u ∈ R, control
    x(2) == [-1, 0]
    x(1) == [0, 0]
    ẋ(t) == [x₂(t), u(t)]
    ∫( 0.5u(t)^2 ) → min
end

expr = @transform ocp TimeSubstitution(8, 10) true