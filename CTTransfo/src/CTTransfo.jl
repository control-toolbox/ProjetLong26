"""
[`CTTransfo`](@ref) module.

Lists all the imported modules and packages:

$(IMPORTS)

List of all the exported names:

$(EXPORTS)
"""
module CTTransfo

# imports
using CTBase
using CTParser
using CTModels
using OrderedCollections
using DocStringExtensions
using Parameters # @with_kw: to have default values in struct
using MacroTools: @capture
using OptimalControl

# exports
export AbstractTransformation, TransfoBackend, @transform, apply_transformation, TimeSubstitution, Identity
export clean_name

# sources
include("transformation.jl")
include("time_substitution.jl")
include("identity.jl")

end