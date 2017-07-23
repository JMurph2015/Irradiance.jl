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

length{T<:AbstractChannel, N<:AbstractController}(strip::LEDStrip{T, N}) = length(strip.idxRange)
getindex{T<:AbstractChannel, N<:AbstractController}(strip::LEDStrip{T, N}, i::Any) = getindex(getindex(strip.controller, strip.idxRange), i)
endof{T<:AbstractChannel, N<:AbstractController}(s::LEDStrip{T, N}) = length(s)
function setindex!{T<:AbstractChannel, N<:AbstractController}(strip::LEDStrip{T, N}, val::Any, idx::Any)
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
push!{T<:AbstractChannel, N<:AbstractController}(controller::LEDController, val::LEDStrip{T, N}) = push!(controller.strips, val)
getindex(controller::LEDController, idx::Any) = getindex(controller.addrs, idx)
endof(c::LEDController) = length(c)
function setindex!(controller::LEDController, val::Any, idx::Any)
    setindex!(controller.addrs, val, idx)
end


mutable struct LEDChannel <: AbstractChannel
    strips::Array{LEDStrip}
    map::Array{Tuple{Float64, Float64, LEDStrip}}
    LEDChannel() = new(Array{LEDStrip, 1}(0), Array{Tuple{Float64, Float64, LEDStrip}}(0))
end
function length(channel::LEDChannel)
    max = 0
    for m in map
        tmp = m[3]/(m[2]-m[1])
        if floor(Int, tmp) > max
            max = tmp
        end
    end
    return max
end
getindex(channel::LEDChannel, idx) = getindex(channel.strips[indmax(length.(channel.strips))], idx)
function length(channel::LEDChannel)
    max = 0
    for i in eachindex(channel.strips)
        if length(channel.strips[i]) > max
            max = length(channel.strips[i])
        end
    end
    return max
end
function push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractController}
    return push!(channel.strips, val)
end

function setindex!(channel::LEDChannel, val::Color, i::Any)

    homogeneous = true
    for i in 2:length(channel.strips)
        if length(channel.strips[i]) != length(channel.strips[i-1])
            homogeneous = false
            break
        end
    end
    if homogeneous
        for strip in channel.strips
            setindex!(strip, val, i)
        end
    else
        max_length = indmax(length.(channel.strips))
        setindex!(channel.strips[max_length], val, i)
        itp = interpolate(channel.strips[max_length][i], BSpline(Cubic(Line())), OnCell())
        for j in eachindex(channel.strips)
            if j != max_length
                setindex!(channel.strips, itp[linspace(1,length(itp),length(channel.strips[j]))], : )
            end
        end
    end
end
endof(c::LEDChannel) = length(c)

mutable struct LEDArray
    controllers::Array{LEDController}
    channels::Array{LEDChannel}
    strips::Array{LEDStrip}
end


function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end