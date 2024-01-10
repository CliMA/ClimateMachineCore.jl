abstract type AbstractReader end

# these need to be here for to make the eval work
# TODO: figure out a better way to represent types
using MPI
using StaticArrays
using ..ClimaCore
using ..Domains: IntervalDomain, SphereDomain
using ..Meshes:
    Meshes,
    NormalizedBilinearMap,
    IntervalMesh,
    RectilinearMesh,
    EquiangularCubedSphere
using ..Topologies: Topologies, IntervalTopology
using ..Spaces:
    Spaces,
    SpectralElementSpace1D,
    SpectralElementSpace2D,
    CenterExtrudedFiniteDifferenceSpace,
    FaceExtrudedFiniteDifferenceSpace,
    ExtrudedFiniteDifferenceSpace
using ..Fields: Field, FieldVector
import ..Geometry:
    Geometry,
    XPoint,
    YPoint,
    ZPoint,
    Covariant1Vector,
    Covariant12Vector,
    Covariant3Vector
using ..DataLayouts

function mpiprint(str, comms_ctx)
    if comms_ctx isa ClimaComms.SingletonCommsContext
        print(str * "\n")
    else
        print(" " * string(MPI.Comm_rank(comms_ctx.mpicomm)) * " " * str * "\n")
    end
    flush(stdout)
end

"""
    HDF5Reader(filename::AbstractString[, context::ClimaComms.AbstractCommsContext])

An `AbstractReader` for reading from HDF5 files created by [`HDF5Writer`](@ref).
The reader object contains an internal cache of domains, meshes, topologies and
spaces that are read so that duplicate objects are not created.

The optional `context` can be used for reading distributed fields: in this case,
the `MPICommsContext` used passed as an argument: resulting `Field`s will be
distributed using this context. As with [`HDF5Writer`](@ref), this requires a
HDF5 library with MPI support.

# Interface
- [`read_domain`](@ref)
- [`read_mesh`](@ref)
- [`read_topology`](@ref)
- [`read_space`](@ref)
- [`read_field`](@ref)

# Usage

```julia
reader = InputOutput.HDF5Reader(filename)
Y = read_field(reader, "Y")
Y.c |> propertynames
Y.f |> propertynames
ρ_field = read_field(reader, "Y.c.ρ")
w_field = read_field(reader, "Y.f.w")
close(reader)
```

To explore the contents of the `reader`, use either
```julia
julia> reader |> propertynames
```
e.g, to explore the components of the `space`,
```julia
julia> reader.space_cache
Dict{Any, Any} with 3 entries:
  "center_extruded_finite_difference_space" => CenterExtrudedFiniteDifferenceSpace:…
  "horizontal_space"                        => SpectralElementSpace2D:…
  "face_extruded_finite_difference_space"   => FaceExtrudedFiniteDifferenceSpace:…
```

Once "unpacked" as shown above, `ClimaCorePlots` or `ClimaCoreMakie` can be used to visualise
fields. `ClimaCoreTempestRemap` supports interpolation onto user-specified grids if necessary.

"""
struct HDF5Reader{C <: ClimaComms.AbstractCommsContext}
    file::HDF5.File
    context::C
    file_version::VersionNumber
    domain_cache::Dict{Any, Any}
    mesh_cache::Dict{Any, Any}
    topology_cache::Dict{Any, Any}
    grid_cache::Dict{Any, Any}
end

@deprecate HDF5Reader(filename::AbstractString) HDF5Reader(
    filename,
    ClimaComms.SingletonCommsContext(),
)

function HDF5Reader(
    filename::AbstractString,
    context::ClimaComms.AbstractCommsContext,
)
    if context isa ClimaComms.SingletonCommsContext
        file = h5open(filename, "r")
    else
        file = h5open(filename, "r", context.mpicomm)
    end
    if !haskey(attrs(file), "ClimaCore version")
        error("Not a ClimaCore HDF5 file")
    end
    file_version = VersionNumber(attrs(file)["ClimaCore version"])
    current_version = VERSION
    if file_version > current_version
        @warn "$filename was written using a newer version of ClimaCore than is currently loaded" file_version current_version
    end
    return HDF5Reader(
        file,
        context,
        file_version,
        Dict(),
        Dict(),
        Dict(),
        Dict(),
    )
