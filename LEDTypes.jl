using Colors, Interpolations
import Base.getindex, Base.length, Base.setindex!, Base.push!, Base.endof, Base.eachindex, Base.size
import FixedPointNumbers

abstract type AbstractChannel end
abstract type AbstractController end


# Make some types so that I don't go insane
mutable struct LEDStrip{T,N}
    name::String
    controller::N
    subArray::SubArray
    idxRange::UnitRange
    function LEDStrip{T,N}(name::String, channel::T, controller::N, startAddr::Int, endAddr::Int) where {T<:AbstractChannel, N<:AbstractController}
        x = new(name, controller, view(controller.addrs, startAddr:endAddr, :), startAddr:endAddr)
        push!(channel, x)
        push!(controller, x)
        return x
    end
end

length(strip::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= length(strip.subArray)
getindex(strip::LEDStrip{T, N}, i::Any...) where {T<:AbstractChannel, N<:AbstractController}= getindex(strip.subArray, i...)
eachindex(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}=eachindex(s.subArray)
endof(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController} = endof(s.subArray)
size(s::LEDStrip{T, N}, vargs...) where {T<:AbstractChannel, N<:AbstractController} = size(s.subArray, vargs...)
setindex!(strip::LEDStrip{T, N}, val::Any, idx::Any...) where {T<:AbstractChannel, N<:AbstractController} = setindex!(strip.subArray, val, idx...)
function setindex!(strip::LEDStrip{T, N}, val::Union{Array{UInt8},UInt8}, idx::Union{AbstractArray, Number, Colon}) where {T<:AbstractChannel, N<:AbstractController}
    return setindex!(strip.subArray, val, idx)
end
function setindex!(strip::LEDStrip{T, N}, val::Union{Array{UInt8},UInt8}, idx::Union{AbstractArray, Number, Colon}, idx2::Union{AbstractArray, Number, Colon}) where {T<:AbstractChannel, N<:AbstractController}
    return setindex!(strip.subArray, val, idx, idx2)
end

mutable struct LEDController <: AbstractController
    addrs::Array{UInt8, 2}
    strips::Array{LEDStrip}
    location::Tuple{IPAddr, Int}
    raw_data::Array{UInt8, 1}
    function LEDController(sz::Int, location::Tuple{IPAddr, Int})
        return new(zeros(UInt8, sz, 3), Array{LEDStrip, 1}(0), location, Array{UInt8, 1}(sz*3))
    end
end

length(controller::LEDController) = length(controller.addrs)
push!(controller::LEDController, val::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= push!(controller.strips, val)
getindex(controller::LEDController, idx...) = getindex(controller.addrs, idx...)
eachindex(c::LEDController) = 1:length(c)
endof(c::LEDController) = length(c)
function setindex!(controller::LEDController, val::Any, idx::Any...)
    setindex!(controller.addrs, val, idx...)
end


mutable struct LEDChannel <: AbstractChannel
    map::Array{Tuple{Float64, Float64, LEDStrip}}
    itps::Array{Interpolations.BSplineInterpolation}
    virtualmem::Array{UInt8,2}
    precision::Float64
    function LEDChannel(map::Array{Tuple{Float64, Float64, LEDStrip},1}, precision::Int64)
        init_virtualmem = zeros(UInt8, precision, 3)
        init_itp = [interpolate(init_virtualmem[:,i], BSpline(Quadratic(Natural())), OnCell()) for i in 1:3]
        return new(map, init_itp, init_virtualmem, precision)
    end
end

LEDChannel(map::Array{Tuple{Float64, Float64, LEDStrip},1}) = LEDChannel(map, 100)
LEDChannel(precision::Int64) = LEDChannel(Array{Tuple{Float64, Float64, LEDStrip}}(0), precision)
LEDChannel() = LEDChannel(Array{Tuple{Float64, Float64, LEDStrip}}(0), 100)
getindex(channel::LEDChannel, idx::Any...) = getindex(channel.virtualmem, idx...)
setindex!(channel::LEDChannel, val, idx::Any...) = setindex!(channel.virtualmem, val, idx...)
function setindex!(channel::LEDChannel, val::ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}}, idx...) 
    channel.virtualmem[idx...,1] = val.r.i
    channel.virtualmem[idx...,2] = val.g.i
    channel.virtualmem[idx...,3] = val.b.i
    return channel.virtualmem[idx...,:]
