using Oceananigans: AbstractModel, AbstractOutputWriter, AbstractDiagnostic

using Oceananigans.Architectures: AbstractArchitecture, CPU
using Oceananigans.Advection: CenteredSecondOrder
using Oceananigans.BoundaryConditions: regularize_field_boundary_conditions

using Oceananigans.BoundaryConditions: UVelocityBoundaryConditions,
                                       VVelocityBoundaryConditions,
                                       TracerBoundaryConditions

using Oceananigans.Fields: Field, tracernames, TracerFields, XFaceField, YFaceField, CenterField
using Oceananigans.Forcings: model_forcing
using Oceananigans.Grids: with_halo, topology
using Oceananigans.TimeSteppers: Clock, TimeStepper
using Oceananigans.TurbulenceClosures: ν₀, κ₀, with_tracers, DiffusivityFields, IsotropicDiffusivity
using Oceananigans.Utils: inflate_halo_size, tupleit

function ShallowWaterTendencyFields(arch, grid, tracer_names)

    uh = XFaceField(arch, grid, UVelocityBoundaryConditions(grid))
    vh = YFaceField(arch, grid, VVelocityBoundaryConditions(grid))
    h  = CenterField(arch,  grid, TracerBoundaryConditions(grid))
    tracers = TracerFields(tracer_names, arch, grid)

    return merge((uh=uh, vh=vh, h=h), tracers)
end

function ShallowWaterSolutionFields(arch, grid, bcs)

    uh_bcs = :uh ∈ keys(bcs) ? bcs.uh : UVelocityBoundaryConditions(grid)
    vh_bcs = :vh ∈ keys(bcs) ? bcs.vh : VVelocityBoundaryConditions(grid)
    h_bcs  = :h  ∈ keys(bcs) ? bcs.h  : TracerBoundaryConditions(grid)

    uh = XFaceField(arch, grid, uh_bcs)
    vh = YFaceField(arch, grid, vh_bcs)
    h = CenterField(arch, grid, h_bcs)

    return (uh=uh, vh=vh, h=h)
end

struct ShallowWaterModel{G, A<:AbstractArchitecture, T, V, R, F, E, B, Q, C, K, TS} <: AbstractModel{TS}

                          grid :: G         # Grid of physical points on which `Model` is solved
                  architecture :: A         # Computer `Architecture` on which `Model` is run
                         clock :: Clock{T}  # Tracks iteration number and simulation time of `Model`
    gravitational_acceleration :: T         # Gravitational acceleration, full, or reduced
                     advection :: V         # Advection scheme for velocities _and_ tracers
                      coriolis :: R         # Set of parameters for the background rotation rate of `Model`
                       forcing :: F         # Container for forcing functions defined by the user
                       closure :: E         # Diffusive 'turbulence closure' for all model fields
                    bathymetry :: B         # Bathymetry/Topography for the model
                      solution :: Q         # Container for transports `uh`, `vh`, and height `h`
                       tracers :: C         # Container for tracer fields
                 diffusivities :: K         # Container for turbulent diffusivities
                   timestepper :: TS        # Object containing timestepper fields and parameters

end

function ShallowWaterModel(;
                           grid,
                           gravitational_acceleration,
  architecture::AbstractArchitecture = CPU(),
                               clock = Clock{eltype(grid)}(0, 0, 1),
                           advection = UpwindBiasedFifthOrder(),
                            coriolis = nothing,
                 forcing::NamedTuple = NamedTuple(),
                             closure = nothing,
                          bathymetry = nothing,
                            solution = nothing,
                             tracers = (),
                       diffusivities = nothing,
     boundary_conditions::NamedTuple = NamedTuple(),
                 timestepper::Symbol = :RungeKutta3)

    #FJP: in the proposed formulation we don't have an Nz when we define ShallowWaterModel so this goes
    #grid.Nz == 1 || throw(ArgumentError("ShallowWaterModel must be constructed with Nz=1!"))

    tracers = tupleit(tracers) # supports tracers=:c keyword argument (for example)

    #FJP: if we we decide to keep this redefintion of inflate_halo_size then we will need to change:
    #         incompressible_mode.jl and hydrostatic_free_surface_model.jl
    
    Hx, Hy, Hz = inflate_halo_size(grid.Hx, grid.Hy, grid.Hz, topology(grid), advection)
    grid = with_halo((Hx, Hy, Hz), grid)

    model_field_names = (:uh, :vh, :h, tracers...)
    boundary_conditions = regularize_field_boundary_conditions(boundary_conditions, grid, model_field_names)

    solution = ShallowWaterSolutionFields(architecture, grid, boundary_conditions)
    tracers  = TracerFields(tracers, architecture, grid, boundary_conditions)
    diffusivities = DiffusivityFields(diffusivities, architecture, grid,
                                      tracernames(tracers), boundary_conditions, closure)

    # Instantiate timestepper if not already instantiated
    timestepper = TimeStepper(timestepper, architecture, grid, tracernames(tracers);
                              Gⁿ = ShallowWaterTendencyFields(architecture, grid, tracernames(tracers)),
                              G⁻ = ShallowWaterTendencyFields(architecture, grid, tracernames(tracers)))

    # Regularize forcing and closure for model tracer and velocity fields.
    model_fields = merge(solution, tracers)
    forcing = model_forcing(model_fields; forcing...)
    closure = with_tracers(tracernames(tracers), closure)

    return ShallowWaterModel(grid,
                             architecture,
                             clock,
                             eltype(grid)(gravitational_acceleration),
                             advection,
                             coriolis,
                             forcing,
                             closure,
                             bathymetry,
                             solution,
                             tracers,
                             diffusivities,
                             timestepper)
end
