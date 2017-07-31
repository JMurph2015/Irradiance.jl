using Colors, Interpolations
import Base.getindex, Base.length, Base.setindex!, Base.push!, Base.endof, Base.eachindex, Base.size
import FixedPointNumbers

abstract type AbstractChannel end
abstract type AbstractController end


# Make some types so that I don't go insane
mutable struct LEDStrip{T<:AbstractChannel, N<:AbstractController}
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
    map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}
    virtualmem::Array{UInt8,2}
    gpu_virtualmem::AFArray{Float32,2}
    precision::Float64
    function LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}, precision::Int64)
        init_virtualmem = zeros(UInt8, precision, 3)
        gpu_virtualmem = AFArray(convert(Array{Float32}, init_virtualmem))
        return new(map, init_virtualmem, gpu_virtualmem, precision)
    end
end

function getGPUIdxArray(strip::LEDStrip, x::Float64, y::Float64, precision::Real)
    return AFArray(convert.(Float32, collect(linspace(x/100*precision, y/100*precision, size(strip,1)))))
end

function LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64},1}, precision::Float64)
    new_map = map(map) do x
        return (x[1:3]..., getGPUIdxArray(x[1:3]..., precision))
    end
    return LEDChannel(new_map, precision)
end

LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}) = LEDChannel(map, 100)
LEDChannel(precision::Int64) = LEDChannel(Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(0), precision)
LEDChannel() = LEDChannel(Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(0), 100)
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
length(channel::LEDChannel) = length(channel.virtualmem)
size(channel::LEDChannel, x::Int) = size(channel.virtualmem, x)
size(channel::LEDChannel, x...) = size(channel.virtualmem, x...)
eachindex(channel::LEDChannel) = 1:length(channel)
endof(c::LEDChannel) = length(c)


function update!(f::Function, channel::LEDChannel)
    for m in channel.map
        indicies = linspace(m[2]/100*precision, m[3]/100*channel.precision, size(m[1],1))
        m[1] .= f.(indices)
    end
end

function update!(channel::LEDChannel)
    channel.gpu_virtualmem::AFArray{Float32,2} = AFArray(convert.(Float32, channel.virtualmem))
    for m in channel.map
        strip = m[1]
        # TODO cache idxs array in the LEDChannel object.
        for k in 1:size(strip, 2)
            strip.subArray[:,k] .= round.(UInt8, min.( max.( Array( approx1(channel.gpu_virtualmem[:,k], m[4], AF_INTERP_CUBIC_SPLINE, 0f0) ), 0.0f0), 255.0f0) )
            #setindex!(strip.subArray, tmp, 1:size(strip.subArray,1), k)
        end
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
        return push!(channel.map, (val, startLoc, endLoc, getGPUIdxArray(val, startLoc, endLoc, channel.precision)))
    else 
        return val
    end
end

function LEDChannel(channel1::LEDChannel, channel2::LEDChannel, offset::Float64)
    new_virtual_space = 100 + abs(offset)
    multiplier = 100/new_virtual_space
    old_map1 = deepcopy(channel1.map)
    old_map2 = deepcopy(channel2.map)
    new_map = Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(length(channel1.map)+length(channel2.map))
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
        @. new_map[i][2:3] = (new_map[i][2:3]+offset1)*multiplier
        new_map[i][4] = getGPUIdxArray()
    end
    for i in eachindex(channel2.map)
        new_map[i+indexed] = old_map2[i]
        @. new_map[i+indexed][2:3] = (new_map[i+indexed][2:3]+offset2)*multiplier
        new_map[i+indexed][4] = getGPUIdxArray(new_map[i+indexed][1:3]..., new_precision)
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
                tmp = (x[1], ((x[2:3]+root_offset)*multiplier)..., x[4])
                tmp[4] = getGPUIdxArray(tmp[1:3]..., new_precision)
                return tmp
            end
        else
            map!(maps[i]) do x
                tmp = (x[1], ((x[2:3]+offsets[i-1])*multiplier)..., x[4])
                tmp[4] = getGPUIdxArray(tmp[1:3]..., new_precision)
                return tmp
            end
        end
    end
    return LEDChannel(vcat(maps...), new_precision)
end

mutable struct LEDArray
    controllers::Array{LEDController,1}
    inactive_channels::Array{LEDChannel,1}
    channels::Array{LEDChannel,1}
    strips::Array{LEDStrip{LEDChannel, LEDController},1}
end


function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end