end


function Base.close(hdfreader::HDF5Reader)
    empty!(hdfreader.domain_cache)
    empty!(hdfreader.mesh_cache)
    empty!(hdfreader.topology_cache)
    empty!(hdfreader.grid_cache)
    close(hdfreader.file)
    return nothing
end

function _scan_coord_type(coordstring::AbstractString)
    coordstring == "XPoint" && return Geometry.XPoint
    coordstring == "YPoint" && return Geometry.YPoint
    coordstring == "ZPoint" && return Geometry.ZPoint
    error("Invalid coord type $coordstring")
end

function _scan_quadrature_style(quadraturestring::AbstractString, npts)
    @assert quadraturestring ∈ ("GLL", "GL", "Uniform", "ClosedUniform")
    quadraturestring == "GLL" && return Quadratures.GLL{npts}()
    quadraturestring == "GL" && return Quadratures.GL{npts}()
    quadraturestring == "Uniform" && return Quadratures.Uniform{npts}()
    return Quadratures.ClosedUniform{npts}()
end

function _scan_data_layout(layoutstring::AbstractString)
    @assert layoutstring ∈ ("IJFH", "IJF", "IFH", "IF", "VIJFH", "VIFH")
    layoutstring == "IJFH" && return DataLayouts.IJFH
    layoutstring == "IJF" && return DataLayouts.IJF
    layoutstring == "IFH" && return DataLayouts.IFH
    layoutstring == "IF" && return DataLayouts.IF
    layoutstring == "VIJFH" && return DataLayouts.VIJFH
    return DataLayouts.VIFH
end

"""
    matrix_to_cartesianindices(elemorder_matrix)

Converts the `elemorder_matrix` to cartesian indices.
"""
function matrix_to_cartesianindices(elemorder_matrix)
    m, ndims = size(elemorder_matrix)
    dims = [maximum(elemorder_matrix[:, dim]) for dim in 1:ndims]
    elemorder = Vector{CartesianIndex{ndims}}(undef, m)
    for i in 1:m
        elemorder[i] = CartesianIndex(elemorder_matrix[i, :]...)
    end
    return reshape(elemorder, dims...)
end


"""
    read_domain(reader::AbstractReader, name)

Reads a domain named `name` from `reader`. Domain objects are cached in the
reader to avoid creating duplicate objects.
"""
function read_domain(reader, name)
    Base.get!(reader.domain_cache, name) do
        read_domain_new(reader, name)
    end
end

function read_domain_new(reader::HDF5Reader, name::AbstractString)
    mpiprint("start read_domain_new", reader.context)
    group = reader.file["domains/$name"]
    type = attrs(group)["type"]
    if type == "IntervalDomain"
        mpiprint("read_domain_new branch 1 IntervalDomain", reader.context)
        CT = _scan_coord_type(attrs(group)["coord_type"])
        mpiprint("after _scan_coord_type", reader.context)
        coord_min = CT(attrs(group)["coord_min"])
        coord_max = CT(attrs(group)["coord_max"])
        mpiprint("after coords", reader.context)
        if haskey(attributes(group), "boundary_names")
            boundary_names =
                tuple(map(Symbol, attrs(group)["boundary_names"])...)
            return Domains.IntervalDomain(coord_min, coord_max; boundary_names)
        else
            return Domains.IntervalDomain(coord_min, coord_max; periodic = true)
        end
    elseif type == "SphereDomain"
        mpiprint("read_domain_new branch 2 SphereDomain", reader.context)
        radius = attrs(group)["radius"]
        mpiprint("before read_domain_new return", reader.context)
        return Domains.SphereDomain(radius)
    else
        error("Unsupported domain type $type")
    end
