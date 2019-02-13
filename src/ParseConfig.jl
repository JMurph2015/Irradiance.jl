using JSON
using Sockets

function parse_config(filename::String)
    json_data = Dict()
    open(filename, "r") do f
        json_data = JSON.parse(f)
    end
    return parse_config(json_data)
end
function parse_config(json_data::Dict{String, N}) where N<:Any
    if !("strips" in keys(json_data) && "controllers" in keys(json_data))
        error("Config file was invalid")
    end
    known_channels = Array{Int,1}(undef, 0)
    known_controllers = Array{String,1}(undef, 0)
    for strip in json_data["strips"]
        if !(strip["channel"] in known_channels)
            push!(known_channels, strip["channel"])
            sort!(known_channels)
        end
        if !(strip["controller"] in known_controllers)
            push!(known_controllers, strip["controller"])
            sort!(known_controllers)
        end
    end
    num_channels = length(known_channels)
    num_controllers = length(known_controllers)
    channel_to_idx = Dict(num => findfirst(known_channels,num) for num in known_channels)
    controller_to_idx = Dict(num => findfirst(known_controllers,num) for num in known_controllers)
    channels = Array{LEDChannel, 1}(undef, num_channels)
    for i in eachindex(channels)
        channels[i] = LEDChannel()
    end
    controllers = Array{LEDController, 1}(undef, num_controllers)
    for i in eachindex(controllers)
        controller_json = json_data["controllers"][known_controllers[i]]
        controllers[i] = LEDController(controller_json["size"], (IPv4(controller_json["ip"]), controller_json["port"]))
    end
    strips = Array{LEDStrip, 1}(undef, 0)
    for strip in json_data["strips"]
        tmp_channel = channels[channel_to_idx[strip["channel"]]]
        tmp_controller = controllers[controller_to_idx[strip["controller"]]]
        push!(strips, LEDStrip(strip["name"], tmp_channel, tmp_controller, strip["start"], strip["end"]))
    end
    led_array = LEDArray(controllers, Array{LEDChannel,1}(undef, 0), channels, strips)
    return led_array
end

function remote_config(outgoing_socket, main_port, discovery_port, subnet)
    broadcast_packet = getBroadcastPacket()
    discovery_socket = UDPSocket()
    bind(discovery_socket, ip"0.0.0.0", discovery_port)
    send(outgoing_socket, subnet, main_port, broadcast_packet)
    discovered_clients = Array{Tuple{IPAddr,Dict},1}(undef, 0)
    searching = true
    @async begin
        while searching
            try
                packet = recvfrom(discovery_socket)
                json_data = Dict{String,Any}()
                try
                    json_data = JSON.parse(convert(String, packet[2]))
                catch
                    println("Failed to parse json")
                end
                if validate_json(json_data)
                    push!(discovered_clients, (packet[1],json_data))
                end
            catch e
                if !isa(e, EOFError)
                    rethrow(e)
                end
            end
        end
    end

    sleep(3)
    searching = false
    close(discovery_socket)

    output = get_overall_config_template()
    known_channels = Array{Int}(undef, 0)
    for data_tup in discovered_clients
        address, data = data_tup
        try
            output["controllers"][data["name"]] = Dict(
                "ip"=>address,
                "port"=>data["port"],
                "size"=>data["numAddrs"]
            )
            for strip in data["strips"]
                push!(output["strips"], Dict(
                    "name"=>strip["name"],
                    "start"=>strip["startAddr"],
                    "end"=>strip["endAddr"],
                    "channel"=>strip["channel"],
                    "controller"=>data["name"]
                ))
                if !(strip["channel"] in known_channels)
                    push!(known_channels, strip["channel"])
                end
            end
        catch
            println("Got some trash json")
        end
        output["general"]["numChannels"] = length(known_channels)
    end
    if length(output["controllers"]) > 0
        return parse_config(output::Dict)
    else
        error("Failed to find any clients")
    end
end

function getBroadcastPacket()
    #macString = readstring(`cat /sys/class/net/eth0/address`)
    ipString = split(read(`hostname -I`, String))[1]
    output_dict = Dict(
        "ip"=>ipString,
        "mac"=>"mac address here",
        "msg_type"=>"startup"
    )
    return json(output_dict)
end

function get_overall_config_template()
    return Dict(
        "general"=>Dict(
            "numChannels"=>0
        ),
        "controllers"=>Dict{String, Dict{String, Union{Number, String, IPAddr}}}(),
        "strips"=>Array{Dict{String,Union{Number, String}},1}(undef, 0)
    )
end

function validate_json(json_data)
    ref_dict = Dict(
        "name"=>"",
        "ip"=>"",
        "port"=>0,
        "mac"=>"",
        "numStrips"=>0,
        "numAddrs"=>0,
        "strips"=>[
            Dict(
                "name"=>"",
                "startAddr"=>0,
                "endAddr"=>1,
                "channel"=>0
            )
        ]
    )

    return check_json(json_data, ref_dict)
end

check_json(x::T, y::T) where {T<:Dict{String, N} where N<:Any} = check_symmetry(x,y)
check_json(x::T, y::N) where {T,N} = false

function check_symmetry(x::T, y::T) where {T<:Dict{S, N} where {S<:Any, N<:Any}}
    if collect(keys(x)) == collect(keys(y))
        return reduce(check_symmetry.(collect(values(x)), collect(values(y)))) do x, y
            return x && y
        end
    else
        return false
    end
end

function check_symmetry(x::AbstractArray, y::AbstractArray)
    try
        return reduce(check_symmetry.(x,y)) do x, y
            return x && y
        end
    catch
        return false
    end
end

check_symmetry(x::T, y::T) where T<:Union{Number, String, Bool} = true
check_symmetry(x::T, y::N) where {T, N} = false