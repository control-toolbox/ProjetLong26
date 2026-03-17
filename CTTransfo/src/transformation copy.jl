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

# NOTE on @transform macro limitations:
# The transformation code generation works correctly, but execution via eval() 
# has scope limitations. To work around CTParser's internal eval() calls,
# we need to execute in a module where the referenced variables are accessible.

macro transform(e, t_struct, log=false)
    # Evaluate transformation instance at macro time
    ts_instance = Core.eval(__module__, t_struct)
    backend_name = ts_instance.backend.name
    
    # Return a quote that will be executed at the call site
    quote
        #  Capture the calling module for eval() context
        caller_module = @__MODULE__
        
        # Get the OCP definition from the input OCP
        ocp_expr = CTModels.definition($(esc(e)))
        
        # Transform the OCP expression using the backend
        # This returns code (an Expr) that represents the transformed OCP
        transformed_code = def_transfo(ocp_expr, $(QuoteNode(backend_name)); log=$(esc(log)))
        
        # Build the OCP from the transformed code
        # def_fun returns code that needs to be evaluated in the caller's module context
        ocp_code = CTParser.def_fun(transformed_code; log=$(esc(log)))
        
        # Evaluate in the caller's module which has access to the variables
        Core.eval(caller_module, ocp_code)
    end
end