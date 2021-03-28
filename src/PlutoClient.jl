using DandelionWebSockets
import DandelionWebSockets: on_text, on_binary
import DandelionWebSockets: state_connecting, state_open,
                            state_closing, state_closed
import DandelionWebSockets: getrequestheaders, HTTPHandshakeLogic
using MsgPack
using UUIDs: uuid4

# Requests:
#   1. connect
#   2. ping

request_id() = string(uuid4())[1:8]
client_id = request_id()

getrequestheaders(h::HTTPHandshakeLogic) = [
    "Sec-WebSocket-Version" => "13",
    "Upgrade" => "websocket",
    "Connection" => "Upgrade",
    "Sec-WebSocket-Key" => h.key,
    "Cookie" => "secret=Bw5qYr3H"]

mutable struct MyHandler <: WebSocketHandler
        connection::Union{WebSocketConnection, Nothing}
        stop_channel::Channel{Any}
end
MyHandler() = MyHandler(nothing, Channel{Any}(3))

on_text(handler::MyHandler, text::String) = println("received: ", text)
function on_binary(handler::MyHandler, data::Vector{UInt8})
        println("received binary data")

        response = unpack(data)
        println(response)
        println("response => ", response["message"]["patches"])
end

function state_connecting(handler::MyHandler, connection::WebSocketConnection) 
        handler.connection = connection
        println("connecting...")
end
function state_open(handler::MyHandler)
        println("State: OPEN")

        @async begin
                println(client_id)
                println("sending hello...")
                msg = pack(Dict(
                        "request_id" => request_id(),
                        "body" => Dict(),
                        "type" => "connect", 
                        "client_id" => client_id,
                        "notebook_id" => "e17bbb76-8e5e-11eb-3d28-1951d40c2082"))
                send_binary(handler.connection, msg)
                sleep(0.4)
                msg = pack(Dict(
                        "request_id" => request_id(),
                        "body" => Dict("updates" => []),
                        "type" => "update_notebook",
                        "client_id" => client_id,
                        "notebook_id" => "e17bbb76-8e5e-11eb-3d28-1951d40c2082"))
                send_binary(handler.connection, msg)
                println("sent!")
                #send_text(handler.connection, "hey!")
        end
end
state_closing(handler::MyHandler) = println("State: CLOSING")
function state_closed(handler::MyHandler)
        println("State: CLOSED")
        put!(handler.stop_channel, true)
end


handler = MyHandler()
client = WSClient()
ok = wsconnect(client, "ws://127.0.0.1:1235/?id=e17bbb76-8e5e-11eb-3d28-1951d40c2082", handler; fix_small_message_latency=true)
if !ok
        dump(client)
        println("websocket connection failed")
        exit(1)
end

take!(handler.stop_channel)
