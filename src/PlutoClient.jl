using DandelionWebSockets
using MsgPack
using UUIDs: uuid4

import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed
import DandelionWebSockets: getrequestheaders, HTTPHandshakeLogic

include("CPU.jl")

# module Firebasey
#         include("Firebasey.jl")
# end

# Requests:
#   1. connect
#   2. ping


Base.@kwdef mutable struct NotebookState
        bonds::Dict{Symbol,Any}=Dict{Symbol,Any}()
end
current_state = NotebookState()

get_request_id() = string(uuid4())[1:7]
client_id = get_request_id()

Base.@kwdef mutable struct PlutoClient <: WebSocketHandler
        connection::Union{WebSocketConnection, Nothing}
        stop_channel::Channel{Any}
        notebook_id::String
end
PlutoClient(;notebook_id) = PlutoClient(nothing, Channel{Any}(3), notebook_id)

on_text(handler::PlutoClient, text::String) = println("received: ", text)
function on_binary(handler::PlutoClient, data::Vector{UInt8})
        println("received binary data")

        response = unpack(data)

        # if haskey(response, "message") && haskey(response["message"], "patches")
        #         fb_patches = [Base.convert(Firebasey.JSONPatch, update) for update in response["message"]["patches"]]
        #         @show fb_patches
                
        #         try
        #                 for patch in fb_patches
        #                         Firebasey.applypatch!(current_state, patch)
        #                 end
        #                 bonds_patch = response["message"]["patches"][1]["value"]["bonds"]
        #                 @show bonds_patch
        #         catch e
        #                 @error e
        #         end
        # end
end
function send_msg(handler::PlutoClient, payload)
        msg = merge(payload, Dict("request_id" => get_request_id(), "client_id" => client_id)) |> pack
        send_binary(handler.connection, msg)
end

function ping(handler::PlutoClient)
        send_msg(handler, Dict("request_id" => get_request_id(), "type" => "ping", "client_id" => client_id, "body" => Dict()))
end
function state_connecting(handler::PlutoClient, connection::WebSocketConnection) 
        handler.connection = connection
        println("connecting...")
end

function set_bond_value(handler::PlutoClient, path, value)
        send_msg(handler, Dict(
                "notebook_id" => handler.notebook_id,
                "type" => "update_notebook",
                "body" => Dict("updates" => [Dict("value" => Dict("value" => value), "op" => "replace", "path" => split(path, "/"))])))
end
function state_open(handler::PlutoClient)
        println("State: OPEN")

        @async begin
                println("sending hello...")
                send_msg(handler, Dict(
                        "body" => Dict(),
                        "type" => "connect", 
                        "notebook_id" => client.notebook_id))
                ping(handler)
                send_msg(handler, Dict(
                        "body" => Dict("updates" => []),
                        "type" => "update_notebook",
                        "notebook_id" => client.notebook_id))

                @async begin
   
                        @info "shghsquidhqsuidh"
                        while true
                                stats = Dict(st.first => compute_percentage(st.second, st.first) for st in get_cpu_stats())
                                set_bond_value(handler, "bonds/a", stats)
                                sleep(.4)
                        end
                end

                while true
                        ping(handler)
                        sleep(28)
                end
        end
end
state_closing(handler::PlutoClient) = println("State: CLOSING")
function state_closed(handler::PlutoClient)
        println("State: CLOSED")
        put!(handler.stop_channel, true)
end

function connect(handler::PlutoClient, url)
    
        wsclient = WSClient()
        url = "ws://$(url)/?id=$(handler.notebook_id)"
        @show url
        ok = wsconnect(wsclient, url, handler)
        if !ok
                dump(wsclient)
                println("websocket connection failed")
                exit(1)
        end
end

client = PlutoClient(notebook_id="b3967950-8fd3-11eb-0922-23b4633b089b")
getrequestheaders(h::HTTPHandshakeLogic) = [
        "Sec-WebSocket-Version" => "13",
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => h.key,
        "Cookie" => "secret=nzpl2yWx"]
connect(client, "127.0.0.1:1235")

@info "Waiting!"

take!(client.stop_channel)
