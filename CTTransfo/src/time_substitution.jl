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
    t0 isa Int64 || return __trow("TimeSubstitution requires t0 to be an integer")
    tf isa Int64 || return __trow("TimeSubstitution requires tf to be an integer")
    println("timesub time")
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
    # line = Meta.parse(p.line)
    
    # transform_cost = (h, args...) -> begin
    #     e = Expr(h, args...)
    #     if e.head == :call && e.args[1] == :→
    #         lhs = e.args[2]
    #         rhs = e.args[3]
    #         if lhs isa Expr && lhs.head == :call && lhs.args[1] == :* && length(lhs.args) == 3 &&
    #            lhs.args[3] isa Expr && lhs.args[3].head == :call && lhs.args[3].args[1] == :∫
    #             # parser match e1 * ∫( ... ) not e1 * e2 * ∫( ... )
    #             e1 = ts.k * lhs.args[2]
    #             return Expr(:call, :→, Expr(:call, :*, e1, lhs.args[3]), rhs)
    #         else
    #             return Expr(:call, :→, Expr(:call, :*, ts.k, lhs), rhs)
    #         end
    #     else
    #         return e
    #     end
    # end
    
    # line = CTParser.expr_it(line, transform_cost, x -> x)

    # return line
    println(e)
    line = :($(ts.k) * ∫($e) → $type)
    return line
end

@with_kw mutable struct TimeSubstitution <: AbstractTransformation
    t0::Int64
    tf::Int64
    original_t0::Union{Int64,Nothing} = nothing
    original_tf::Union{Int64,Nothing} = nothing
    k::Union{Float64,Nothing} = nothing
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
    add_backend!(ts.backend)
    return ts
end