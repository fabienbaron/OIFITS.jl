#
# oidata.jl --
#
# Implement OI-FITS data types.
#
#------------------------------------------------------------------------------

###############
# BASIC TYPES #
###############

# Conversion to integer(s) of type `Int`.
to_integer(x::Int) = x
to_integer(x::Integer) = Int(x)
to_integer(x::Array{Int}) = x
to_integer(x::AbstractArray{<:Integer,N}) where {N} = convert(Array{Int,N}, x)
to_integer(x::Tuple{Vararg{Int}}) = x
to_integer(x::Tuple{Vararg{Integer}}) = map(to_integer, x)

# Conversion to floating-point(s) of type `Cdouble`.
to_float(x::Cdouble) = x
to_float(x::Real) = Cdouble(x)
to_float(x::Array{Cdouble}) = x
to_float(x::AbstractArray{<:Real,N}) where {N} = convert(Array{Cdouble,N}, x)
to_float(x::Tuple{Vararg{Cdouble}}) = x
to_float(x::Tuple{Vararg{Real}}) = map(to_float, x)

# Conversion to complex(es) of type `Complex{Cdouble}`.
to_complex(x::Complex{Cdouble}) = x
to_complex(x::Union{Real,Complex{<:Real}}) = convert(Complex{Cdouble}, x)
to_complex(x::Array{Complex{Cdouble}}) = x
to_complex(x::AbstractArray{<:Union{Real,Complex{<:Real}},N}) where {N} =
    convert(Array{Complex{Cdouble},N}, x)
to_complex(x::Tuple{Vararg{Complex{Cdouble}}}) = x
to_complex(x::Tuple{Vararg{Union{Real,Complex{<:Real}}}}) = map(to_complex, x)

# Conversion to a string(s) of type `String`.
#
# `string(x::SubString)` calls `String(x)` so the two are as
# fast. `string(x::Symbol)` is 2-3 tiles slower than `String(x::Symbol)`.
# Hence we call `String`, not `string` in all other cases.
to_string(x::String) = x
to_string(x::AbstractString) = String(x)
to_string(x::Symbol) = String(x)
to_string(x::Array{String}) = x
to_string(x::AbstractArray{<:Union{<:AbstractString,Symbol},N}) where {N} =
    convert(Array{String,N}, x)
to_string(x::Tuple{Vararg{String}}) = x
to_string(x::Tuple{Vararg{Union{AbstractString,Symbol}}}) = map(to_string, x)

"""
    to_fieldname(s)

converts OI-FITS column name `s` into a `Symbol` that can be used as a field
name in OI-FITS structures.

"""
to_fieldname(sym::Symbol) = sym
function to_fieldname(name::AbstractString)
    key = lowercase(name)
    key == "oi_revn" ? :revn : Symbol(replace(key, r"[^a-z0-9_]" => '_'))
end

# OI-FITS files stores the following 4 different data types:
const DTYPE_LOGICAL =  1 # for format letter 'L'
const DTYPE_INTEGER =  2 # for format letters 'I' or 'J'
const DTYPE_REAL    =  3 # for format letters 'D' or 'E'
const DTYPE_COMPLEX =  4 # for format letter 'C'
const DTYPE_STRING  =  5 # for format letter 'A'
const DTYPE_UNKNOWN = -1 # for other letters

"""
    get_dtype(c)

yields the DTYPE code of a FITS table column defined by the letter `c`.
In case of error, `DTYPE_UNKNOWN` (-1) is returned.

"""
get_dtype(c::Char) =
    # It is about 2 times faster to search with a series of tests instead of
    # using a dictionary.  Converting to uppercase/lowercase is much longer so
    # we keep upper- and lowercase version of each letter.
    (c == 'A' ? DTYPE_STRING  :
     c == 'C' ? DTYPE_COMPLEX :
     c == 'D' ? DTYPE_REAL    :
     c == 'E' ? DTYPE_REAL    :
     c == 'I' ? DTYPE_INTEGER :
     c == 'J' ? DTYPE_INTEGER :
     c == 'L' ? DTYPE_LOGICAL :
     c == 'a' ? DTYPE_STRING  :
     c == 'c' ? DTYPE_COMPLEX :
     c == 'd' ? DTYPE_REAL    :
     c == 'e' ? DTYPE_REAL    :
     c == 'i' ? DTYPE_INTEGER :
     c == 'j' ? DTYPE_INTEGER :
     c == 'l' ? DTYPE_LOGICAL : DTYPE_UNKNOWN)

