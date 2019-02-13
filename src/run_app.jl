push!(LOAD_PATH, pwd())
using Irradiance, Sockets
const subnet = ip"192.168.0.255"
run_app(true, 8080, 37322, subnet)
