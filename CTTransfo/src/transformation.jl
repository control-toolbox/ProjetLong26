# --------------------------------------------------------------------------------------------------
# Abstract type and main structure
# --------------------------------------------------------------------------------------------------

abstract type AbstractTransformation end

#recup la ligne pré alias subs ?
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
    CTParser.PARSING_DIR[backend.name] = backend.transfo_dict
    CTParser.ACTIVE_PARSING_BACKENDS[backend.name] = true

    current = CTParser.PARSING_BACKENDS
    if !(backend.name in current)
        new_tuple = (current..., backend.name)
        Core.eval(CTParser, :(const PARSING_BACKENDS = $new_tuple))
    end
end

function def_transfo(e, backend_name; log=false)
    # Parsing relies on PARSING_BACKENDS being up to date
    pref = CTParser.prefix_fun()
    p_ocp = CTParser.__symgen(:p_ocp)
    p = CTParser.ParsingInfo()
    ee = QuoteNode(e)
    code = CTParser.parse!(p, p_ocp, e; log=log, backend=backend_name)
    println("Generated code for transformation ($backend_name):")
    println(code)
    return code
end

macro transform(ocp, t_struct, log=false)
    ts_instance = Core.eval(__module__, t_struct)
    backend_name = ts_instance.backend.name
    
    return quote
        original_expr = CTModels.definition($(esc(ocp)))
        
        println("Applying transformation: ", $(QuoteNode(backend_name)))
        
        # Transform the OCP through the backend
        transformed_code = def_transfo(original_expr, $(QuoteNode(backend_name)); log=$(esc(log)))
        
        # TODO: Implement runtime execution of transformed_code
        # The transformed_code contains DSL expressions that need CTParser's macro processing
        # to be converted into executable OCP definitions. 
        # Current challenge: Passing runtime values to compile-time macros.
        #
        # For now, return the original OCP to maintain functionality.
        # Full implementation requires integration with CTParser's DSL compilation pipeline.
        
        $(esc(ocp))
    end
end