is_logical(::Any) = false
is_logical(::Bool) = true
is_logical(::Array{Bool}) = true

is_string(::Any) = false
is_string(::AbstractString) = true
is_string(::Array{T}) where {T<:AbstractString} = true

is_integer(::Any) = false
is_integer(::Integer) = true
is_integer(::Array{T}) where {T<:Integer} = true

is_float(::Any) = false
is_float(::Real) = true
is_float(::Array{T}) where {T<:Real} = true

is_complex(::Any) = false
is_complex(::Complex) = true
is_complex(::Array{T}) where {T<:Complex} = true


#################
# OI-FITS TYPES #
#################

"""
    contents(db)

yields the contents of data-block `db`.

"""
contents(db::OIDataBlock) = getfield(db, :contents)

"""
    is_attached(db)

yields whether data-block `db` is attached to a master structure.

"""
is_attached(db::OIDataBlock) = getfield(db, :attached)

Base.getproperty(db::OIDataBlock, sym::Symbol) =
    getindex(contents(db), sym)

Base.setproperty!(db::OIDataBlock, sym::Symbol, val) =
    setindex!(contents(db), val, sym)

# Correspondance between OI-FITS data-block names and Julia types.
const _DATABLOCKS = Dict("OI_TARGET"     => OITarget,
                         "OI_WAVELENGTH" => OIWavelength,
                         "OI_ARRAY"      => OIArray,
                         "OI_VIS"        => OIVis,
                         "OI_VIS2"       => OIVis2,
                         "OI_T3"         => OIT3,
                         "OI_SPECTRUM"   => OISpectrum,
                         "OI_CORR"       => OICorrelation,
                         "OI_INSPOL"     => OIPolarization)

"""
    get_oitype(extname) -> T

yields the data-block type `T` associated to the OI-FITS extension `extname`.

"""
get_oitype(extname::Symbol) =
    (extname == :OI_TARGET     ? OITarget       :
     extname == :OI_WAVELENGTH ? OIWavelength   :
     extname == :OI_ARRAY      ? OIArray        :
     extname == :OI_VIS        ? OIVis          :
     extname == :OI_VIS2       ? OIVis2         :
     extname == :OI_T3         ? OIT3           :
     extname == :OI_SPECTRUM   ? OISpectrum     :
     extname == :OI_CORR       ? OICorrelation  :
     extname == :OI_INSPOL     ? OIPolarization :
     bad_extname(extname))

get_oitype(extname::AbstractString) =
    (extname == "OI_TARGET"     ? OITarget       :
     extname == "OI_WAVELENGTH" ? OIWavelength   :
     extname == "OI_ARRAY"      ? OIArray        :
     extname == "OI_VIS"        ? OIVis          :
     extname == "OI_VIS2"       ? OIVis2         :
     extname == "OI_T3"         ? OIT3           :
     extname == "OI_SPECTRUM"   ? OISpectrum     :
     extname == "OI_CORR"       ? OICorrelation  :
     extname == "OI_INSPOL"     ? OIPolarization :
     bad_extname(extname))

 @noinline bad_extname(extname::Union{Symbol,AbstractString}) =
    error("bad OI-FITS datablock name \"$extname\"")


"""
    get_extname(db) -> str

yields the FITS extension name of an OI-FITS data-block `db`.  Argument can
also be a sub-type of `OIDataBlock` or an instance of such a sub-type or a FITS
header instance.

"""
get_extname(::T) where {T<:OIDataBlock} = get_extname(T)
get_extname(::Type{OITarget})       = "OI_TARGET"
get_extname(::Type{OIWavelength})   = "OI_WAVELENGTH"
get_extname(::Type{OIArray})        = "OI_ARRAY"
get_extname(::Type{OIVis})          = "OI_VIS"
get_extname(::Type{OIVis2})         = "OI_VIS2"
get_extname(::Type{OIT3})           = "OI_T3"
get_extname(::Type{OISpectrum})     = "OI_SPECTRUM"
get_extname(::Type{OICorrelation})  = "OI_CORR"
get_extname(::Type{OIPolarization}) = "OI_INSPOL"

get_extname(hdr::FITSHeader) =
    (get_hdutype(hdr) == :binary_table ?
     fixname(get_string(hdr, "EXTNAME", "")) : "")

