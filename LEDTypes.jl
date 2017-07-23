using Colors, Interpolations
import Base.getindex, Base.length, Base.setindex!, Base.push!, Base.endof
import FixedPointNumbers

abstract type AbstractChannel end
abstract type AbstractController end


# Make some types so that I don't go insane
mutable struct LEDStrip{T,N}
    name::String
    channel::T
    controller::N
    startAddr::Int
    endAddr::Int
    idxRange::UnitRange
    function LEDStrip{T,N}(name::String, channel::T, controller::N, startAddr::Int, endAddr::Int) where {T<:AbstractChannel, N<:AbstractController}
        x = new(name, channel, controller, startAddr, endAddr, startAddr:endAddr)
        push!(channel, x)
        push!(controller, x)
        return x
    end
end

length(strip::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= length(strip.idxRange)
getindex(strip::LEDStrip{T, N}, i::Any) where {T<:AbstractChannel, N<:AbstractController}= getindex(getindex(strip.controller, strip.idxRange), i)
eachindex(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= 1:length(s)
endof(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController} = length(s)
function setindex!(strip::LEDStrip{T, N}, val::Any, idx::Any) where {T<:AbstractChannel, N<:AbstractController}
    setindex!(strip.controller, setindex!(strip.controller[strip.idxRange], val, idx), strip.idxRange)
end


mutable struct LEDController <: AbstractController
    addrs::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}
    strips::Array{LEDStrip}
    location::Tuple{IPAddr, Int}
    raw_data::Array{UInt8, 1}
    function LEDController(sz::Int, location::Tuple{IPAddr, Int})
        return new(Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}(sz), Array{LEDStrip, 1}(0), location, Array{UInt8, 1}(sz*3))
    end
end

length(controller::LEDController) = length(controller.addrs)
push!(controller::LEDController, val::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= push!(controller.strips, val)
getindex(controller::LEDController, idx::Any) = getindex(controller.addrs, idx)
eachindex(c::LEDController) = 1:length(c)
endof(c::LEDController) = length(c)
function setindex!(controller::LEDController, val::Any, idx::Any)
    setindex!(controller.addrs, val, idx)
end


mutable struct LEDChannel <: AbstractChannel
    map::Array{Tuple{Float64, Float64, LEDStrip}}
    itp::Interpolations.BSplineInterpolation
    virtualmem::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}},1}
    precision::Float64
    function LEDChannel(map::Array{Tuple{Float64, Float64, LEDStrip},1}, precision::Int64)
        init_map = map
        init_virtualmem = zeros(precision)
        init_precision = precision
        init_itp = interpolate(init_virtualmem, BSpline(Quadratic(Linear())), OnCell())
        return new(init_map, init_itp, init_virtualmem, init_precision)
    end
end

LEDChannel(map::Array{Tuple{Float64, Float64, LEDStrip},1}) = LEDChannel(map, 100)
LEDChannel(precision::Int64) = LEDChannel(Array{Tuple{Float64, Float64, LEDStrip}}(0), precision)
LEDChannel() = LEDChannel(Array{Tuple{Float64, Float64, LEDStrip}}(0), 100)
getindex(channel::LEDChannel, idx) = getindex(channel.virtualmem, idx)
setindex!(channel::LEDChannel, val, idx) = setindex!(channel.virtualmem, val, idx)
length(channel::LEDChannel) = length(channel.virtualmem)
eachindex(channel::LEDChannel) = 1:length(channel)
endof(c::LEDChannel) = length(c)

function update!(channel::LEDChannel)
    channel.itp = interpolate(channel.virtualmem, BSpline(Quadratic(Linear())), OnCell())
    for m in channel.map
        indicies = linspace(m[1]/100*precision, m[2]/100*precision, length(m[3]))
        Threads.@threads for i in eachindex(m[3])
            m[3][i] = itp[indicies[i]]
        end
    end
end

function update!(f::Function, channel::LEDChannel)
    for m in channel.map
        indicies = linspace(m[1]/100*precision, m[2]/100*precision, length(m[3]))
        m[3] .= f.(indices)
    end
end


function push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractController}
    return push!(channel, val, 0.0, 100.0)
end

function push!(channel::LEDChannel, val::LEDStrip{T,N}, startLoc::Real, endLoc::Real) where {T<:AbstractChannel, N<:AbstractController}
    (startLoc >= 0.0 && startLoc <= 100.0) || error("Strips must be assigned to locations between 0.0 and 100.0 on a channel")
    (endLoc >= 0.0 && endLoc <= 100.0) || error("Strips must be assigned to locations between 0.0 and 100.0 on a channel")
    if !(val in getindex.(channel.map, 3))
        return push!(channel.map, (val, startLoc, endLoc))
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
end


function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end