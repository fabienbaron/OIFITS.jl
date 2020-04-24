#
# types.jl --
#
# Definitions of OI-FITS data types.
#
#------------------------------------------------------------------------------

const OIContents = Dict{Symbol,Any}

abstract type OIDataBlock end

mutable struct OITarget <: OIDataBlock
    attached::Bool
    contents::OIContents
    OITarget(contents::OIContents) =
        new(false, contents)
end

mutable struct OIArray <: OIDataBlock
    attached::Bool
    contents::OIContents
    OIArray(contents::OIContents) =
        new(false, contents)
end

mutable struct OIWavelength <: OIDataBlock
    attached::Bool
    contents::OIContents
    OIWavelength(contents::OIContents) =
        new(false, contents)
end

mutable struct OICorrelation <: OIDataBlock
    attached::Bool
    contents::OIContents
    OICorrelation(contents::OIContents) =
        new(false, contents)
end

mutable struct OIPolarization <: OIDataBlock
    attached::Bool
    arr::Union{OIArray,Nothing}
    contents::OIContents
    OIPolarization(contents::OIContents) =
        new(false, nothing, contents)
end

mutable struct OIVis <: OIDataBlock
    attached::Bool
    arr::Union{OIArray,Nothing}
    ins::Union{OIWavelength,Nothing}
    corr::Union{OICorrelation,Nothing}
    contents::OIContents
    OIVis(contents::OIContents) =
        new(false, nothing, nothing, nothing, contents)
end

mutable struct OIVis2 <: OIDataBlock
    attached::Bool
    arr::Union{OIArray,Nothing}
    ins::Union{OIWavelength,Nothing}
    corr::Union{OICorrelation,Nothing}
    contents::OIContents
    OIVis2(contents::OIContents) =
        new(false, nothing, nothing, nothing, contents)
end

mutable struct OIT3 <: OIDataBlock
    attached::Bool
    arr::Union{OIArray,Nothing}
    ins::Union{OIWavelength,Nothing}
    corr::Union{OICorrelation,Nothing}
    contents::OIContents
    OIT3(contents::OIContents) =
        new(false, nothing, nothing, nothing, contents)
end

mutable struct OISpectrum <: OIDataBlock
    attached::Bool
    arr::Union{OIArray,Nothing}
    ins::Union{OIWavelength,Nothing}
    corr::Union{OICorrelation,Nothing}
    contents::OIContents
    OISpectrum(contents::OIContents) =
        new(false, nothing, nothing, nothing, contents)
end

# OIData is any OI-FITS data-block which contains interferometric data.
const OIData = Union{OIVis,OIVis2,OIT3}

"""

`OIMaster` stores the contents of an OI-FITS file.  All data-blocks containing
measurements (OI_VIS, OI_VIS2, OI_T3, OI_SPECTRUM and OI_POLARIZATION) are
stored into a vector and thus indexed by an integer.  Named data-blocks
(OI_ARRAY, OI_WAVELENGTH and OI_CORREL) are indexed by their names (converted
to upper case letters, with leading and trailing spaces stripped, multiple
spaces replaced by a single ordinary space).

"""
mutable struct OIMaster <: AbstractVector{OIDataBlock}
    all::Vector{OIDataBlock}            # All data-blocks
    tgt::Union{OITarget,Nothing}
    arr::Dict{String,OIArray}
    ins::Dict{String,OIWavelength}
    corr::Dict{String,OICorrelation}
    function OIMaster()
        new(Array{OIDataBlock}(undef, 0),
            nothing,
            Dict{String,OIArray}(),
            Dict{String,OIWavelength}(),
            Dict{String,OICorrelation}())
    end
end