# OIDataBlock can be indexed by the name (either as a string or as a
# symbol) of the field.
getindex(db::OIDataBlock, key::Symbol) = get(contents(db), key, nothing)
getindex(db::OIDataBlock, key::AbstractString) = getindex(db, Symbol(key))
haskey(db::OIDataBlock, key::Symbol) = haskey(contents(db), key)
haskey(db::OIDataBlock, key::AbstractString) = haskey(contents(db), Symbol(key))
keys(db::OIDataBlock) = keys(contents(db))

function show(io::IO, db::OITarget)
    print(io, "OI_TARGET: ")
    if haskey(db, :target)
        tgt = db[:target]
        n = length(tgt)
        if n > 0
            print(io, "target=")
            for i in 1:n
                print(io, (i == 1 ? "[\"" : ", \""),
                      tgt[i], (i == n ? "\"]" : "\""))
            end
        end
    else
        n = 0
    end
    n == 0 && print(io, "<empty>")
end

function show(io::IO, db::OIArray)
    print(io, "OI_ARRAY: ")
    ntels = (haskey(db, :sta_index) ? length(db[:sta_index]) : 0)
    if haskey(db, :arrname)
        print(io, "arrname=\"", db[:arrname], "\", ", ntels, " telescope(s)")
    else
        print(io, ntels, " telescope(s)")
    end
end

function show(io::IO, db::OIWavelength)
    print(io, "OI_WAVELENGTH: ")
    if ! haskey(db, :insname)
        print(io, "<empty>")
    else
        print(io, "insname=\"", db[:insname], "\"")
        if haskey(db, :eff_wave)
            wave = db[:eff_wave]
            n = length(db[:eff_wave])
            if n < 1
                print(io, " with 0 spectral channels")
            elseif n == 1
                print(io, " with 1 spectral channel at ",
                      round(wave[1]*1e6, digits=3), " µm")
            else
                print(io, " with ", n, " spectral channels from ",
                      round(minimum(wave)*1e6, digits=3), " µm to ",
                      round(maximum(wave)*1e6, digits=3), " µm")
            end
        end
    end
end

function show(io::IO, db::OISpectrum)
    print(io, "OI_SPECTRUM")
end

function show(io::IO, db::OIDataBlock,
              name::AbstractString, nwaves::Integer, ntimes::Integer)
    print(io, name, ": ")
    if nwaves > 0 && ntimes > 0
        print(io, nwaves*ntimes, " measurements in ", nwaves,
              " spectral channel(s) and ", ntimes, " exposure(s)")
    else
        print(io, name, "<empty>")
    end
end

function show(io::IO, db::OIVis)
    if haskey(db, :visamp)
        dims = size(db[:visamp])
        nwaves = dims[1]
        ntimes = dims[2]
    else
        nwaves = 0
        ntimes = 0
    end
    show(io, db, "OI_VIS", nwaves, ntimes)
end

function show(io::IO, db::OIVis2)
    if haskey(db, :vis2data)
        dims = size(db[:vis2data])
        nwaves = dims[1]
        ntimes = dims[2]
    else
        nwaves = 0
        ntimes = 0
    end
    show(io, db, "OI_VIS2", nwaves, ntimes)
end

function show(io::IO, db::OIT3)
    if haskey(db, :t3amp)
        dims = size(db[:t3amp])
        nwaves = dims[1]
        ntimes = dims[2]
    else
        nwaves = 0
        ntimes = 0
    end
    show(io, db, "OI_T3", nwaves, ntimes)
end

function show(io::IO, master::OIMaster)
    print(io, "OI_MASTER: (", length(master.all), " data-block(s))")
    for db in master.all
        print(io, "\n    ")
        show(io, db)
    end
end


####################################
# PARSING OF DATABLOCK DEFINITIONS #
####################################

# OIFormatDef is used to store all the data-block definitions for a given
# revision number.
const OIFormatDef = Dict{String,OIDataBlockDef}

# _FORMATS table is indexed by a 2-tuple composed by the datablock name
# and by the revision number of the corresponding OI-FITS table.
const _FORMATS = Dict{Tuple{String,Int},OIDataBlockDef}()
_FORMATS_key(name::AbstractString, revn::Integer) =
    (to_string(name), to_integer(revn))

# The default format version number.
default_revision() = 2

# _FIELDS is a dictionary indexed by the data-block name (e,g., "OI_VIS"), each
# entry stores a set of its fields.
const _FIELDS = Dict{String,Set{Symbol}}()

