################################################################################
#
#	CONCRETE TYPE
#
#   Bandstructure{path} <: AbstractBandstructure{path}
#   --> path is the path in k-space
#
#   FILE CONTAINS
#       - concrete struct definition
#        - interface implementation
#
################################################################################



mutable struct Bandstructure{P,H} <: AbstractBandstructure{P,H}

    # the path along which the band structure is calcualted
    path :: P
    # the hamiltonian
    h :: H

    # bands for each segment
    # bands[i] gives all bands of segment i
    # bands[i][j] gives all energy values for band j of segment i
    # bands[i][j][k] gives the energy value at kpoint index k of band j in segment i
    bands :: Array{Array{Array{Float64, 1}, 1}, 1}

end


# export the type
export Bandstructure



################################################################################
#
#	INTERFACING / ACCESSING BANDSTRUCTURES
#	(functions have to be overwritten by concrete types)
#
################################################################################

# obtaining the hamiltonian
function hamiltonian(
            bs :: Bandstructure{P,H}
        ) :: H where {RP, P<:AbstractReciprocalPath{RP}, L,UC,HB,H<:AbstractHamiltonian{L,UC,HB}}

    # return the field
    return bs.h
end

# export the function
export hamiltonian



# obtaining the path
function path(
            bs :: Bandstructure{P,H}
        ) :: P where {RP, P<:AbstractReciprocalPath{RP}, L,UC,HB,H<:AbstractHamiltonian{L,UC,HB}}

    # return the field
    return bs.path
end

# export the function
export path


# obtaining the energy values
function energies(
            bs :: Bandstructure{P,H}
        ) :: Array{Array{Array{Float64, 1}, 1}, 1} where {RP, P<:AbstractReciprocalPath{RP}, L,UC,HB,H<:AbstractHamiltonian{L,UC,HB}}

    # return the energy array
    return bs.bands
end


# recalculate the band structure (energy values)
function recalculate!(
            bs :: Bandstructure{P,H}
            ;
            resolution :: Union{Int64, Vector{Int64}} = 100
        ) where {D,RP<:AbstractReciprocalPoint{D}, P<:AbstractReciprocalPath{RP}, L,UC,HB,H<:AbstractHamiltonian{L,UC,HB}}

    # calculate the number of segments
    N_segments = length(path(bs)) - 1
    # parse the segment resolution
    seg_resolution = (zeros(Int64,N_segments).+1).*resolution
    if typeof(resolution)==Vector{Int64}
        if length(resolution) == N_segments
            seg_resolution = resolution
        else
            error("given resolution \"$(resolution)\" has not enough components ($(N_segments) needed)")
        end
    end

    # calculate number of bands
    N_bands = dim(hamiltonian(bs))


    # make a list of all k values
    k_values = Vector{Vector{Vector{Float64}}}(undef, N_segments)
    # make a list for all energy values
    e_values = Vector{Vector{Vector{Float64}}}(undef, N_segments)

    # fill all k values
    for i in 1:N_segments
        # fill the k values with points on the path segment
        k_values[i] = getPointsOnLine(path(bs)[i], path(bs)[i+1], seg_resolution[i])
        # fill energy values with zeros
        e_values[i] = Vector{Float64}[
            zeros(Float64, seg_resolution[i]) for j in 1:N_bands
        ]
    end


    # calculate the energy values
    for i in 1:N_segments
        for j in 1:seg_resolution[i]
            # use the k_value j of segment i
            k = k_values[i][j]
            # obtain the matrix
            m = matrixAtK(hamiltonian(bs), k)
            # diagonalize the matrix and save the eigenvalues
            m_eigenvalues = sort(eigvals(m))
            # put the eigenvalues into the bands
            for b in 1:N_bands
                e_values[i][b][j] = m_eigenvalues[b]
            end
        end
    end

    # set the energy values within band structure
    bs.bands = e_values

    # return nothing
    return nothing
end

# export the function
export recalculate!









# Convinience constructor function
function Bandstructure(
            path :: P,
            h    :: H
            ;
            recalculate :: Bool = true
        ) :: Bandstructure{P,H} where {D,RP<:AbstractReciprocalPoint{D}, P<:AbstractReciprocalPath{RP}, L,UC,HB,H<:AbstractHamiltonian{L,UC,HB}}

    # create a new object
    bs = Bandstructure{P,H}(path, h, Vector{Vector{Vector{Float64}}}(undef, length(path)-1))

    # recalculate the numerical energy values
    if recalculate
        recalculate!(bs)
    end

    # return the new object
    return bs
end
