using Colors, Interpolations
import Base: getindex, length, setindex!, push!, endof, eachindex, size
import FixedPointNumbers

"""
    AbstractChannel
    This channel abstraction allows me to use circular referential types between
    LEDStrip, LEDChannel, and LEDController because Julia doesn't yet support the 
    forward lookahead necessary to use this feature with only the child types.
"""
abstract type AbstractChannel end
"""
    AbstractController
    This does the same for Controllers that AbstractChannel did for Channels:
    it allows me to use typed circular references without forward lookahead.
"""
abstract type AbstractController end

"""
    LEDStrip{T<:AbstractChannel, N<:AbstractController}
    This encapsulates the core representation of a string of LED's.
    It contains a view (a reference to a section of an array) of a portion of
    its controller's memory addresses.  It also has a reference to its controller
    which happends to be circular.
"""
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

#=
    Array-like interface implementation (Julia doesn't have interfaces, 
    but there are collections of functions informally expected to exist)

    Most of these use some form of redirection to the inner view of the
    LEDController memory, but some have significant customizations on that.
=#
"Implements an override for the base length function"
length(strip::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= length(strip.subArray)

"Implements getting an index from the strip"
getindex(strip::LEDStrip{T, N}, i::Any...) where {T<:AbstractChannel, N<:AbstractController}= getindex(strip.subArray, i...)

"Implements the equivalent of Python's enumerate() instance method, returns a range of indices to iterate over"
eachindex(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}=eachindex(s.subArray)

"Implements a endof base function that returns the index of the last element"
endof(s::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController} = endof(s.subArray)

"Implements a size function for the LEDStrip, overrides the base function"
size(s::LEDStrip{T, N}, vargs...) where {T<:AbstractChannel, N<:AbstractController} = size(s.subArray, vargs...)

"Implements a function to set a particular index to a value for LEDStrip"
setindex!(strip::LEDStrip{T, N}, val::Any, idx::Any...) where {T<:AbstractChannel, N<:AbstractController} = setindex!(strip.subArray, val, idx...)

"Implements a vectorized form of setindex! to ensure maximum efficiency"
function setindex!(strip::LEDStrip{T, N}, val::Union{Array{UInt8},UInt8}, idx::Union{AbstractArray, Number, Colon}) where {T<:AbstractChannel, N<:AbstractController}
    return setindex!(strip.subArray, val, idx)
end

"""
    Implements another vectorized form to cover slightly different input 
    params, but still want to type specialize for maximum performance
"""
function setindex!(
                   strip::LEDStrip{T, N}, 
                   val::Union{Array{UInt8},UInt8}, 
                   idx::Union{AbstractArray, Number, Colon}, 
                   idx2::Union{AbstractArray, Number, Colon}
                  ) where {T<:AbstractChannel, N<:AbstractController}
    return setindex!(strip.subArray, val, idx, idx2)
end


"""
    LEDController <: AbstractController
    Contains the core representation of a LEDController for Irradiance.
    This class contains a large portion of the actual memory allocations for the system
    because it holds the memory for physical LED addresses.
"""
mutable struct LEDController <: AbstractController
    addrs::Array{UInt8, 2}
    strips::Array{LEDStrip}
    location::Tuple{IPAddr, Int}
    raw_data::Array{UInt8, 1}
    function LEDController(sz::Int, location::Tuple{IPAddr, Int})
        return new(zeros(UInt8, sz, 3), Array{LEDStrip, 1}(0), location, Array{UInt8, 1}(sz*3))
    end
end

#=
    The below section implements the Array-like interface for LEDControllers
    Once again, Julia doesn't have proper interfaces, but there are informal ones
    made of collections of methods
=#
"Implements the length function for LEDControllers"
length(controller::LEDController) = length(controller.addrs)

"Implements a push function for LEDControllers"
push!(controller::LEDController, val::LEDStrip{T, N}) where {T<:AbstractChannel, N<:AbstractController}= push!(controller.strips, val)

"Implments a getindex function for LEDControllers"
getindex(controller::LEDController, idx...) = getindex(controller.addrs, idx...)

"Implements the eachindex function for LEDControllers, returns a range of all valid indices for the LEDController"
eachindex(c::LEDController) = 1:length(c)

"Implements the endof function for LEDControllers, returns the last valid index of the LEDController"
endof(c::LEDController) = length(c)

"Implements the setindex! function for LEDControllers, sets an index of the LEDController to a given value"
function setindex!(controller::LEDController, val::Any, idx::Any...)
    setindex!(controller.addrs, val, idx...)
end

"""
    LEDChannel <: AbstractChannel
    This contains the implementation of a AbstractChannel for Irradiance. This is the main abstraction used
    in the rest of the program for a collection of LED's, all effects are applied to LEDChannels, not 
    LEDStrips, so that effects can be independent of the physical layout of the LED's
"""
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

"""
    getGPUIdxArray(strip::LEDStrip, x::Float64, y::Float64, precision::Real)::AFArray{Float32}
    
    This function gets the virtual memory addresses corresponding to the real indices of the given
    strip.  Essentially it returns an array of equal size to the input strip, but each element in the
    returned array is the index that the LED at that position should reference in the GPU.  Note that
    these can be Float32s, this is intentional, since this data is then fed into in interpolation algorithm
    that doesn't mind non-integer indices.
"""
function getGPUIdxArray(strip::LEDStrip, x::Float64, y::Float64, precision::Real)
    return AFArray(convert.(Float32, collect(linspace(x/100*precision, y/100*precision, size(strip,1)))))
end

"""
    LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64},1}, precision::Float64)

    This function is a convenience constructor for LEDChannel that initializes the map with 
    the given map and precision, then calls the default constructor.  Makes it substantially
    less onerous to create LEDChannels.
"""
function LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64},1}, precision::Float64)
    new_map = map(map) do x
        return (x[1:3]..., getGPUIdxArray(x[1:3]..., precision))
    end
    return LEDChannel(new_map, precision)
