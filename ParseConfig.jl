using JSON

function parse_config(filename)
    open(filename, "r") do f
        json_data = JSON.parse(f)
    end
    "strips" in json_data || error("Config file was invalid")
    "controllers" in json_data || error("Config file missing controller section")
    known_channels = Array{Int,1}(0)
    known_controllers = Array{Int,1}(0)
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
    channels = Array{LEDChannels, 1}(num_channels)
    controllers = Array{LEDControllers, 1}(num_controllers)
    for i in eachindex(controllers)
        controller_json = json_data["controllers"][known_controllers[i]]
        controllers[i].location = (IPAddr(controller_json["ip"]), controller_json["port"])
    strips = Array{LEDControllers, 1}(0)
    for strip in json_data["strips"]
        tmp_channel = channels[channel_to_idx[strip["channel"]]]
        tmp_controller = controllers[controller_to_idx[strip["controller"]]]
        push!(strips, LEDStrip(strip["name"], tmp_channel, tmp_controller, strip["start"], strip["end"]))
    end
    led_array = LEDArray(controllers, channels, strips)
    return led_array
end