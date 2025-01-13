var documenterSearchIndex = {"docs":
[{"location":"api/#API","page":"API","title":"API","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"CurrentModule = ClimaCore","category":"page"},{"location":"api/#DataLayouts","page":"API","title":"DataLayouts","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"DataLayouts\nDataLayouts.IJFH","category":"page"},{"location":"api/#ClimaCore.DataLayouts","page":"API","title":"ClimaCore.DataLayouts","text":"ClimaCore.DataLayouts\n\nNotation:\n\ni,j are horizontal node indices within an element\nk is the vertical node index within an element\nf is the field index\nv is the vertical element index in a stack\nh is the element stack index\n\nData layout is specified by the order in which they appear, e.g. IJKFVH indexes the underlying array as [i,j,k,f,v,h]\n\n\n\n\n\n","category":"module"},{"location":"api/#ClimaCore.DataLayouts.IJFH","page":"API","title":"ClimaCore.DataLayouts.IJFH","text":"IJFH{S,Nij}(ArrayType, nelements)\n\nConstruct an IJFH structure given the backing ArrayType, quadrature degrees of freedom Nij, and the number of mesh elements nelements.\n\n\n\n\n\n","category":"type"},{"location":"api/#Geometry","page":"API","title":"Geometry","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Geometry.Cartesian12Vector","category":"page"},{"location":"api/#Domains","page":"API","title":"Domains","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Domains.IntervalDomain\nDomains.RectangleDomain","category":"page"},{"location":"api/#ClimaCore.Domains.IntervalDomain","page":"API","title":"ClimaCore.Domains.IntervalDomain","text":"IntervalDomain(coord⁻, coord⁺; periodic=true)\nIntervalDomain(coord⁻, coord⁺; boundary_tags::Tuple{Symbol,Symbol})\n\nConstruct a IntervalDomain, the closed interval is given by coord⁻, coord⁺ coordinate arguments.\n\nEither a periodic or boundary_tags keyword argument is required.\n\n\n\n\n\nIntervalDomain(coords::ClosedInterval; boundary_tags::Tuple{Symbol,Symbol})\n\nConstruct a IntervalDomain, over the closed coordinate interval coords Because IntervalDomain does not support periodic boundary conditions, the boundary_tags keyword arugment must be supplied.\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Domains.RectangleDomain","page":"API","title":"ClimaCore.Domains.RectangleDomain","text":"RectangleDomain(x1::ClosedInterval, x2::ClosedInterval;\n    x1boundary::Tuple{Symbol,Symbol},\n    x2boundary::Tuple{Symbol,Symbol},\n    x1periodic = false,\n    x2periodic = false,\n)\n\nConstruct a RectangularDomain in the horizontal. If a given x1 or x2 boundary is not periodic, then x1boundary or x2boundary boundary tag keyword arguments must be supplied.\n\n\n\n\n\n","category":"type"},{"location":"api/#Meshes","page":"API","title":"Meshes","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Meshes.IntervalMesh\nMeshes.Uniform\nMeshes.ExponentialStretching\nMeshes.EquispacedRectangleMesh","category":"page"},{"location":"api/#ClimaCore.Meshes.IntervalMesh","page":"API","title":"ClimaCore.Meshes.IntervalMesh","text":"IntervalMesh <: AbstractMesh\n\nA 1D mesh on an IntervalDomain.\n\nConstuctors\n\nIntervalMesh(domain::IntervalDomain, faces::AbstractVector)\n\nConstruct a 1D mesh with face locations at faces.\n\nIntervalMesh(domain::IntervalDomain[, stetching=Uniform()]; nelems=)\n\nConstuct a 1D mesh on domain with nelems elements, using stretching. Possible values of stretching are:\n\nUniform()\nExponentialStretching(H)\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Meshes.Uniform","page":"API","title":"ClimaCore.Meshes.Uniform","text":"Uniform()\n\nUse uniformly-sized elements.\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Meshes.ExponentialStretching","page":"API","title":"ClimaCore.Meshes.ExponentialStretching","text":"ExponentialStretching(H)\n\nApply exponential stretching to the domain when constructing elements. H is the scale height (a typical atmospheric scale height H ≈ 7.5e3km).\n\nFor an interval z_0z_1, this makes the elements uniformally spaced in zeta, where\n\nzeta = frac1 - e^-etah1-e^-1h\n\nwhere eta = fracz - z_0z_1-z_0, and h = fracHz_1-z_0 is the non-dimensional scale height.\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Meshes.EquispacedRectangleMesh","page":"API","title":"ClimaCore.Meshes.EquispacedRectangleMesh","text":"EquispacedRectangleMesh(domain::RectangleDomain, n1::Integer, n2::Integer)\n\nA regular AbstractMesh of domain with n1 elements in dimension 1, and n2 in dimension 2.\n\n\n\n\n\n","category":"type"},{"location":"api/#Topologies","page":"API","title":"Topologies","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Topologies\nTopologies.IntervalTopology","category":"page"},{"location":"api/#ClimaCore.Topologies","page":"API","title":"ClimaCore.Topologies","text":"ClimaCore.Topologies\n\nObjects describing the horizontal connections between elements.\n\nAll elements are quadrilaterals, using the face and vertex numbering convention from p4est:\n\n          4\n      3-------4\n ^    |       |\n |  1 |       | 2\nx2    |       |\n      1-------2\n          3\n        x1-->\n\n\n\n\n\n","category":"module"},{"location":"api/#ClimaCore.Topologies.IntervalTopology","page":"API","title":"ClimaCore.Topologies.IntervalTopology","text":"IntervalTopology(mesh::IntervalMesh)\n\nA sequential topology on an IntervalMesh.\n\n\n\n\n\n","category":"type"},{"location":"api/#Spaces","page":"API","title":"Spaces","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"Spaces\nSpaces.Quadratures.degrees_of_freedom\nSpaces.Quadratures.GL\nSpaces.Quadratures.Uniform\nSpaces.Quadratures.quadrature_points\nSpaces.Quadratures.GLL\nSpaces.Quadratures.polynomial_degree\nSpaces.Quadratures.QuadratureStyle","category":"page"},{"location":"api/#ClimaCore.Spaces","page":"API","title":"ClimaCore.Spaces","text":"Meshes\n\ndomain\ntopology\ncoordinates\nmetric terms (inverse partial derivatives)\nquadrature rules and weights\n\nReferences / notes\n\nceed\nQA\n\n\n\n\n\n","category":"module"},{"location":"api/#ClimaCore.Spaces.Quadratures.degrees_of_freedom","page":"API","title":"ClimaCore.Spaces.Quadratures.degrees_of_freedom","text":"degrees_of_freedom(QuadratureStyle) -> Int\n\nReturns the degreesoffreedom of the QuadratureStyle concrete type\n\n\n\n\n\n","category":"function"},{"location":"api/#ClimaCore.Spaces.Quadratures.GL","page":"API","title":"ClimaCore.Spaces.Quadratures.GL","text":"GL{Nq}()\n\nGauss-Legendre quadrature using Nq quadrature points.\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Spaces.Quadratures.Uniform","page":"API","title":"ClimaCore.Spaces.Quadratures.Uniform","text":"Uniform{Nq}()\n\nUniformly-spaced quadrature.\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Spaces.Quadratures.quadrature_points","page":"API","title":"ClimaCore.Spaces.Quadratures.quadrature_points","text":"points, weights = quadrature_points(::Type{FT}, quadrature_style)\n\nThe points and weights of the quadrature rule in floating point type FT.\n\n\n\n\n\n","category":"function"},{"location":"api/#ClimaCore.Spaces.Quadratures.GLL","page":"API","title":"ClimaCore.Spaces.Quadratures.GLL","text":"GLL{Nq}()\n\nGauss-Legendre-Lobatto quadrature using Nq quadrature points.\n\n\n\n\n\n","category":"type"},{"location":"api/#ClimaCore.Spaces.Quadratures.polynomial_degree","page":"API","title":"ClimaCore.Spaces.Quadratures.polynomial_degree","text":"polynomial_degree(QuadratureStyle) -> Int\n\nReturns the polynomial degree of the QuadratureStyle concrete type\n\n\n\n\n\n","category":"function"},{"location":"api/#ClimaCore.Spaces.Quadratures.QuadratureStyle","page":"API","title":"ClimaCore.Spaces.Quadratures.QuadratureStyle","text":"QuadratureStyle\n\nQuadrature style supertype. See sub-types:\n\nGLL\nGL\nUniform\n\n\n\n\n\n","category":"type"},{"location":"api/#RecursiveApply","page":"API","title":"RecursiveApply","text":"","category":"section"},{"location":"api/","page":"API","title":"API","text":"RecursiveApply","category":"page"},{"location":"api/#ClimaCore.RecursiveApply","page":"API","title":"ClimaCore.RecursiveApply","text":"RecursiveApply\n\nThis module contains operators to recurse over nested Tuples or NamedTuples.\n\nTo extend to another type T, define RecursiveApply.rmap(fn, args::T...)\n\n\n\n\n\n","category":"module"},{"location":"operators/#Operators","page":"Operators","title":"Operators","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"CurrentModule = ClimaCore.Operators","category":"page"},{"location":"operators/#Finite-difference-operators","page":"Operators","title":"Finite difference operators","text":"","category":"section"},{"location":"operators/#Interpolation-operators","page":"Operators","title":"Interpolation operators","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"InterpolateC2F\nInterpolateF2C\nUpwindBiasedProductC2F\nLeftBiasedC2F\nRightBiasedC2F","category":"page"},{"location":"operators/#ClimaCore.Operators.InterpolateC2F","page":"Operators","title":"ClimaCore.Operators.InterpolateC2F","text":"I = InterpolateC2F(;boundaries..)\nI.(x)\n\nInterpolate a center-valued field x to faces, using the stencil\n\nI(x)i = frac12 (xi+tfrac12 + xi-tfrac12)\n\nSupported boundary conditions are:\n\nSetValue(x₀): set the value at the boundary face to be x₀. On the left boundary the stencil is\n\nI(x)tfrac12 = x₀\n\nSetGradient(v): set the value at the boundary such that the gradient is v. At the left boundary the stencil is\n\nI(x)tfrac12 = x1 - frac12 v³\n\nExtrapolate: use the closest interior point as the boundary value. At the left boundary the stencil is\n\nI(x)tfrac12 = x1\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.InterpolateF2C","page":"Operators","title":"ClimaCore.Operators.InterpolateF2C","text":"InterpolateF2C()\n\nInterpolate from face to center mesh. No boundary conditions are required (or supported).\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.UpwindBiasedProductC2F","page":"Operators","title":"ClimaCore.Operators.UpwindBiasedProductC2F","text":"U = UpwindBiasedProductC2F(;boundaries)\nU.(v, x)\n\nCompute the product of a face-valued vector field v and a center-valued field x at cell faces by upwinding x according to v\n\nU(vx)i = begincases\n  vi xi-tfrac12 quad v^3i  0 \n  vi xi+tfrac12 quad v^3i  0\n  endcases\n\nSupported boundary conditions are:\n\nSetValue(x₀): set the value of x to be x₀ on the boundary. On the left boundary the stencil is\nU(vx)tfrac12 = begincases\n  vtfrac12 x_0 quad v^3tfrac12  0 \n  vtfrac12 x1 quad v^3tfrac12  0\n  endcases\nExtrapolate(): set the value of x to be the same as the closest interior point. On the left boundary, the stencil is U(v,x)[\\tfrac{1}{2}] = U(v,x)[1 + \\tfrac{1}{2}]\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.LeftBiasedC2F","page":"Operators","title":"ClimaCore.Operators.LeftBiasedC2F","text":"L = LeftBiasedC2F(;boundaries)\nL.(x)\n\nInterpolate a left-value field to a face-valued field from the left.\n\nL(x)i = xi-tfrac12\n\nOnly the left boundary condition should be set. Currently supported is:\n\nSetValue(x₀): set the value to be x₀ on the boundary.\n\nL(x)tfrac12 = x_0\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.RightBiasedC2F","page":"Operators","title":"ClimaCore.Operators.RightBiasedC2F","text":"R = RightBiasedC2F(;boundaries)\nR.(x)\n\nInterpolate a center-valued field to a face-valued field from the right.\n\nR(x)i = xi+tfrac12\n\nOnly the right boundary condition should be set. Currently supported is:\n\nSetValue(x₀): set the value to be x₀ on the boundary.\n\nR(x)n+tfrac12 = x_0\n\n\n\n\n\n","category":"type"},{"location":"operators/#Advection-operators","page":"Operators","title":"Advection operators","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"AdvectionF2F\nAdvectionC2C","category":"page"},{"location":"operators/#ClimaCore.Operators.AdvectionF2F","page":"Operators","title":"ClimaCore.Operators.AdvectionF2F","text":"A = AdvectionF2F(;boundaries)\nA.(v, θ)\n\nVertical advection operator at cell faces, for a face-valued velocity field v and face-valued variables θ, approximating v^3 partial_3 theta.\n\nIt uses the following stencil\n\nA(vθ)i = frac12 (θi+1 - θi-1) v³i\n\nNo boundary conditions are currently supported. ```\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.AdvectionC2C","page":"Operators","title":"ClimaCore.Operators.AdvectionC2C","text":"A = AdvectionC2C(;boundaries)\nA.(v, θ)\n\nVertical advection operator at cell centers, for cell face velocity field v cell center variables θ, approximating v^3 partial_3 theta.\n\nIt uses the following stencil\n\nA(vθ)i = frac12  (θi+1 - θi) v³i+tfrac12 + (θi - θi-1)v³i-tfrac12\n\nSupported boundary conditions:\n\nSetValue(θ₀): set the value of θ at the boundary face to be θ₀. At the lower boundary, this is:\n\nA(vθ)1 = frac12  (θ2 - θ1) v³1 + tfrac12 + (θ1 - θ₀)v³tfrac12\n\nExtrapolate: use the closest interior point as the boundary value. At the lower boundary, this is:\n\nA(vθ)1 = (θ2 - θ1) v³1 + tfrac12 \n\n\n\n\n\n","category":"type"},{"location":"operators/#Gradient-operators","page":"Operators","title":"Gradient operators","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"GradientF2C\nGradientC2F","category":"page"},{"location":"operators/#ClimaCore.Operators.GradientF2C","page":"Operators","title":"ClimaCore.Operators.GradientF2C","text":"G = GradientF2C(;boundaryname=boundarycondition...)\nG.(x)\n\nCompute the gradient of a face-valued field x, returning a center-valued Covariant3 vector field, using the stencil:\n\nG(x)i^3 = xi+tfrac12 - xi-tfrac12\n\nThe following boundary conditions are supported:\n\nby default, the value of x at the boundary face will be used.\nSetValue(x₀): calculate the gradient assuming the value at the boundary is x₀. For the left boundary, this becomes:\n\nG(x)1³ = x1+tfrac12 - x₀\n\nExtrapolate(): set the value at the center closest to the boundary\n\nto be the same as the neighbouring interior value. For the left boundary, this becomes:\n\nG(x)1³ = G(x)2³\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.GradientC2F","page":"Operators","title":"ClimaCore.Operators.GradientC2F","text":"G = GradientC2F(;boundaryname=boundarycondition...)\nG.(x)\n\nCompute the gradient of a center-valued field x, returning a face-valued Covariant3 vector field, using the stencil:\n\nG(x)i^3 = xi+tfrac12 - xi-tfrac12\n\nThe following boundary conditions are supported:\n\nSetValue(x₀): calculate the gradient assuming the value at the boundary is x₀. For the left boundary, this becomes:\nG(x)tfrac12³ = 2 (x1 - x₀)\nSetGradient(v₀): set the value of the gradient at the boundary to be v₀. For the left boundary, this becomes:\nG(x)tfrac12 = v₀\n\n\n\n\n\n","category":"type"},{"location":"operators/#Divergence-operators","page":"Operators","title":"Divergence operators","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"DivergenceF2C\nDivergenceC2F","category":"page"},{"location":"operators/#ClimaCore.Operators.DivergenceF2C","page":"Operators","title":"ClimaCore.Operators.DivergenceF2C","text":"D = DivergenceF2C(;boundaryname=boundarycondition...)\nD.(v)\n\nCompute the vertical contribution to the divergence of a face-valued field vector v, returning a center-valued scalar field, using the stencil\n\nD(v)i = (Jv³i+tfrac12 - Jv³i-tfrac12)  Ji\n\nwhere Jv³ is the Jacobian multiplied by the third contravariant component of v.\n\nThe following boundary conditions are supported:\n\nby default, the value of v at the boundary face will be used.\nSetValue(v₀): calculate the divergence assuming the value at the boundary is v₀. For the left boundary, this becomes:\n\nD(v)1 = (Jv³1+tfrac12 - Jv³₀)  Ji\n\nExtrapolate(): set the value at the center closest to the boundary to be the same as the neighbouring interior value. For the left boundary, this becomes:\n\nD(v)1³ = D(v)2³\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.DivergenceC2F","page":"Operators","title":"ClimaCore.Operators.DivergenceC2F","text":"D = DivergenceC2F(;boundaryname=boundarycondition...)\nD.(v)\n\nCompute the vertical contribution to the divergence of a center-valued field vector v, returning a face-valued scalar field, using the stencil\n\nD(v)i = (Jv³i+tfrac12 - Jv³i-tfrac12)  Ji\n\nwhere Jv³ is the Jacobian multiplied by the third contravariant component of v.\n\nThe following boundary conditions are supported:\n\nSetValue(v₀): calculate the divergence assuming the value at the  boundary is v₀. For the left boundary, this becomes:\nD(v)tfrac12 = frac12 (Jv³1 - Jv³₀)  Ji\nSetDivergence(x): set the value of the divergence at the boundary to be x.\nD(v)tfrac12 = x\n\n\n\n\n\n","category":"type"},{"location":"operators/#Other","page":"Operators","title":"Other","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"SetBoundaryOperator","category":"page"},{"location":"operators/#ClimaCore.Operators.SetBoundaryOperator","page":"Operators","title":"ClimaCore.Operators.SetBoundaryOperator","text":"SetBoundaryOperator(;boundaries...)\n\nThis operator only modifies the values at the boundary:\n\nSetValue(val): set the value to be val on the boundary.\n\n\n\n\n\n","category":"type"},{"location":"operators/#Finite-difference-boundary-conditions","page":"Operators","title":"Finite difference boundary conditions","text":"","category":"section"},{"location":"operators/","page":"Operators","title":"Operators","text":"SetValue\nSetGradient\nSetDivergence\nExtrapolate","category":"page"},{"location":"operators/#ClimaCore.Operators.SetValue","page":"Operators","title":"ClimaCore.Operators.SetValue","text":"SetValue(val)\n\nSet the value at the boundary to be val. In the case of gradient operators, this will set the input value from which the gradient is computed.\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.SetGradient","page":"Operators","title":"ClimaCore.Operators.SetGradient","text":"SetGradient(val)\n\nSet the gradient at the boundary to be val. In the case of gradient operators this will set the output value of the gradient.\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.SetDivergence","page":"Operators","title":"ClimaCore.Operators.SetDivergence","text":"SetDivergence(val)\n\nSet the divergence at the boundary to be val.\n\n\n\n\n\n","category":"type"},{"location":"operators/#ClimaCore.Operators.Extrapolate","page":"Operators","title":"ClimaCore.Operators.Extrapolate","text":"Extrapolate()\n\nSet the value at the boundary to be the same as the closest interior point.\n\n\n\n\n\n","category":"type"},{"location":"#ClimaCore.jl","page":"Home","title":"ClimaCore.jl","text":"","category":"section"}]
}