end

"LEDChannel overload to pass only the map and use a default precision"
LEDChannel(map::Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}) = LEDChannel(map, 100)

"LEDChannel overload to pass only the precision and use a default (empty) map"
LEDChannel(precision::Int64) = LEDChannel(Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(0), precision)

"LEDChannel overload to pass no arguments at all and use a default map, precision, etc."
LEDChannel() = LEDChannel(Array{Tuple{LEDStrip{LEDChannel, LEDController}, Float64, Float64, AFArray{Float32, 1}},1}(0), 100)

"Implements getindex for LEDChannel in a maximally generic way"
getindex(channel::LEDChannel, idx::Any...) = getindex(channel.virtualmem, idx...)

"Implements setindex! for LEDChannel in a very generic way"
setindex!(channel::LEDChannel, val, idx::Any...) = setindex!(channel.virtualmem, val, idx...)

"Implements setindex! for LEDChannel for a specialized value type of RGB for convenience in writing effects"
function setindex!(channel::LEDChannel, val::ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}}, idx...) 
    channel.virtualmem[idx...,1] = val.r.i
    channel.virtualmem[idx...,2] = val.g.i
    channel.virtualmem[idx...,3] = val.b.i
    return channel.virtualmem[idx...,:]
end

"Implements setindex! for LEDChannel for an array type of RGB for convenience and performance in writing effects"
function setindex!(channel::LEDChannel, val::Array{ColorTypes.RGB{FixedPointNumbers.Normed{UInt8,8}}}, idx...)
    setindex!(channel, [getfield(v, f).i for v in val, f in fieldnames(eltype(val))], idx..., :)
end

"Implements a length function for LEDChannels"
length(channel::LEDChannel) = length(channel.virtualmem)

"Implements a size function for LEDChannels, the most basic overload"
size(channel::LEDChannel, x::Int) = size(channel.virtualmem, x)

