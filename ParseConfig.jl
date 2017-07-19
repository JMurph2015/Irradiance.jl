using JSON

function parse_config(filename)
    json_data = Dict()
    open(filename, "r") do f
        json_data = JSON.parse(f)
    end
    "strips" in keys(json_data) || error("Config file was invalid")
    "controllers" in keys(json_data) || error("Config file missing controller section")
    known_channels = Array{Int,1}(0)
    known_controllers = Array{String,1}(0)
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
    channels = Array{LEDChannel, 1}(num_channels)
    for i in eachindex(channels)
        channels[i] = LEDChannel()
    end
    controllers = Array{LEDController, 1}(num_controllers)
    for i in eachindex(controllers)
        controller_json = json_data["controllers"][known_controllers[i]]
        controllers[i] = LEDController(controller_json["size"], (IPv4(controller_json["ip"]), controller_json["port"]))
    end
    strips = Array{LEDStrip, 1}(0)
    for strip in json_data["strips"]
        tmp_channel = channels[channel_to_idx[strip["channel"]]]
        tmp_controller = controllers[controller_to_idx[strip["controller"]]]
        push!(strips, LEDStrip(strip["name"], tmp_channel, tmp_controller, strip["start"], strip["end"]))
    end
    led_array = LEDArray(controllers, channels, strips)
    return led_array
end