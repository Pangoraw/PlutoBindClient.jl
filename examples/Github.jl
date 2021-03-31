import DandelionWebSockets: getrequestheaders, HTTPHandshakeLogic
import HTTP
import JSON

include("../src/PlutoBindClient.jl")


function get_latest_events()
        r = HTTP.get("https://api.github.com/events", ["Accept" => "application/vnd.github.v3+json"])
        JSON.parse(String(r.body))
end

function send_events(handler::PlutoClient)
        events = get_latest_events()
        @info "Got $(length(events)) events"
        for event in events
                set_bond_value(handler, "bonds/ghevents", event)
                sleep(0.1) # throttle a bit
        end
end

notebook_id, cookie = ARGS

getrequestheaders(h::HTTPHandshakeLogic) = [
        "Sec-WebSocket-Version" => "13",
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => h.key,
        "Cookie" => "secret=$cookie"]

client = PlutoClient(notebook_id=notebook_id)
ok = connect(client, "127.0.0.1:1235")
if !ok
        @error "Failed to connect to the notebook"
        exit(1)
end

while true
        send_events(client)
        sleep(.4)
end

take!(client.stop_channel)