end


"""
    read_mesh(reader::AbstractReader, name)

Reads a mesh named `name` from `reader`, or from the reader cache if it has
already been read.
"""
function read_mesh(reader, name)
    Base.get!(reader.mesh_cache, name) do
        read_mesh_new(reader, name)
    end
end

function read_mesh_new(reader::HDF5Reader, name::AbstractString)
    mpiprint("start read_mesh_new", reader.context)
    group = reader.file["meshes/$name"]
    type = attrs(group)["type"]
    if type == "IntervalMesh"
        mpiprint("read_mesh_new branch 1 IntervalMesh", reader.context)
        domain = read_domain(reader, attrs(group)["domain"])
        nelements = attrs(group)["nelements"]
        faces_type = attrs(group)["faces_type"]
        if faces_type == "Range"
            mpiprint("read_mesh_new branch 1.1 Range", reader.context)
            return Meshes.IntervalMesh(
                domain,
                Meshes.Uniform(),
                nelems = nelements,
            )
        else
            mpiprint("read_mesh_new branch 1.2", reader.context)
            CT = Domains.coordinate_type(domain)
            faces = [CT(coords) for coords in attrs(group)["faces"]]
            return Meshes.IntervalMesh(domain, faces)
        end
    elseif type == "RectilinearMesh"
        mpiprint("read_mesh_new branch 2 RectilinearMesh", reader.context)
        intervalmesh1 = read_mesh(reader, attrs(group)["intervalmesh1"])
        intervalmesh2 = read_mesh(reader, attrs(group)["intervalmesh2"])
        return Meshes.RectilinearMesh(intervalmesh1, intervalmesh2)
    elseif type == "EquiangularCubedSphere"
        mpiprint("read_mesh_new branch 2 EquiangularCubedSphere", reader.context)
        domain = read_domain(reader, attrs(group)["domain"])
        mpiprint("after read_domain", reader.context)
        localelementmap =
            attrs(group)["localelementmap"] == "NormalizedBilinearMap" ?
            Meshes.NormalizedBilinearMap() : Meshes.IntrinsicMap()
        ne = attrs(group)["ne"]
        mpiprint("before read_mesh_new return", reader.context)
        return Meshes.EquiangularCubedSphere(domain, ne, localelementmap)
    end
end

"""
    read_topology(reader::AbstractReader, name)

Reads a topology named `name` from `reader`, or from the reader cache if it has
already been read.
"""
function read_topology(reader, name)
    Base.get!(reader.topology_cache, name) do
        read_topology_new(reader, name)
    end
end


function read_topology_new(reader::HDF5Reader, name::AbstractString)
    mpiprint("debug branch read_topology_new", reader.context)
    group = reader.file["topologies/$name"]
    type = attrs(group)["type"]
    if type == "IntervalTopology"
        mpiprint("branch 1 IntervalTopology", reader.context)
        mesh = read_mesh(reader, attrs(group)["mesh"])
        # context =
        #     ClimaComms.SingletonCommsContext(ClimaComms.device(reader.context))
        # return Topologies.IntervalTopology(context, mesh)
        # return Topologies.IntervalTopology(
        #     ClimaComms.SingletonCommsContext(ClimaComms.device()),
        #     mesh,
        # )
        mpiprint("before IntervalTopology call", reader.context)
        return Topologies.IntervalTopology(mesh)
    elseif type == "Topology2D"
        mpiprint("branch 2 Topology2D", reader.context)
        mesh = read_mesh(reader, attrs(group)["mesh"])
        mpiprint("branch 2 after read_mesh", reader.context)
        if haskey(group, "elemorder")
            mpiprint("branch 2 if", reader.context)
            elemorder_matrix = HDF5.read(group, "elemorder")
            if reader.file_version < v"0.10.9"
                mpiprint("branch 2 OLDER file version", reader.context)
                elemorder = collect(
                    reinterpret(
                        reshape,
                        CartesianIndex{size(elemorder_matrix, 2)},
                        elemorder_matrix',
                    ),
                )
            else
                mpiprint("branch 2 NEWER file version", reader.context)
                elemorder = collect(
                    reinterpret(
                        reshape,
                        CartesianIndex{size(elemorder_matrix, 1)},
                        elemorder_matrix,
                    ),
                )
            end
        else
            mpiprint("branch 3 else", reader.context)
            elemorder = Meshes.elements(mesh)
        end
        mpiprint("read_topology_new before return", reader.context)
        return Topologies.Topology2D(reader.context, mesh, elemorder)
    else
        error("Unsupported type $type")
    end