"""
    Implements a more generic size function for LEDChannels that catches more 
    at the expense of being less specialized (and thus slower, usually)
"""
size(channel::LEDChannel, x...) = size(channel.virtualmem, x...)

"""
    Implements an eachindex function for LEDChannels that allows easy iteration 
    by returning a range of valid indicies
"""
eachindex(channel::LEDChannel) = 1:length(channel)

"Implements the endof function for LEDChannel, returns the last valid index"
endof(c::LEDChannel) = length(c)

"""
    update!(f:Function, channel::LEDChannel)
    
    The update! functions are probably the most complicated and crucial things
    in this file!  This one takes a function of index (aka f(index)) that returns
    a color for each index called, then takes that function and evaluates it at 
    each mapped index of the channel's virtual memory and puts that result on the
    LEDStrip memory.  If unclear, see the other implementation of update! first
    then come back here.
"""
function update!(f::Function, channel::LEDChannel)
    for m in channel.map
        indicies = linspace(m[2]/100*precision, m[3]/100*channel.precision, size(m[1],1))
        m[1] .= f.(indices)
    end
end

"""
    update!(channel::LEDChannel)
    
    This function is the real bread and butter of the most common effect workflow.  
    It takes the current state of the virtual memory and via interpolation gets the value
    of the virtual memory at each LED position in the map.  So if there were 100 LED's mapped
    across 100% of the virtual memory, then this would evaluate the interpolation at each integer
    from 1-100 (since Julia is 1-indexed).  It can be substantially more complicated than that
    however, as there aren't particular restrictions on how LED's are mapped into LEDChannels
    except that they are contiguous and range within the bounds of the indices of the virtual
    memory.
"""
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

"""
    push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractChannel}

    This function adds a LEDStrip to the channel in the default map configuration (which is spanning the
    whole channel).
"""
function push!(channel::LEDChannel, val::LEDStrip{T,N}) where {T<:AbstractChannel, N<:AbstractController}
    return push!(channel, val, 0.0, 100.0)
end

"""
    push!(channel::LEDChannel, val::LEDStrip{T,N}, startLoc::Real, endLoc::Real) where {T<:AbstractChannel, N:<AbstractController}

    This function inserts a LEDStrip in the LEDChannel's mapping in an arbitrary start and end location. Used to build
    LEDChannels with more complicated mappings than just a bunch of (0.0,100.0) entries.
"""
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

"""
    LEDChannel(channel1::LEDChannel, channel2::LEDChannel, offset::Float64)

    Another constructor overload for LEDChannel that creates a new channel by merging
    two existing channels with a given offset.  So if you wanted to set them up to mirror
    each other, the offset would be zero, if you wanted to concatenate them, you would specify
    an offset of 100.0.  Negative offsets are also supported in case one wants to overlay the
    second channel to the left of the first channel.
"""
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

"""
    LEDChannel(channels::Array{LEDChannels}, offsets::Array{Float64})

    A constructor overload that creates a new channel from an array of channels
    and an array of offsets (the first of which is the offset of the first channel
    and so on).  The merging process normalizes everything against the channel offset
    furthest to the left (furthest negative, even!).
"""
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

"""
    LEDArray

    This structure bundles all of the important structures used by Irradiance
    into one large structure for convenience.
"""
mutable struct LEDArray
    controllers::Array{LEDController,1}
    inactive_channels::Array{LEDChannel,1}
    channels::Array{LEDChannel,1}
    strips::Array{LEDStrip{LEDChannel, LEDController},1}
end

"""
    LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)

    This is the concrete constructor for LEDStrip that uses the concrete implementations of LEDController
    and LEDChannel.
"""
function LEDStrip(name::String, channel::LEDChannel, controller::LEDController, startAddr::Int, endAddr::Int)
    return LEDStrip{LEDChannel, LEDController}(name, channel, controller, startAddr, endAddr)
end