"""
    get_def(db)

or

    get_def(extname, revn = default_revision())

yield the format definition for datablock `db` of for the OI-FITS extension
`extname` (e.g., "OI_TARGET") in revision `revn` of OI-FITS standard, throwing
an error if not found.  The returned value is an instance of `OIDataBlockDef`.

    get_def(extname, revn, def)

is similar but returns `def` if the format is not found.

"""
function get_def(extname::AbstractString, revn::Integer = default_revision())
    val = get_def(extname, revn, nothing)
    val === nothing && error("unknown OI-FITS extension \"", extname,
                             "\" (revision ", revn, ")")
    return val
end

get_def(extname::AbstractString, revn::Integer, def) =
    get(_FORMATS, _FORMATS_key(extname, revn), def)

get_def(db::OIDataBlock) =
    get_def(get_extname(db), get_revn(db))

function get_descr(db::OIDataBlock)
    name = get_extname(db)
    revn = get_revn(db)
    return (name, revn, get_def(name, revn))
end

"""
    add_def(extname, revn, defs)

defines revision `revn` of the OI-FITS extension `extname`.  The format of the
OI-FITS extension is described `defs`, a vector of strings like:

    ["KEYWORD FORMAT DESCR",
      ...,
      ...,
     "---------------------------",
     "COLUMN  FORMAT DESCR",
      ...,
      ...,
      ...]

where:

- `KEYWORD` is the keyword name in FITS header.

- `COLUMN` is the column name in FITS table (`TTYPE`).

- `FORMAT` may be prefixed with a `?` to indicate an optional field and is:

  - for keywords, a single letter indicating the type,

  - for columns, a letter indicating the type followed by list of dimensions in
    parenthesis (letter `W` for a dimension means number of wavelengths).

- `DESCR` is a short description; units, if any, are indicated at the end
  between square brackets.

There may be any number of keyword definitions and any number of column
definitions, the two parts are separated by a dash line like

    "--------------".

See also [`get_def`](@ref).

"""
function add_def(extname::AbstractString,
                 revn::Integer,
                 tbl::Vector{<:AbstractString})
    # Check OI-FITS extension name and revision number.
    (startswith(extname, "OI_") && extname == uppercase(extname) &&
     ! occursin(" ", extname)) || error("invalid OI-FITS extension name: \"",
                                        extname, "\"")
    revn ≥ 1 || error("invalid OI-FITS revision number: $revn")
    fmtkey = _FORMATS_key(extname, revn)
    haskey(_FORMATS, fmtkey) && error("revision ", revn,
                                      " of OI-FITS extension ", extname,
                                      " already defined")

    # Parse table of definitions.
    function bad_def(reason::AbstractString, extname::AbstractString,
                     revn::Integer, linenum::Integer, code::AbstractString)
        error(reason, " in definition of OI-FITS extension ", extname,
              " (revision ", revn, ", line ", linenum, "): \"", code, "\"")
    end
    fields = get(_FIELDS, extname, Set{Symbol}())
    def = Array{OIFieldDef}(undef, 0)
    keyword = true
    for rownum in 1:length(tbl)
        row = strip(tbl[rownum])
        m = match(r"^([^ ]+) +([^ ]+) +(.*)$", row)
        if m === nothing
            match(r"^-+$", row) === nothing &&
                bad_def("syntax error", extname, revn, rownum, row)
            keyword = false
            continue
        end
        name = uppercase(m.captures[1])
        symb = to_fieldname(name)
        format = m.captures[2]
        descr = m.captures[3]
        optional = (format[1] == '?')
        i = (optional ? 2 : 1)
        dtype = get_dtype(format[i])
        dtype > 0 || bad_def("invalid type letter", extname, revn, rownum, row)
        if keyword
            length(format) == i ||
                bad_def("invalid keyword format", extname, revn, rownum, row)
            multiplier = 1
        else
            # Very naive code to parse the dimension list of the column format.
            (length(format) > i + 2 && format[i+1] == '('
             && format[end] == ')') || bad_def("missing column dimension(s)",
                                               extname, revn, rownum, row)
            format = uppercase(format[i+2:end-1])
            if format == "W"
                multiplier = -1
            elseif format == "W,W"
                multiplier = -2
            else
                multiplier = tryparse(Int, format)
                (multiplier === nothing || multiplier < 1) &&
                    bad_def("invalid multiplier", extname, revn, rownum, row)
            end
        end
        mp = match(r"^(.*[^ ]) +\[([^\]])\]$", descr)
        if mp === nothing
            units = ""
        else
            descr = mp.captures[1]
            units = mp.captures[2]
        end
        push!(def, OIFieldDef(name, symb, keyword, optional, multiplier,
                              dtype, units, descr))
        push!(fields, symb)
    end

    # Insert the data-block definition in the global table.
    _FORMATS[fmtkey] = OIDataBlockDef(extname, def)
    _FIELDS[extname] = fields