end



"""
    read_grid(reader::AbstractReader, name)

Reads a space named `name` from `reader`, or from the reader cache if it has
already been read.
"""
function read_grid(reader, name)
    Base.get!(reader.grid_cache, name) do
        read_grid_new(reader, name)
    end
end

function read_grid_new(reader, name)
    mpiprint("start read_grid_new", reader.context)
    group = reader.file["grids/$name"]
    type = attrs(group)["type"]
    if type in ("SpectralElementGrid1D", "SpectralElementGrid2D")
        npts = attrs(group)["quadrature_num_points"]
        quadrature_style =
            _scan_quadrature_style(attrs(group)["quadrature_type"], npts)
        mpiprint("branch 1 before read_topology", reader.context)
        topology = read_topology(reader, attrs(group)["topology"])
        mpiprint("after read_topology", reader.context)
        if type == "SpectralElementGrid1D"
            mpiprint("read_grid_new SpectralElementGrid1D", reader.context)
            return Grids.SpectralElementGrid1D(topology, quadrature_style)
        else
            mpiprint("read_grid_new SpectralElementGrid1D", reader.context)
            return Grids.SpectralElementGrid2D(topology, quadrature_style)
        end
    elseif type == "FiniteDifferenceGrid"
        mpiprint("branch 2 before read_topology", reader.context)
        topology = read_topology(reader, attrs(group)["topology"])
        return Grids.FiniteDifferenceGrid(topology)
    elseif type == "ExtrudedFiniteDifferenceGrid"
        mpiprint("branch 3 before read_grid", reader.context)
        vertical_grid = read_grid(reader, attrs(group)["vertical_grid"])
        horizontal_grid = read_grid(reader, attrs(group)["horizontal_grid"])
        hypsography_type = get(attrs(group), "hypsography_type", "Flat")
        if hypsography_type == "Flat"
            hypsography = Grids.Flat()
        elseif hypsography_type == "LinearAdaption"
            hypsography = Hypsography.LinearAdaption(
                read_field(reader, attrs(group)["hypsography_surface"]),
            )
        else
            error("Unsupported hypsography type $hypsography_type")
        end
        return Grids.ExtrudedFiniteDifferenceGrid(
            horizontal_grid,
            vertical_grid,
            hypsography,
        )
    elseif type == "LevelGrid"
        full_grid = read_grid(reader, attrs(group)["full_grid"])
        if haskey(attrs(group), "level")
            level = attrs(group)["level"]
        else
            level = attrs(group)["level_half"] + half
        end
        return Grids.LevelGrid(full_grid, level)
    else
        error("Unsupported grid type $type")
    end
end

"""
    read_space(reader::AbstractReader, name)

Reads a space named `name` from `reader`, or from the reader cache if it has
already been read.
"""
function read_space(reader, name)
    Base.get!(reader.space_cache, name) do
        read_space_new(reader, name)
    end
end

