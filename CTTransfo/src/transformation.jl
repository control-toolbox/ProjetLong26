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

macro transform(e, t_struct, log=false)
    try
        ts_instance = Core.eval(__module__, t_struct)
        
        if e isa Symbol
            return quote 
                original_expr = CTModels.definition($(esc(e)))
                println("Runtime transformation of variable: ", $(QuoteNode(e)))

                code = Base.invokelatest(def_transfo, original_expr, $ts_instance.backend.name; log=$log)
                eval(:( CTParser.@def $code ))
            end
        else
            if @capture(e, CTParser.@def block_)
                expr = block
            else
                expr = e
            end  

            # if no invoke, the backend is unknown
            code = Base.invokelatest(def_transfo, expr, ts_instance.backend.name; log=log)
            eval(:( CTParser.@def $code ))
        end

    catch ex
        rethrow(ex)
    end
end