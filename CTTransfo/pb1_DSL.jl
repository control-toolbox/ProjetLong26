using OptimalControl
using NLPModelsIpopt
using Plots
using Moshi
using MacroTools: postwalk, @capture
using MLStyle
using Unicode


""" Rules for transforming the AST of an optimal control problem. 
    These are just examples to show how you can manipulate the AST.
"""
function dummy_rule(expr)
    @match expr begin
        _ => println(expr)
    end
    return postwalk(expr) do x
        if x == 0.5
            return 10.0
        else
            return x
        end
    end
end

# Variable sustitution with t(s) = t0 + ($original_tf - $original_t0) / ($new_tf - $new_t0) * (s - new_t0) and s ∈ [new_t0, new_tf]
function time_substitution(expr, new_t0, new_tf)
    k = nothing
    aliases = OptimalControl.CTParser.__init_aliases()

    return postwalk(expr) do e

        for (target, replacement) in aliases
            e = OptimalControl.CTParser.subs(e, target, replacement)
        end
        
        # println("Visiting node: ", e)
        # t ∈ [t0, tf], time  --->  t ∈ [new_t0, new_tf], time
        if @capture(e, (t_ ∈ [original_t0_, original_tf_], time))
            println("Rule 1: ", e)
            k = :(($original_tf - $original_t0) / ($new_tf - $new_t0))
            return :($t ∈ [$new_t0, $new_tf], time)
        end

        if @capture(e, (var_ ∈ dim_, state))
            println("Found state variable: ", var)
            aliases[Symbol(Unicode.normalize(string(var, "̇")))] = :(∂($var))
        end

        # x(t0) == ...  --->  x(new_t0) == ...
        # x(tf) == ...  --->  x(new_tf) == ...
        if @capture(e, state_(time_arg_))
            println("Rule 2: ", e)
            if time_arg == original_t0
                return :($state($new_t0))
            elseif time_arg == original_tf
                return :($state($new_tf))
            end
        end

        # ẋ(t) == RHS  --->  ẋ(t) == k * (RHS)
        if @capture(e, ∂(der_)(t_) == rhs_) 
            println("Rule 3: ", e)
            return :(∂($der)($t) == $k * ($rhs))
        end
        
        # ∫( L ) -> min  --->  ∫( k * L ) -> min
        if @capture(e, (∫(integrand_) → type_))
            println("Rule 4: ", e)
            return :( ∫( $k * $integrand ) → $type )
        end

        return e
    end
end


""" The @transform macro applies a given rule function to either an existing model (if the input is a variable) or directly to code (if the input is an expression).
    - If the input is a variable (Symbol), it retrieves the model's AST at runtime
        and applies the rule function to it, then re-evaluates the modified AST to create a new model.
    - If the input is code (Expr), it applies the rule function at compile time and returns the modified code for compilation.
"""
macro transform(input, rule_function, args...)

    rule_fn = esc(rule_function)
    if input isa Symbol
        return quote
            local original_expr = definition($(esc(input)))
            println("Runtime transformation of variable: ", $(QuoteNode(input)))

            local new_expr = ($rule_fn)(original_expr, $(args...))

            eval(:( @def $new_expr ))
        end

    else
        return quote
            local input_expr = $(QuoteNode(input))
            if @capture(input_expr, @def block_)
                local target = block
            else
                local target = input_expr
            end
        
            local new_block = ($rule_fn)(target, $(args...))

            eval(:( @def $new_block ))
        end
    end
end


""" Example usage of the @transform macro to manipulate an optimal control problem.
"""

println("\nStarting...\n")

# ocp = @def ocp begin
#     t ∈ [0, 1], time
#     x ∈ R², state
#     u ∈ R, control
#     x(0) == [-1, 0]
#     x(1) == [0, 0]
#     ẋ(t) == [x₂(t), u(t)]
#     ∫( 0.5u(t)^2 ) → min
# end true

# sol = solve(ocp)
# plot(sol)

# n_ocp = @transform ocp time_substitution 8 10
# n_ocp = @transform dummy_rule ocp
# definition(n_ocp) |> println

# sol2 = solve(n_ocp)
# plot(sol2)

# @transform (@def begin
#     t ∈ [0, 1], time
#     x ∈ R², state
#     u ∈ R, control
#     x(0) == [-1, 0]
#     x(1) == [0, 0]
#     ẋ(t) == [x₂(t), u(t)]
#     ∫( 0.5u(t)^2 ) → min
# end) time_substitution 8 10

# sol = solve(n_ocp)
# plot(sol)
