@with_kw mutable struct Identity_Transformation <: AbstractTransformation
    backend::TransfoBackend = TransfoBackend(name=:identity)
end

function Identity()
    ts = Identity_Transformation()
    add_backend!(ts.backend)
    return ts
end