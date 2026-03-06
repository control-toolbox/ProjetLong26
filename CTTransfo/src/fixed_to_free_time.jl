function p_time_fixed_to_free!(f2f, p, p_ocp, t, t0, tf)
    """
    Transform from fixed final time to free final time.
    Introduces a new variable tf representing the final time,
    and normalizes the time interval to [t0, 1].
    """
    println("  -> Converting fixed time to free time (tf_fixed = $(f2f.tf_fixed))")
    return :($t ∈ [$t0, 1], time)
end

function p_variable_fixed_to_free!(f2f, p, p_ocp)
    """
    Add a new variable 'tf' to represent the free final time.
    """
    # Introduce tf as a parameter/variable with bounds
    return :($(f2f.tf_var) ∈ [$interval_start, $interval_end])
end

function p_constraint_fixed_to_free!(f2f, p, p_ocp, e1, e2, e3, c_type, label)
    """
    Transform constraints by replacing fixed tf with variable tf.
    """
    line = p.line
    line = replace(line, string(f2f.tf_fixed) => string(f2f.tf_var))
    return Meta.parse(line)
end

function p_dynamics_fixed_to_free!(f2f, p, args...)
    """
    Scale dynamics by the free final time variable.
    dx/dt_fixed = (1/tf) * dx/dt_normalized, so dx/dt_normalized = tf * dx/dt_fixed
    """
    line = Meta.parse(p.line)
    
    transform_dynamics = (h, expr_args...) -> begin
        e = Expr(h, expr_args...)
        if e.head == :call && e.args[1] == :(==)
            # Transform: dx/d_normalized_time = tf * dx/d_original_time
            # Original: ẋ = f(x, u, t)
            # Normalized: dx/dτ = t_f * f(x, u, t_0 + t_f*τ)
            return Expr(:call, :(==), e.args[2], Expr(:call, :*, f2f.tf_var, e.args[3]))
        else
            return e
        end
    end
    
    line = CTParser.expr_it(line, transform_dynamics, x -> x)
    return line
end

function p_lagrange_fixed_to_free!(f2f, p, p_ocp, e, type, args...)
    """
    Scale Lagrange cost by the free final time variable.
    ∫₀^{T_f} L(x,u,t) dt = ∫₀¹ L(x,u,t₀+T_f*τ) * T_f dτ
    """
    # Wrapper to adapt clean_name to expr_it's signature (head, args...)
    clean_expr_wrapper = (h, expr_args...) -> clean_name(Expr(h, expr_args...))
    e = CTParser.expr_it(e, clean_expr_wrapper, x -> x)

    line = :($(f2f.tf_var) * ∫($e) → $type)
    return line
end

function p_mayer_fixed_to_free!(f2f, p, p_ocp, e, type, args...)
    """
    Transform Mayer cost by replacing fixed tf with variable tf.
    """
    e = CTParser.expr_it(e, clean_name, x -> x)
    
    # Replace the fixed tf value with the variable tf
    e = CTParser.expr_it(e, 
        (h, args...) -> begin
            if h == :ref && args[1] isa Symbol && string(args[1]) == string(f2f.tf_fixed)
                return f2f.tf_var
            else
                return Expr(h, args...)
            end
        end, 
        x -> x
    )
    
    return :($e → $type)
end

@with_kw mutable struct FixedToFreeTime <: AbstractTransformation
    tf_fixed::Float64              # The fixed final time value from the original problem
    tf_var::Symbol = :tf           # Name of the new variable representing free time
    tf_lower::Float64 = 0.1        # Lower bound for the free time variable
    tf_upper::Float64 = 100.0      # Upper bound for the free time variable
    backend::TransfoBackend = TransfoBackend(name=:fixed_to_free_time)
end

"""
    FixedToFreeTime(tf_fixed::Float64; tf_var=:tf, tf_lower=0.1, tf_upper=100.0)

Create a transformation that converts an optimal control problem with fixed 
final time to one with free (variable) final time.

The transformation:
1. Introduces a new variable `tf` representing the final time
2. Normalizes the time interval to [t0, 1]
3. Scales dynamics by `tf`: dx/dτ = tf * dx/dt_original
4. Scales Lagrange cost by `tf`
5. Replaces fixed time references with the variable `tf`

# Arguments
- `tf_fixed::Float64`: The fixed final time value from the original problem
- `tf_var::Symbol`: Name of the new variable (default: `:tf`)
- `tf_lower::Float64`: Lower bound for the time variable (default: 0.1)
- `tf_upper::Float64`: Upper bound for the time variable (default: 100.0)

# Example
```julia
ocp = @transform original_ocp FixedToFreeTime(10.0; tf_lower=5.0, tf_upper=20.0)
```

# Mathematical Details

If the original problem is on [t0, tf_fixed] with dynamics ẋ = f(x, u, t),
the transformed problem is on [t0, 1] with variable tf and normalized dynamics:
    dx/dτ = tf * f(x, u, t0 + tf*τ)
"""
function FixedToFreeTime(tf_fixed::Float64; tf_var=:tf, tf_lower=0.1, tf_upper=100.0)
    f2f = FixedToFreeTime(
        tf_fixed=tf_fixed, 
        tf_var=tf_var, 
        tf_lower=tf_lower, 
        tf_upper=tf_upper
    )
    f2f.backend.transfo_dict[:time] = (args...) -> p_time_fixed_to_free!(f2f, args...)
    f2f.backend.transfo_dict[:constraint] = (args...) -> p_constraint_fixed_to_free!(f2f, args...)
    f2f.backend.transfo_dict[:dynamics] = (args...) -> p_dynamics_fixed_to_free!(f2f, args...)
    f2f.backend.transfo_dict[:dynamics_coord] = (args...) -> p_dynamics_fixed_to_free!(f2f, args...)
    f2f.backend.transfo_dict[:lagrange] = (args...) -> p_lagrange_fixed_to_free!(f2f, args...)
    f2f.backend.transfo_dict[:mayer] = (args...) -> p_mayer_fixed_to_free!(f2f, args...)
    add_backend!(f2f.backend)
    return f2f
end
