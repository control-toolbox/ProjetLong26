function p_time_free_to_fixed!(f2f, p, p_ocp, t, t0, tf)
    """
    Transform from free final time to fixed final time.
    Replaces the variable final time tf with a fixed time value.
    """
    # Store the original variable final time symbol for reference
    if tf isa Symbol
        f2f.original_tf_var = tf
    end
    
    println("  -> Converting free time to fixed time (tf = $(f2f.tf))")
    return :($t ∈ [$t0, $(f2f.tf)], time)
end

function p_constraint_free_to_fixed!(f2f, p, p_ocp, e1, e2, e3, c_type, label)
    """
    Transform constraints by replacing variable tf with fixed time value.
    """
    line = p.line
    if !isnothing(f2f.original_tf_var)
        line = replace(line, string(f2f.original_tf_var) => string(f2f.tf))
    end
    return Meta.parse(line)
end

function p_dynamics_free_to_fixed!(f2f, p, args...)
    """
    Dynamics remain unchanged as the time scaling is handled in the constraint transformation.
    """
    return Meta.parse(p.line)
end

function p_lagrange_free_to_fixed!(f2f, p, p_ocp, e, type, args...)
    """
    Lagrange cost remains unchanged.
    """
    return Meta.parse(p.line)
end

function p_mayer_free_to_fixed!(f2f, p, p_ocp, e, type, args...)
    """
    Transform Mayer cost by replacing variable tf with fixed time value.
    """
    e = CTParser.expr_it(e, clean_name, x -> x)
    
    if !isnothing(f2f.original_tf_var)
        e = CTParser.expr_it(e, 
            (h, args...) -> begin
                if h == :ref && args[1] == f2f.original_tf_var
                    return f2f.tf
                else
                    return Expr(h, args...)
                end
            end, 
            x -> x
        )
    end
    
    return :($e → $type)
end

@with_kw mutable struct FreeToFixedTime <: AbstractTransformation
    tf::Float64  # Fixed final time value
    original_tf_var::Union{Symbol,Nothing} = nothing  # Original variable final time symbol
    backend::TransfoBackend = TransfoBackend(name=:free_to_fixed_time)
end

"""
    FreeToFixedTime(tf::Float64)

Create a transformation that converts an optimal control problem with free (variable) 
final time to one with a fixed final time.

# Arguments
- `tf::Float64`: The fixed final time value to use

# Example
```julia
ocp = @transform original_ocp FreeToFixedTime(10.0)
```
"""
function FreeToFixedTime(tf::Float64)
    f2f = FreeToFixedTime(tf=tf)
    f2f.backend.transfo_dict[:time] = (args...) -> p_time_free_to_fixed!(f2f, args...)
    f2f.backend.transfo_dict[:constraint] = (args...) -> p_constraint_free_to_fixed!(f2f, args...)
    f2f.backend.transfo_dict[:dynamics] = (args...) -> p_dynamics_free_to_fixed!(f2f, args...)
    f2f.backend.transfo_dict[:dynamics_coord] = (args...) -> p_dynamics_free_to_fixed!(f2f, args...)
    f2f.backend.transfo_dict[:lagrange] = (args...) -> p_lagrange_free_to_fixed!(f2f, args...)
    f2f.backend.transfo_dict[:mayer] = (args...) -> p_mayer_free_to_fixed!(f2f, args...)
    add_backend!(f2f.backend)
    return f2f
end