function read_space_new(reader, name)
    group = reader.file["spaces/$name"]
    type = attrs(group)["type"]
    if type in ("SpectralElementSpace1D", "SpectralElementSpace2D")
        npts = attrs(group)["quadrature_num_points"]
        quadrature_style =
            _scan_quadrature_style(attrs(group)["quadrature_type"], npts)
        topology = read_topology(reader, attrs(group)["topology"])
        if type == "SpectralElementSpace1D"
            Spaces.SpectralElementSpace1D(topology, quadrature_style)
        else
            Spaces.SpectralElementSpace2D(topology, quadrature_style)
        end
    elseif type == "ExtrudedFiniteDifferenceSpace"
        if attrs(group)["staggering"] == "CellFace"
            center_space = read_space(reader, attrs(group)["center_space"])
            return Spaces.FaceExtrudedFiniteDifferenceSpace(center_space)
        else
            vertical_topology =
                read_topology(reader, attrs(group)["vertical_topology"])
            horizontal_space =
                read_space(reader, attrs(group)["horizontal_space"])
            hypsography_type = get(attrs(group), "hypsography_type", "Flat")
            if hypsography_type == "Flat"
                hypsography = Grids.Flat()
            elseif hypsography_type == "LinearAdaption"
                hypsography = Hypsography.LinearAdaption(
                    read_field(reader, attrs(group)["hypsography_surface"]),
                )
            else
                error("Unsupported hypsography type $hypsography_type")
            end
            return Spaces.ExtrudedFiniteDifferenceSpace(
                horizontal_space,
                Spaces.CenterFiniteDifferenceSpace(vertical_topology),
                hypsography,
            )
        end
    else
        error("Unsupported space type $type")
    end
end

"""
    read_field(reader, name)

Reads a `Field` or `FieldVector` named `name` from `reader`. Fields are _not_
cached, so that reading the same field multiple times will create multiple
distinct objects.
"""
function read_field(reader::HDF5Reader, name::AbstractString)
    mpiprint("start read_field", reader.context)

    obj = reader.file["fields/$name"]
    type = attrs(obj)["type"]
    if type == "Field"
        mpiprint("field type", reader.context)
        if haskey(attrs(obj), "grid")
            grid = read_grid(reader, attrs(obj)["grid"])
            staggering = get(attrs(obj), "staggering", nothing)
            mpiprint("before staggering", reader.context)
            if staggering == "CellCenter"
                staggering = Grids.CellCenter()
            elseif staggering == "CellFace"
                staggering = Grids.CellFace()
            end
            mpiprint("after staggering", reader.context)
            space = Spaces.space(grid, staggering)
        else
            mpiprint("before read_space", reader.context)
            space = read_space(reader, attrs(obj)["space"])
        end
        mpiprint("after grid if/else", reader.context)
        topology = Spaces.topology(space)
        ArrayType = ClimaComms.array_type(topology)
        if topology isa Topologies.Topology2D
            mpiprint("topology isa Topology2D", reader.context)
            nd = ndims(obj)
            localidx = ntuple(d -> d < nd ? (:) : topology.local_elem_gidx, nd)
            data = ArrayType(obj[localidx...])
        else
            mpiprint("topology is not Topology2D", reader.context)
            data = ArrayType(read(obj))
        end
        data_layout = attrs(obj)["data_layout"]
        Nij = size(data, findfirst("I", data_layout)[1])
        mpiprint("before _scan_data_layout", reader.context)
        DataLayout = _scan_data_layout(data_layout)
        ElType = eval(Meta.parse(attrs(obj)["value_type"]))
        values = DataLayout{ElType, Nij}(data)
        mpiprint("before field return", reader.context)
        return Fields.Field(values, space)
    elseif type == "FieldVector"
        mpiprint("fieldveg type", reader.context)
        Fields.FieldVector(;
            [
                Symbol(sub) => read_field(reader, "$name/$sub") for
                sub in keys(obj)
            ]...,
        )
    else
        error("Unsupported type $type")
    end
end

"""
    read_attributes(reader::AbstractReader, name::AbstractString, data::Dict)

Return the attributes associated to the object at `name` in the given HDF5 file.
"""
read_attributes(reader::HDF5Reader, name::AbstractString) =
    h5readattr(reader.file.filename, name)
