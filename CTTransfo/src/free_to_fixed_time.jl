function p_time_freeToFixed!(ts, p, p_ocp, t, t0, tf)
    println("free to fixed time")
    ts.original_t0 = t0
    ts.original_tf = tf
    return :($t ∈ [$(ts.t0), $(ts.tf)], time)
end

@with_kw mutable struct FreeToFixedTime <: AbstractTransformation
    t0::Int64
    tf::Int64
    original_t0::Union{Int64,Nothing} = nothing
    original_tf::Union{Int64,Nothing} = nothing
    k::Union{Float64,Nothing} = nothing
    backend::TransfoBackend = TransfoBackend(name=:free_to_fixed_time)
end

# t = new_t0 + ($original_tf - $original_t0) / ($new_tf - $new_t0) * (s - new_t0)
function FreeToFixedTime(t0::Int64=0, tf::Int64=1)
    ts = FreeToFixedTime(t0=t0, tf=tf)
    add_backend!(ts.backend)
    return ts
end