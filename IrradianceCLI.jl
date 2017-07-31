using Colors
function handle_cli(channels)
    blue_ansi = "\033[94m"
    end_ansi = "\033[0m"
    bold_ansi = "\033[1m"
    signal_channel = channels[1]
    config_channel = channels[2]
    stopped = false
    valid_modes = r"mode\s*\d{1,2}"i
    config_command = r"config\s*(?<args>.*)"i
    while !stopped
        print("$(bold_ansi)$(blue_ansi)irradiance>$(end_ansi)")
        temp = readline(STDIN)
        if typeof(temp) == Char
            temp = convert(String, [temp])
        end
        if ismatch(valid_modes, temp)
            if length(signal_channel.data) > 0
                take!(signal_channel)
            end
            put!(signal_channel, temp)
        elseif ismatch(config_command, temp)
            handle_config(config_channel, match(config_command, temp)[:args])
        elseif (
                ismatch(r"shutdown|quit"six, temp) ||
                ismatch(r"\x03"six, temp) ||
                ismatch(r"\x02"six, temp)
            )
            if length(signal_channel.data) > 0
                take!(signal_channel)
            end
            put!(signal_channel, "shutdown")
            stopped = true
        end
    end
end
function handle_config(config_channel::Channel, ipt)
    valid_subcommands = r"\s*(?<subcommand>primary_color|secondary_color|scaling|speed)\s*(?<arg>.*)\s*"i
    valid_arguments = Dict{String, Regex}(
        "primary_color"=>r"(?P<arg>#{0,1}[0-9A-F]{6})\s*"i,
        "secondary_color"=>r"(?P<arg>#{0,1}[0-9A-F]{6})\s*"i,
        "scaling"=>r"(?P<arg>[\d+, \d*.\d+])\s*"i,
        "speed"=>r"(?P<arg>[\d+, \d*.\d+])\s*"i
    )
    handlers = Dict{String, Function}(
        "primary_color"=>handle_primary_color,
        "secondary_color"=>handle_secondary_color,
        "scaling"=>handle_scaling_config,
        "speed"=>handle_speed_config
    )

    if ismatch(valid_subcommands, ipt)
        mat1 = match(valid_subcommands, ipt)
        subcom = lowercase(mat1[:subcommand])
        if ismatch(valid_arguments[subcom], mat1[:arg])
            handlers[subcom](config_channel, mat1[:arg])
        else
            println("Sorry, that was an invalid argument.")
        end
    else
        println("Sorry, that subcommand was unrecognized.")
    end
end

function swap_configs(config_channel::Channel{EffectConfig}, new_config::EffectConfig)
    put!(config_channel, new_config)
    take!(config_channel)
end

function handle_primary_color(config_channel::Channel{EffectConfig}, argument)
    letters_only_regex = r"$[0-9A-F]{6}\s*"i
    if ismatch(letters_only_regex, argument)
        argument = "#$argument"
    end
    cur_con = fetch(config_channel)
    new_prim_color = cur_con.primary_color
    try
        new_prim_color = convert(HSL, parse(Colorant, argument))
    catch
        println("Sorry, failed to parse that input.")
    end
    new_config = EffectConfig(new_prim_color, cur_con.secondary_color, cur_con.scaling, cur_con.speed, cur_con.special)
    swap_configs(config_channel, new_config)
end

function handle_secondary_color(config_channel::Channel{EffectConfig}, argument)
    cur_con = fetch(config_channel)
    new_sec_color = cur_con.secondary_color
    try
        new_sec_color = convert(HSL, parse(Colorant, argument))
    catch
        println("Sorry, failed to parse that input.")
    end
    new_config = EffectConfig(cur_con.primary_color, new_sec_color, cur_con.scaling, cur_con.speed, cur_con.special)
    swap_configs(config_channel, new_config)
end

function handle_scaling_config(config_channel::Channel{EffectConfig}, argument)
    cur_con = fetch(config_channel)
    new_scaling = cur_con.scaling
    try
        new_scaling = parse(Float64, argument)
    catch
        println("Sorry, failed to parse that input.")
    end
    new_config = EffectConfig(cur_con.primary_color, cur_con.secondary_color, new_scaling, cur_con.speed, cur_con.special)
    swap_configs(config_channel, new_config)
end

function handle_speed_config(config_channel::Channel{EffectConfig}, argument)
    cur_con = fetch(config_channel)
    new_speed = cur_con.speed
    try
        new_speed = parse(Float64, argument)
    catch
        println("Sorry, failed to parse that input.")
    end
    new_config = EffectConfig(cur_con.primary_color, cur_con.secondary_color, cur_con.scaling, new_speed, cur_con.special)
    swap_configs(config_channel, new_config)
end