end
function setindex!(channel::LEDChannel, val::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}}}, idx...)
    setindex!(channel, [getfield(v, f).i for v in val, f in fieldnames(eltype(val))], idx..., :)
end
length(channel::LEDChannel) = size(channel.virtualmem)[1]
eachindex(channel::LEDChannel) = 1:length(channel)
endof(c::LEDChannel) = length(c)

function safeFloat(x::AbstractFloat)
    if isnan(x) || x < 1e-3
        return 0
    elseif x > 255
        return 255
    else
        return abs(x)
    end
end



@inline function update!(f::Function, channel::LEDChannel)
    for m in channel.map
        indicies = linspace(m[1]/100*precision, m[2]/100*channel.precision, length(m[3]))
        m[3] .= f.(indices)
    end
end


function push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractController}
    return push!(channel, val, 0.0, 100.0)
end

function push!(channel::LEDChannel, val::LEDStrip{T,N}, startLoc::Real, endLoc::Real) where {T<:AbstractChannel, N<:AbstractController}
    if !((startLoc >= 0.0 && startLoc <= 100.0) && (endLoc >= 0.0 && endLoc <= 100.0))
        error("Strips must be assigned to locations between 0.0 and 100.0 on a channel")
    end
    if !(val in getindex.(channel.map, 3))
        return push!(channel.map, (startLoc, endLoc, val))
    else 
        return val
    end
end

function LEDChannel(channel1::LEDChannel, channel2::LEDChannel, offset::Float64)
    new_virtual_space = 100 + abs(offset)
    multiplier = 100/new_virtual_space
    old_map1 = deepcopy(channel1.map)
    old_map2 = deepcopy(channel2.map)
    new_map = Array{Tuple{Float64, Float64, LEDStrip}}(length(channel1.map)+length(channel2.map))
    new_precision = max(channel1.precision, channel2.precision)
    indexed = 0
    offset1 = 0
    offset2 = 0
    if offset < 0
        offset1 = abs(offset)
    else
        offset2 = abs(offset)
    end
    for i in eachindex(channel1.map)
        indexed = i
        new_map[i] = old_map1[i]
        @. new_map[i][1:2] = (new_map[i][1:2]+offset1)*multiplier
    end
    for i in eachindex(channel2.map)
        new_map[i+indexed] = old_map2[i]
        @. new_map[i+indexed][1:2] = (new_map[i+indexed][1:2]+offset2)*multiplier
    end
    return LEDChannel(new_map, new_precision)
end

function LEDChannel(channels::Array{LEDChannel}, offsets::Array{Float64})
    root_offset = 0
    max_offset = maximum(offsets)
    min_offset = minimum(offsets)
    if min_offset < 0
        root_offset -= min_offset
        offsets .-= min_offset
    end
    new_virtual_space = (max_offset+100) - min_offset
    multiplier = 100/new_virtual_space
    new_precision = maximum(getfield.(maps, :precision))
    maps = deepcopy.(getfield.(channels, :map))
    for i in eachindex(maps)
        if i == 1
            map!(maps[i]) do x
                return ((x[1:2]+root_offset)*multiplier, x[3])
            end
        else
            map!(maps[i]) do x
                return ((x[1:2]+offsets[i-1])*multiplier, x[3])
            end
        end
    end
    return LEDChannel(new_map, new_precision)
end

mutable struct LEDArray
    controllers::Array{LEDController}
    inactive_channels::Array{LEDChannel}
    channels::Array{LEDChannel}
    strips::Array{LEDStrip}
    state::Dict{String, Any}
end


function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end