end

##########################
# BUILDING OF DATABLOCKS #
##########################

# Build constructors for the various data-blocks types.
for (func, name) in ((:new_target,     "OI_TARGET"),
                     (:new_array,      "OI_ARRAY"),
                     (:new_wavelength, "OI_WAVELENGTH"),
                     (:new_vis,        "OI_VIS"),
                     (:new_vis2,       "OI_VIS2"),
                     (:new_t3,         "OI_T3"),
                     (:new_spectrum,   "OI_SPECTRUM"),
                     (:new_corr,       "OI_CORR"),
                     (:new_inspol,     "OI_INSPOL"))
    @eval begin
        function $func(master::Union{OIMaster, Nothing}=nothing;
                       revn::Integer = default_revision(), kwds...)
            db = build_datablock($name, revn, kwds)
            if master != nothing
                attach!(master, db)
            end
            return db
        end
    end
end

function build_datablock(extname::AbstractString, revn::Integer, kwds)
    def = get_def(extname, revn)
    contents = OIContents()
    contents[:revn] = to_integer(revn)
    rows = -1         # number of rows in the OI-FITS table
    channels = -1     # number of spectral channels
    for (field, value) in kwds
        # Check whether this field exists.
        spec = get(def.spec, field, nothing)
        spec === nothing && error("OI-FITS extension ", extname,
                                  " has no field `", field, "`")

        # Check value type.
        if spec.dtype == DTYPE_LOGICAL
            is_logical(value) || error("expecting boolean value for `", field,
                                       "` field of OI-FITS extension ",
                                       extname)
        elseif spec.dtype == DTYPE_INTEGER
            is_integer(value) || error("expecting integer value for `", field,
                                       "` field of OI-FITS extension ",
                                       extname)
            value = to_integer(value)
        elseif spec.dtype == DTYPE_REAL
            is_float(value) || error("expecting floating-point value for `",
                                     field, "` field of OI-FITS extension ",
                                     extname)
            value = to_float(value)
        elseif spec.dtype == DTYPE_COMPLEX
            is_complex(value) || error("expecting complex value for `",
                                       field, "` field of OI-FITS extension ",
                                       extname)
            value = to_complex(value)
        elseif spec.dtype == DTYPE_STRING
            is_string(value) || error("expecting string value for `", field,
                                      "` field of OI-FITS extension ", extname)
        else
            error("*** CORRUPTED WORKSPACE ***")
        end

        # Check value dimensions.
        dims = (isa(value, Array) ? size(value) : ())
        rank = length(dims)
        if spec.keyword
            rank == 0 || error("expecting a scalar value for `", field,
                               "` field in OI-FITS extension ", extname)
        else
            # Check array rank.
            mult = spec.multiplier
            maxrank = (spec.dtype == DTYPE_STRING || mult == 1 ? 1 :
                       mult == -2 ? 3 : 2)
            rank > maxrank && error("bad number of dimensions for `", field,
                                    "` field of OI-FITS extension ", extname)

            # Fields may have up to 3 dimensions.  For now, the last dimension
            # is the number of rows.  FIXME: The ordering of dimensions must
            # be changed: the number of rows should be the first dimension.
            dim0 = (rank >= 1 ? dims[end] : 1)
            dim1 = (rank >= 2 ? dims[1] : 1)
            dim2 = (rank >= 3 ? dims[2] : 1)

            if rows == -1
                rows = dim0
            else
                rows == dim0 || error("incompatible number of rows for `",
                                      field, "` field of OI-FITS extension ",
                                      extname)
            end

            if mult < 0
                # Expecting an N-by-W or N-by-W-by-W array (N is the number of
                # rows and W the number of channels).
                (mult == -2 && dim1 != dim2) &&
                    error("bad dimensions for `", field,
                          "` field of OI-FITS extension ", extname)
                if channels == -1
                    channels = dim1
                else
                    channels == dim1 || error("incompatible number of ",
                                              "spectral channels for `",
                                              field,
                                              "` field of OI-FITS extension ",
                                              extname)
                end
            elseif spec.dtype != DTYPE_STRING && dim1 != mult
                error("bad dimensions for `", field,
                      "` field of OI-FITS extension ", extname)
            end
        end

        # Store value.
        contents[field] = value
    end

    # Check that all mandatory fields have been given.
    nerrs = 0
    for field in def.fields
        spec = def.spec[field]
        if ! haskey(contents, field) && ! spec.optional
            warn("missing value for `", field, "` field of OI-FITS extension ",
                 extname)
            nerrs += 1
        end
    end
    if nerrs > 0
        error("some mandatory fields are missing in OI-FITS extension ",
              extname)
    end
    return _DATABLOCKS[extname](contents)
