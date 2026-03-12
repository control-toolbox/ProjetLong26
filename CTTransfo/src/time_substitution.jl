function clean_name(e)
    # If e is an expression like var"tf##221"[1], extract the symbol
    sym = e
    if Meta.isexpr(e, :ref)
        sym = e.args[1]
    end
    
    if sym isa Symbol
        s = string(sym)
        if occursin("##", s)
            original_name = split(s, "##")[1]
            return Symbol(original_name)
        end
    end
    
    return e
end

function p_time_timesub!(ts, p, p_ocp, t, t0, tf)
    t0 isa Int64 || return CTParser.__throw("TimeSubstitution requires t0 to be an integer", p.lnum, p.line)
    tf isa Int64 || return CTParser.__throw("TimeSubstitution requires tf to be an integer", p.lnum, p.line)
    println("timesub time")
    println(p.v)
    dump(t0)
    dump(tf)
    println("  -> Original time interval: [", t0, ", ", tf, "]")
    ts.original_t0 = t0
    ts.original_tf = tf
    ts.k = (tf - t0) / (ts.tf - ts.t0)
    return :($t ∈ [$(ts.t0), $(ts.tf)], time)
end

function p_constraint_timesub!(ts, p, p_ocp, e1, e2, e3, c_type, label)
    line = p.line
    line = replace(line, "($(ts.original_t0))" => "($(ts.t0))")
    line = replace(line, "($(ts.original_tf))" => "($(ts.tf))")
    return Meta.parse(line)
end

function p_dynamics_timesub!(ts, p, args...)
    line = Meta.parse(p.line)
    
    transform_dynamics = (h, args...) -> begin
        e = Expr(h, args...)
        if e.head == :call && e.args[1] == :(==)
            # e1 = ts.k * e.args[3]
            return Expr(:call, :(==), e.args[2], Expr(:call, :*, ts.k, e.args[3]))
        else
            return e
        end
    end
    
    line = CTParser.expr_it(line, transform_dynamics, x -> x)
    return line
end

function p_lagrange_timesub!(ts, p, p_ocp, e, type, args...)
    clean_expr_wrapper = (h, expr_args...) -> clean_name(Expr(h, expr_args...))
    e = CTParser.expr_it(e, clean_expr_wrapper, x -> x)

    line = :($(ts.k) * ∫($e) → $type)
    return line
end

function p_mayer_timesub!(ts, p, p_ocp, e, type)
    clean_expr_wrapper = (h, expr_args...) -> clean_name(Expr(h, expr_args...))
    e = CTParser.expr_it(e, clean_expr_wrapper, x -> x)

    line = :($(ts.k) * $e → $type)
    return line
end

function p_bolza_timesub!(ts, p, p_ocp, e1, e2, type)
    clean_expr_wrapper = (h, expr_args...) -> clean_name(Expr(h, expr_args...))
    e1 = CTParser.expr_it(e1, clean_expr_wrapper, x -> x)
    e2 = CTParser.expr_it(e2, clean_expr_wrapper, x -> x)

    line = :($(ts.k) * $e1 + $(ts.k) * $e2 → $type)
    return line
end

@with_kw mutable struct TimeSubstitution <: AbstractTransformation
    t0::Int64
    tf::Int64
    original_t0::Union{Int64,Nothing} = nothing
    original_tf::Union{Int64,Nothing} = nothing
    k::Float64 = 1.0
    backend::TransfoBackend = TransfoBackend(name=:time_substitution)
end

# t = new_t0 + ($original_tf - $original_t0) / ($new_tf - $new_t0) * (s - new_t0)
function TimeSubstitution(t0::Int64, tf::Int64)
    ts = TimeSubstitution(t0=t0, tf=tf)
    ts.backend.transfo_dict[:time] = (args...) -> p_time_timesub!(ts, args...)
    ts.backend.transfo_dict[:constraint] = (args...) -> p_constraint_timesub!(ts, args...)
    ts.backend.transfo_dict[:dynamics] = (args...) -> p_dynamics_timesub!(ts, args...)
    ts.backend.transfo_dict[:dynamics_coord] = (args...) -> p_dynamics_timesub!(ts, args...)
    ts.backend.transfo_dict[:lagrange] = (args...) -> p_lagrange_timesub!(ts, args...)
    ts.backend.transfo_dict[:mayer] = (args...) -> p_mayer_timesub!(ts, args...)
    ts.backend.transfo_dict[:bolza] = (args...) -> p_bolza_timesub!(ts, args...)
    add_backend!(ts.backend)
    return ts
end