using OptimalControl
using OrderedCollections
using Parameters # @with_kw: to have default values in struct
using MacroTools: @capture

# --------------------------------------------------------------------------------------------------
# Abstract type and main structure
# --------------------------------------------------------------------------------------------------

abstract type AbstractTransformation end

function p_default_transfo!(p, args...; kwargs...)
    return Meta.parse(p.line)
end

@with_kw mutable struct TransfoBackend
    name::Symbol
    transfo_dict::OrderedDict{Symbol,Function} = OrderedDict{Symbol,Function}(
        :pragma => p_default_transfo!,
        :alias => p_default_transfo!,
        :variable => p_default_transfo!,
        :time => p_default_transfo!,
        :state => p_default_transfo!,
        :control => p_default_transfo!,
        :constraint => p_default_transfo!,
        :dynamics => p_default_transfo!,
        :dynamics_coord => p_default_transfo!,
        :lagrange => p_default_transfo!,
        :mayer => p_default_transfo!,
        :bolza => p_default_transfo!,
    )
end

function add_backend!(backend::TransfoBackend)
    OptimalControl.CTParser.PARSING_DIR[backend.name] = backend.transfo_dict
    OptimalControl.CTParser.ACTIVE_PARSING_BACKENDS[backend.name] = true

    current = OptimalControl.CTParser.PARSING_BACKENDS
    if !(backend.name in current)
        new_tuple = (current..., backend.name)
        Core.eval(OptimalControl.CTParser, :(const PARSING_BACKENDS = $new_tuple))
    end
end

function def_transfo(e, backend_name; log=false)
    # Parsing relies on PARSING_BACKENDS being up to date
    pref = OptimalControl.CTParser.prefix_fun()
    p_ocp = OptimalControl.CTParser.__symgen(:p_ocp)
    p = OptimalControl.CTParser.ParsingInfo()
    ee = QuoteNode(e)
    code = OptimalControl.CTParser.parse!(p, p_ocp, e; log=log, backend=backend_name)
    println("Generated code for transformation ($backend_name):")
    println(code)
    return code
end

macro transform(e, t_struct, log=false)
    try
        ts_instance = Core.eval(__module__, t_struct)
        
        if e isa Symbol
            return quote 
                original_expr = definition($(esc(e)))
                println("Runtime transformation of variable: ", $(QuoteNode(e)))

                code = Base.invokelatest(def_transfo, original_expr, $ts_instance.backend.name; log=$log)
                eval(:( @def $code ))
            end
        else
            if @capture(e, @def block_)
                expr = block
            else
                expr = e
            end  
        end

        # if no invoke, the backend is unknown
        code = Base.invokelatest(def_transfo, expr, ts_instance.backend.name; log=log)
        return eval(:( @def $code ))
    catch ex
        rethrow(ex)
    end
end

# --------------------------------------------------------------------------------------------------
# Example: Time Scaling Transformation with Internal Parameters
# --------------------------------------------------------------------------------------------------

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

function p_time_scaling_transfo!(t_struct, p, p_ocp, t, t0, tf)
    t0 = clean_name(t0)
    tf = clean_name(tf)
    k = t_struct.k
    println("  -> Applying Time Scaling (factor k=$k)")
    
    return :($t ∈ [$t0*$k, $tf*$k], time)
end

@with_kw mutable struct TimeScaling <: AbstractTransformation
    k::Float64
    backend::TransfoBackend = TransfoBackend(name=:time_scaling)
end

function TimeScaling(k::Float64)
    ts = TimeScaling(k=k)
    ts.backend.transfo_dict[:time] = (args...) -> p_time_scaling_transfo!(ts, args...)
    add_backend!(ts.backend)
    return ts
end

ocp = @def begin
    t ∈ [0, 1], time
    x ∈ R², state
    u ∈ R, control
    x(0) == [-1, 0]
    x(1) == [0, 0]
    ẋ(t) == [x₂(t), u(t)]
    ∫( 0.5u(t)^2 ) → min
end

expr = @transform ocp TimeScaling(10.0) true


# pour éviter les substitutions, retrouver la ligne de base et faire le sub dessus (si aliases(l)=expr) (utiliser le aliases d'origine pour éviter les x point ou les aliases rajouter plus tard)