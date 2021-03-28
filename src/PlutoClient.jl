using DandelionWebSockets
using MsgPack
using UUIDs: uuid4

import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed
import DandelionWebSockets: getrequestheaders, HTTPHandshakeLogic

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
        msg = pack(payload)
        send_binary(handler.connection, msg)
end

function ping(handler::PlutoClient)
        send_msg(handler, Dict("request_id" => get_request_id(), "type" => "ping", "client_id" => client_id, "body" => Dict()))
end
function state_connecting(handler::PlutoClient, connection::WebSocketConnection) 
        handler.connection = connection
        println("connecting...")
end
function state_open(handler::PlutoClient)
        println("State: OPEN")

        @async begin
                println(client.notebook_id)
                request_id = get_request_id()
                println("sending hello $(request_id)...")
                send_msg(handler, Dict(
                        "request_id" => request_id,
                        "body" => Dict(),
                        "type" => "connect", 
                        "client_id" => client_id,
                        "notebook_id" => client.notebook_id))
                sleep(0.4)
                ping(handler)
                sleep(0.4)
                request_id = get_request_id()
                println("sending hello $(request_id)...")
                send_msg(handler, Dict(
                        "request_id" => request_id,
                        "body" => Dict("updates" => []),
                        "type" => "update_notebook",
                        "client_id" => client_id,
                        "notebook_id" => client.notebook_id))
                println("sent!")
                #send_text(handler.connection, "hey!")

                send_msg(handler, Dict(
                        "request_id" => get_request_id(),
                        "body" => Dict("query" => "sq"),
                        "notebook_id" => client.notebook_id,
                        "type" => "complete",
                        "client_id" => client_id,
                ))

                @async begin
                        value = 0
                        while true
                                send_msg(handler, Dict(
                                        "request_id" => get_request_id(),
                                        "notebook_id" => handler.notebook_id,
                                        "client_id" => client_id,
                                        "type" => "update_notebook",
                                        "body" => Dict("updates" => [Dict("value" => Dict("value" => value), "op" => "replace", "path" => ["bonds", "a"])])))
                                value += 5 * (rand() - 0.5)
                                sleep(.25)
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

client = PlutoClient(notebook_id="8a008156-8fcb-11eb-2283-59fd2069a573")
getrequestheaders(h::HTTPHandshakeLogic) = [
        "Sec-WebSocket-Version" => "13",
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => h.key,
        "Cookie" => "secret=K3zjTlsw"]
connect(client, "127.0.0.1:1235")

take!(client.stop_channel)