end

warn(args...) = message(stderr, "WARNING", :yellow, args...)
inform(args...) = message(stderr, "INFO", :blue, args...)
@noinline function message(io::IO, ident::String, color::Symbol, args...)
    printstyled(io, color; bold=true, color=color)
    printstyled(io, " ", args...; bold=false, color=color)
end


###################################################
# MANAGING THE DATABLOCK CONTAINER (THE "MASTER") #
###################################################

# Letter case and trailing spaces are insignificant according to FITS
# conventions.
fixname(name::AbstractString) = uppercase(rstrip(name))

# OIDataBlock and OIMaster can be used as iterators.
Base.iterate(db::OIDataBlock) = iterate(contents(db))
Base.iterate(db::OIDataBlock, state) = iterate(contents(db), state)

Base.iterate(mst::OIMaster) = iterate(mst.all)
Base.iterate(mst::OIMaster, state) = iterate(mst.all, state)

function select(master::OIMaster, args::AbstractString...)
    datablocks = Array{OIDataBlock}(undef, 0)
    for db in master
        if get_extname(db) ∈ args
            push!(datablocks, db)
        end
    end
    return datablocks
end

"""

Assuming `mst` is an instance of `OIMaster`, then:

    get_target(mst)

yields the `OITarget` data-block of `mst` if any, `nothing` otherwise.

Assuming `tgt` is an instance of `OITarget`, then:

    get_target(tgt)

yields the "TARGET" column of `tgt` which is an array of target names.

"""
get_target(master::OIMaster) = getfield(update!(master), :tgt)


"""

Assuming `mst` is an instance of `OIMaster`, then:

    get_array(mst, arrname)

yields the `OIArray` data-block of `mst` whose name is `arrname` if any,
`nothing` otherwise.

Assuming `db` is an instance of a sub-type of `OIDataBlock`, then:

    get_array(db)

yields corresponding instance of `OIArray` if any, `nothing` otherwise.

"""
function get_array(master::OIMaster, arrname::AbstractString)
    get(get_array(update!(master)), fixname(arrname), nothing)
end
get_array(db::OIDataBlock) = nothing
get_array(db::OIArray) = db
get_array(obj::Union{OIMaster,OIVis,OIVis2,OIT3}) = getfield(obj, :arr)

"""

Assuming `mst` is an instance of `OIMaster`, then:

    get_instrument(mst, insname)

yields the `OIWavelength` data-block of `mst` whose name is `insname` if any,
`nothing` otherwise.

Assuming `db` is an instance of a sub-type of `OIDataBlock`, then:

    get_instrument(db)

yields corresponding instance of `OIWavelength` if any, `nothing` otherwise.

"""
function get_instrument(master::OIMaster, insname::AbstractString)
    get(get_instrument(update!(master)), fixname(insname), nothing)
end
get_instrument(db::OIDataBlock) = nothing
get_instrument(db::OIWavelength) = db
get_instrument(obj::Union{OIMaster,OIVis,OIVis2,OIT3}) = getfield(obj, :ins)

"""

Assuming `mst` is an instance of `OIMaster`, then:

    get_targets(mst)

yields the names of the targets defined in `mst`.

"""
function get_targets(master::OIMaster)
    tgt = get_target(master)
    return tgt === nothing ? Array{String}(undef, 0) : get_target(tgt)
end

"""

Assuming `mst` is an instance of `OIMaster`, then:

    get_arrays(mst)

yields the names of the interferometric arrays defined in `mst`.

"""
get_arrays(master::OIMaster) = collect(keys(update!(master).arr))

