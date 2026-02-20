"""
[`CTTransfo`](@ref) module.

Lists all the imported modules and packages:

$(IMPORTS)

List of all the exported names:

$(EXPORTS)
"""
module CTTransfo

# imports
using OptimalControl
using OrderedCollections
using Parameters # @with_kw: to have default values in struct
using MacroTools: @capture

# exports
export AbstractTransformation, TransfoBackend, @transform

# sources
include("transfo_modular.jl")

end