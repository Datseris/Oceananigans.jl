"""
    FieldBoundaryConditions

An alias for `NamedTuple{(:x, :y, :z)}` that represents a set of three `CoordinateBoundaryCondition`s
applied to a field along x, y, and z.
"""
const FieldBoundaryConditions = NamedTuple{(:x, :y, :z)}

"""
    FieldBoundaryConditions(x, y, z)

Construct a `FieldBoundaryConditions` using a `CoordinateBoundaryCondition` for each of the
`x`, `y`, and `z` coordinates.
"""
FieldBoundaryConditions(x, y, z) = FieldBoundaryConditions((x, y, z))

default_tracer_bc(::Grids.Periodic) = PeriodicBC()
default_tracer_bc(::Bounded)  = NoFluxBC()
default_tracer_bc(::Flat)     = PeriodicBC()

# Right now it seems all defaults are the same except for no-normal
# flow velocity BCs (which are treated in default_bc below), but
# that might change in the future.
const default_velocity_bc = default_tracer_bc
const default_pressure_bc = default_tracer_bc
const default_diffusivity_bc = default_tracer_bc

function default_bc(grid, field, dim)
    top = topology(grid)[dim]

    # No normal flow velocity boundary conditions by default.
    top isa Bounded && field == :u && dim == 1 && return NoPenetrationBC()
    top isa Bounded && field == :v && dim == 2 && return NoPenetrationBC()
    top isa Bounded && field == :w && dim == 3 && return NoPenetrationBC()

    field in (:u, :v, :w) && (field = :velocity)
    default_field_bc = Symbol(:default_, field, :_bc)
    return @eval $default_field_bc(top)
end

function validate_bcs(topology, left_bc, right_bc, default_bc, left_name, right_name, dir)
    if topology isa Periodic && (left_bc != default_bc || right_bc != default_bc)
        e = "Cannot specify $left_name or $right_name boundary conditions with $topology topology in $dir-direction."
        throw(ArgumentError(e))
    end
    return true
end

function FieldBoundaryConditions(grid::AbstractGrid; field_type,
                                 west=default_bc(grid, field_type, 1), east=default_bc(grid, field_type, 1),
                                 south=default_bc(grid, field_type, 2), north=default_bc(grid, field_type, 2),
                                 bottom=default_bc(grid, field_type, 3), top=default_bc(grid, field_type, 3))
    TX, TY, TZ = topology(grid)
    validate_bcs(TX, west,   east, default_bc(grid, field_type, 1), :west,   :east, :x)
    validate_bcs(TY, south, north, default_bc(grid, field_type, 2), :south, :north, :y)
    validate_bcs(TZ, bottom,  top, default_bc(grid, field_type, 3), :bottom,  :top, :z)

    x = CoordinateBoundaryConditions(west, east)
    y = CoordinateBoundaryConditions(south, north)
    z = CoordinateBoundaryConditions(bottom, top)

    return FieldBoundaryConditions(x, y, z)
end

  UVelocityBoundaryConditions(grid; kwargs...) = FieldBoundaryConditions(grid, field_type=:u, kwargs...)
  VVelocityBoundaryConditions(grid; kwargs...) = FieldBoundaryConditions(grid, field_type=:v, kwargs...)
  WVelocityBoundaryConditions(grid; kwargs...) = FieldBoundaryConditions(grid, field_type=:w, kwargs...)
     TracerBoundaryConditions(grid; kwargs...) = FieldBoundaryConditions(grid, field_type=:tracer, kwargs...)
   PressureBoundaryConditions(grid; kwargs...) = FieldBoundaryConditions(grid, field_type=:pressure, kwargs...)
DiffusivityBoundaryConditions(grid; kwargs...) = FieldBoundaryConditions(grid, field_type=:diffusivity, kwargs...)