"""

Assuming `mst` is an instance of `OIMaster`, then:

    get_instruments(mst)

yields the names of the instruments defined in `mst`.

"""
get_instruments(master::OIMaster) = collect(keys(update!(master).ins))

function new_master(datablocks::OIDataBlock...)
    master = OIMaster()
    for db in datablocks
        attach!(master, db)
    end
    return update!(master)
end

function new_master(datablocks::Array{OIDataBlock})
    master = OIMaster()
    for db in datablocks
        attach!(master, db)
    end
    return update!(master)
end

function attach!(master::OIMaster, db::OIDataBlock)
    is_attached(db) && error("data-block already attached")
    if isa(db, OITarget)
        if master.tgt != nothing
            error("only one OI_TARGET data-block can be attached")
        end
        master.tgt = db
    elseif isa(db, OIWavelength)
        insname = fixname(db[:insname])
        haskey(master.ins, insname) && error("master already have an ",
                                             "OI_WAVELENGTH data-block with ",
                                             "INSNAME=\"", insname, "\"")
        master.ins[insname] = db
    elseif isa(db, OIArray)
        arrname = fixname(db[:arrname])
        haskey(master.arr, arrname) && error("master already have an ",
                                             "OI_ARRAY data-block with ",
                                             "ARRNAME=\"", arrname, "\"")
        master.arr[arrname] = db
    elseif isa(db, OICorrelation)
        corrname = fixname(db[:corrname])
        haskey(master.corr, corrname) && error("master already have an ",
                                               "OI_CORR data-block with ",
                                               "CORRNAME=\"", corrname, "\"")
        master.corr[corrname] = db
    end
    push!(master.all, db)
    master.update_pending = true
    setfield!(db, :attached, true)
    nothing
end

function update!(master::OIMaster)
    if master.update_pending
        if master.tgt === nothing
            error("missing mandatory OI_TARGET data-block")
        end
        for db in master.all
            if (haskey(db, :insname)
                && ! isa(db, Union{OIWavelength,OIPolarization}))
                insname = fixname(db[:insname])
                ins = get(master.ins, insname, nothing)
                ins === nothing && error("OI_WAVELENGTH data-block with ",
                                         "INSNAME=\"", insname,
                                         "\" not found in master")
                setfield!(db, :ins, ins)
            end
            if haskey(db, :arrname) && ! isa(db, OIArray)
                arrname = fixname(db[:arrname])
                arr = get(master.arr, arrname, nothing)
                arr === nothing && warn("OI_ARRAY data-block with ARRNAME=\"",
                                        arrname, "\" not found in master")
                setfield!(db, :arr, arr)
            end
            if haskey(db, :corrname) && ! isa(db, OICorrelation)
                corrname = fixname(db[:corrname])
                corr = get(master.corr, corrname, nothing)
                corr === nothing && warn("OI_CORR data-block with ",
                                         "CORRNAME=\"", corrname,
                                         "\" not found in master")
                setfield!(db, :corr, corr)
            end
        end
        master.update_pending = false
    end
    return master
end

"""

### Clone a data-block

This method clones an existing data-block.  The array data are shared between
the clones but not the links (owner, target, instrument, etc.).  Only the
fields defined by OI-FITS standard are cloned.  This method is intended when
a data-block from a given `OIMaster` instance is to be attached to another
`OIMaster` instance.

"""
function clone(db::OIDataBlock)
    (name, revn, defn) = get_descr(db)
    data = Dict{Symbol,Any}()
    for (key, val) in contents(db)
        if haskey(defn.spec, key)
            data[key] = val
        end
    end
    return build_datablock(name, revn, data)
end


"""

### Select data for a given target

The method `select_target` selects a subset of data corresponding to a given
target.   The general syntax is:

    out = select_target(inp, tgt)

where `inp` is the input data (can be an instance of `OIMaster` or of any
`OIDataBlock` sub-types), `tgt` is the target number or name.

The result `out` may share part of its contents with the input data `inp`.

The result may be `nothing` if the input contains no data for the given target.

"""
select_target(db::OIDataBlock, target::Integer) = clone(db)

function select_target(db::OITarget, target::Integer)
    (name, revn, defn) = get_descr(db)
    k = findfirst(id -> id == target, get_target_id(db))
    k == 0 && return
    data = Dict{Symbol,Any}()
    for (key, val) in contents(db)
        spec = get(defn.spec, key, nothing)
        spec != nothing || continue
        if spec.keyword
            data[key] = db[key]
        else
            data[key] = db[key][k:k]
        end
    end
    return build_datablock(name, revn, data)
