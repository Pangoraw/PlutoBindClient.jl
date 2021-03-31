using DandelionWebSockets
using MsgPack
using UUIDs: uuid4

import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed
import DandelionWebSockets: getrequestheaders, HTTPHandshakeLogic

# include("CPU.jl")

get_request_id() = string(uuid4())[1:7]
client_id = get_request_id()

Base.@kwdef mutable struct PlutoClient <: WebSocketHandler
        connection::Union{WebSocketConnection, Nothing}
        stop_channel::Channel{Any}
        notebook_id::String
end
PlutoClient(;notebook_id) = PlutoClient(nothing, Channel{Any}(3), notebook_id)

handle_message(handler::PlutoClient, message) = nothing

on_text(handler::PlutoClient, text::String) = println("received: ", text)
function on_binary(handler::PlutoClient, data::Vector{UInt8})
        println("received binary data")

        message = unpack(data)

        handle_message(handler, message)
end
function send_msg(handler::PlutoClient, payload)
        msg = merge(payload, Dict("request_id" => get_request_id(), "client_id" => client_id)) |> pack
        send_binary(handler.connection, msg)
end

function ping(handler::PlutoClient)
        send_msg(handler, Dict("request_id" => get_request_id(), "type" => "ping", "client_id" => client_id, "body" => Dict()))
end
state_connecting(handler::PlutoClient, connection::WebSocketConnection) = 
        handler.connection = connection


set_bond_value(handler::PlutoClient, path, value) =
        send_msg(handler, Dict(
                "notebook_id" => handler.notebook_id,
                "type" => "update_notebook",
                "body" => Dict("updates" => [Dict("value" => Dict("value" => value), "op" => "replace", "path" => split(path, "/"))])))

function state_open(handler::PlutoClient)
        @async begin
                send_msg(handler, Dict(
                        "body" => Dict(),
                        "type" => "connect", 
                        "notebook_id" => client.notebook_id))
                ping(handler)
                send_msg(handler, Dict(
                        "body" => Dict("updates" => []),
                        "type" => "update_notebook",
                        "notebook_id" => client.notebook_id))

                while true
                        ping(handler)
                        sleep(28)
                end
        end
end
state_closing(handler::PlutoClient) = @info "Closing connection..."
state_closed(handler::PlutoClient) = put!(handler.stop_channel, true)

function connect(handler::PlutoClient, url)
        wsclient = WSClient()
        url = "ws://$(url)/?id=$(handler.notebook_id)"
        wsconnect(wsclient, url, handler)
end
