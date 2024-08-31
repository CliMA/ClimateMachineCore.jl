import ClimaCore.DataLayouts:
    to_non_extruded_broadcasted, has_uniform_datalayouts
DataLayouts._device_dispatch(x::CUDA.CuArray) = ToCUDA()

# function Base.copyto!(
#     dest::VIJFH{S, Nv, Nij, Nh},
#     bc::DataLayouts.BroadcastedUnionVIJFH{S, Nv, Nij, Nh},
#     ::ToCUDA,
# ) where {S, Nv, Nij, Nh}
#     if Nv > 0 && Nh > 0
#         us = DataLayouts.UniversalSize(dest)
#         n = prod(DataLayouts.universal_size(us))
#         if has_uniform_datalayouts(bc)
#             bc′ = to_non_extruded_broadcasted(bc)
#             auto_launch!(knl_copyto_linear!, (dest, bc′, us), n; auto = true)
#         else
#             auto_launch!(knl_copyto_cart!, (dest, bc, us), n; auto = true)
#         end
#     end
#     return dest
# end
function knl_copyto_linear!(dest::AbstractData, bc, us)
    @inbounds begin
        tidx = thread_index()
        if tidx ≤ get_N(us)
            dest[tidx] = bc[tidx]
        end
    end
    return nothing
end

function knl_copyto_linear!(dest::DataF{S},bc,us) where {S}
    @inbounds begin
        tidx = thread_index()
        if tidx ≤ get_N(us)
            dest[] = bc[tidx]
        end
    end
    return nothing
end

function knl_copyto_flat!(dest::AbstractData, bc, us)
    @inbounds begin
        tidx = thread_index()
        if tidx ≤ get_N(us)
            n = size(dest)
            I = kernel_indexes(tidx, n)
            dest[I] = bc[I]
        end
    end
    return nothing
end

function knl_copyto_flat!(
    dest::DataF{S},
    bc::DataLayouts.BroadcastedUnionDataF{S},
    us,
) where {S}
    @inbounds begin
        tidx = thread_index()
        if tidx ≤ get_N(us)
            n = size(dest)
            # I = kernel_indexes(tidx, n)
            dest[] = bc[]
        end
    end
    return nothing
end

function cuda_copyto!(dest::AbstractData, bc)
    (_, _, Nv, _, Nh) = DataLayouts.universal_size(dest)
    us = DataLayouts.UniversalSize(dest)
    n = prod(DataLayouts.universal_size(us))
    if Nv > 0 && Nh > 0
        if has_uniform_datalayouts(bc)
            bc′ = to_non_extruded_broadcasted(bc)
            auto_launch!(knl_copyto_linear!, (dest, bc′, us), n; auto = true)
        else
            auto_launch!(knl_copyto_flat!, (dest, bc, us), n; auto = true)
        end
    end
    return dest
end

#! format: off
Base.copyto!(dest::IJFH{S, Nij},          bc::DataLayouts.BroadcastedUnionIJFH{S, Nij, Nh}, ::ToCUDA) where {S, Nij, Nh} = cuda_copyto!(dest, bc)
Base.copyto!(dest::IFH{S, Ni, Nh},        bc::DataLayouts.BroadcastedUnionIFH{S, Ni, Nh}, ::ToCUDA) where {S, Ni, Nh} = cuda_copyto!(dest, bc)
Base.copyto!(dest::IJF{S, Nij},           bc::DataLayouts.BroadcastedUnionIJF{S, Nij}, ::ToCUDA) where {S, Nij} = cuda_copyto!(dest, bc)
Base.copyto!(dest::IF{S, Ni},             bc::DataLayouts.BroadcastedUnionIF{S, Ni}, ::ToCUDA) where {S, Ni} = cuda_copyto!(dest, bc)
Base.copyto!(dest::VIFH{S, Nv, Ni, Nh},   bc::DataLayouts.BroadcastedUnionVIFH{S, Nv, Ni, Nh}, ::ToCUDA) where {S, Nv, Ni, Nh} = cuda_copyto!(dest, bc)
Base.copyto!(dest::VIJFH{S, Nv, Nij, Nh}, bc::DataLayouts.BroadcastedUnionVIJFH{S, Nv, Nij, Nh}, ::ToCUDA) where {S, Nv, Nij, Nh} = cuda_copyto!(dest, bc)
Base.copyto!(dest::VF{S, Nv},             bc::DataLayouts.BroadcastedUnionVF{S, Nv}, ::ToCUDA) where {S, Nv} = cuda_copyto!(dest, bc)
Base.copyto!(dest::DataF{S},              bc::DataLayouts.BroadcastedUnionDataF{S}, ::ToCUDA) where {S} = cuda_copyto!(dest, bc)
#! format: on
