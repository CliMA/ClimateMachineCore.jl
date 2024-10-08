#=
julia --check-bounds=yes --project
julia -g2 --check-bounds=yes --project
julia --project
using Revise; include(joinpath("test", "Fields", "benchmark_field_multi_broadcast_fusion.jl"))
=#
include("utils_field_multi_broadcast_fusion.jl")

@testset "FusedMultiBroadcast VIJHF and VF" begin
    FT = Float64
    device = ClimaComms.device()
    space = TU.CenterExtrudedFiniteDifferenceSpace(
        FT;
        zelem = 63,
        helem = 30,
        Nq = 4,
        context = ClimaComms.context(device),
    )
    X = Fields.FieldVector(
        x1 = rand_field(FT, space),
        x2 = rand_field(FT, space),
        x3 = rand_field(FT, space),
    )
    Y = Fields.FieldVector(
        y1 = rand_field(FT, space),
        y2 = rand_field(FT, space),
        y3 = rand_field(FT, space),
    )
    test_kernel!(; fused!, unfused!, X, Y)
    test_kernel!(; fused! = fused_bycolumn!, unfused! = unfused_bycolumn!, X, Y)

    benchmark_kernel!(unfused!, X, Y, device)
    benchmark_kernel!(fused!, X, Y, device)

    benchmark_kernel!(unfused_bycolumn!, X, Y, device)
    benchmark_kernel!(fused_bycolumn!, X, Y, device)
    nothing
end

@testset "FusedMultiBroadcast VIHF" begin
    FT = Float64
    device = ClimaComms.device()
    # Add GPU test when https://github.com/CliMA/ClimaCore.jl/issues/1383 is fixed
    if device isa ClimaComms.CPUSingleThreaded
        space = CenterExtrudedFiniteDifferenceSpaceLineHSpace(
            FT;
            zelem = 63,
            helem = 30,
            Nq = 4,
            context = ClimaComms.context(device),
        )
        X = Fields.FieldVector(
            x1 = rand_field(FT, space),
            x2 = rand_field(FT, space),
            x3 = rand_field(FT, space),
        )
        Y = Fields.FieldVector(
            y1 = rand_field(FT, space),
            y2 = rand_field(FT, space),
            y3 = rand_field(FT, space),
        )
        test_kernel!(; fused!, unfused!, X, Y)
        test_kernel!(;
            fused! = fused_bycolumn!,
            unfused! = unfused_bycolumn!,
            X,
            Y,
        )

        benchmark_kernel!(unfused!, X, Y, device)
        benchmark_kernel!(fused!, X, Y, device)

        benchmark_kernel!(unfused_bycolumn!, X, Y, device)
        benchmark_kernel!(fused_bycolumn!, X, Y, device)
        nothing
    end
end

@testset "FusedMultiBroadcast IJHF" begin
    FT = Float64
    device = ClimaComms.device()
    sem_space =
        TU.SphereSpectralElementSpace(FT; context = ClimaComms.context(device))
    IJHF_data() = Fields.Field(FT, sem_space)
    X = Fields.FieldVector(;
        x1 = IJHF_data(),
        x2 = IJHF_data(),
        x3 = IJHF_data(),
    )
    Y = Fields.FieldVector(;
        y1 = IJHF_data(),
        y2 = IJHF_data(),
        y3 = IJHF_data(),
    )
    test_kernel!(; fused!, unfused!, X, Y)
    benchmark_kernel!(unfused!, X, Y, device)
    benchmark_kernel!(fused!, X, Y, device)
    nothing
end

@testset "FusedMultiBroadcast VF" begin
    FT = Float64
    device = ClimaComms.device()
    colspace = TU.ColumnCenterFiniteDifferenceSpace(
        FT;
        zelem = 63,
        context = ClimaComms.context(device),
    )
    VF_data() = Fields.Field(FT, colspace)

    X = Fields.FieldVector(; x1 = VF_data(), x2 = VF_data(), x3 = VF_data())
    Y = Fields.FieldVector(; y1 = VF_data(), y2 = VF_data(), y3 = VF_data())
    test_kernel!(; fused!, unfused!, X, Y)
    benchmark_kernel!(unfused!, X, Y, device)
    benchmark_kernel!(fused!, X, Y, device)
    nothing
end

@testset "FusedMultiBroadcast DataF" begin
    FT = Float64
    device = ClimaComms.device()
    ArrayType = ClimaComms.array_type(device)
    DataF_data() = DataF{FT}(ArrayType(ones(FT, 1)))
    X = Fields.FieldVector(;
        x1 = DataF_data(),
        x2 = DataF_data(),
        x3 = DataF_data(),
    )
    Y = Fields.FieldVector(;
        y1 = DataF_data(),
        y2 = DataF_data(),
        y3 = DataF_data(),
    )
    test_kernel!(; fused!, unfused!, X, Y)
    benchmark_kernel!(unfused!, X, Y, device)
    benchmark_kernel!(fused!, X, Y, device)
    nothing
end