end

function select_target(db::OIData, target::Integer)
    (name, revn, defn) = get_descr(db)
    target_id = get_target_id(db)
    sel = find(id -> id == target, target_id)
    length(sel) > 0 || return
    data = Dict{Symbol,Any}()
    cpy = (length(sel) == length(target_id)) # just copy?
    for (key, val) in contents(db)
        spec = get(defn.spec, key, nothing)
        spec != nothing || continue
        if cpy || spec.keyword
            data[key] = db[key]
        else
            # Copy a sub-array corresponding to the selection.  (The target is
            # specified for each last index.)
            src = db[key]
            @assert(size(src)[end] == length(target_id))
            rank = ndims(src)
            dims = ntuple(i -> i == rank ? length(sel) : size(src, i), rank)
            dst = Array{eltype(src)}(undef, dims)
            data[key] = dst
            if rank == 1
                for j in 1:length(sel)
                    dst[j] = src[sel[j]]
                end
            elseif rank == 2
                for j in 1:length(sel)
                    dst[:,j] = src[:,sel[j]]
                end
            else
                error("unexpected rank $rank")
            end
        end
    end
    return build_datablock(name, revn, data)
end

function select_target(master::OIMaster, target::Integer)
    result = OIMaster()
    for db in master
        sel = select_target(db, target)
        sel != nothing && attach!(result, sel)
    end
    return update!(result)
end

function select_target(master::OIMaster, target::AbstractString)
    db = get_target(master)
    if db != nothing
        k = findfirst(name -> name == target, get_target(db))
        k != 0 && return select_target(master, get_target_id(db)[k])
    end
    error("target name not found")
end

"""

### Select data at given wavelengths

The method `select_wavelength` selects a subset of data on the basis of their
wavelength.   The general syntax is:

    out = select_wavelength(inp, sel)

where `inp` is the input data (can be an instance of `OIMaster` or of any
`OIDataBlock` sub-types), `sel` is a predicate function which takes a
wavelength (in meters) as argument and returns true if this wavelength is to be
selected and false otherwise.

An alternative is:

    out = select_wavelength(inp, wmin, wmax)

to select wavelengths `w` such that `wmin ≤ w ≤ wmax`.  The wavelength
bounds are in meters.

The result `out` may share part of its contents with the input data `inp`.

The result may be `nothing` if the input contains no data at selected
wavelengths.

"""
function select_wavelength(inp::Union{OIMaster,OIDataBlock},
                           wavemin::Real, wavemax::Real)
    wmin = convert(Cdouble, wavemin)
    wmax = convert(Cdouble, wavemax)
    select_wavelength(inp, w -> wmin ≤ w ≤ wmax)
end

select_wavelength(db::OIDataBlock, selector::Function) = clone(db)

function select_wavelength(db::Union{OIWavelength,OIVis,OIVis2,OIT3,OISpectrum},
                           selector::Function)
    (name, revn, defn) = get_descr(db)
    wave = get_eff_wave(db)
    sel = find(selector, wave)
    length(sel) > 0 || return
    data = Dict{Symbol,Any}()
    cpy = (length(sel) == length(wave)) # just copy?
    iswave = (typeof(db) == OIWavelength)
    for (key, val) in contents(db)
        spec = get(defn.spec, key, nothing)
        spec != nothing || continue
        if cpy || spec.keyword || (spec.multiplier >= 0 && ! iswave)
            data[key] = db[key]
        else
            # Copy a sub-array corresponding to the selection.  (The wavelength
            # corresponds to the first index.)
            src = db[key]
            @assert(size(src, 1) == length(wave))
            rank = ndims(src)
            dims = ntuple(i -> i == 1 ? length(sel) : size(src, i), rank)
            dst = Array{eltype(src)}(undef, dims)
            data[key] = dst
            if rank == 1
                for j in 1:length(sel)
                    dst[j] = src[sel[j]]
                end
            elseif rank == 2
                for j in 1:length(sel)
                    dst[j,:] = src[sel[j],:]
                end
            else
                error("unexpected rank $rank")
            end
        end
    end
    return build_datablock(name, revn, data)
end

function select_wavelength(master::OIMaster, selector::Function)
    result = OIMaster()
    for db in master
        sel = select_wavelength(db, selector)
        sel != nothing && attach!(result, sel)
    end
    return update!(result)
end
