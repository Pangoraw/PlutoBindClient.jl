include("../src/PlutoClient.jl")

import DandelionWebSockets: getrequestheaders, HTTPHandshakeLogic

notebook_id, cookie = ARGS

getrequestheaders(h::HTTPHandshakeLogic) = [
        "Sec-WebSocket-Version" => "13",
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => h.key,
        "Cookie" => "secret=$(cookie)"]

client = PlutoClient(notebook_id=notebook_id)
ok = connect(client, "127.0.0.1:1235")
if !ok
        @error "Failed to connect to the notebook"
        exit(1)
end

while true
        stats = Dict(st.first => compute_percentage(st.second, st.first) for st in get_cpu_stats())
        set_bond_value(handler, "bonds/a", stats)
        sleep(4)
end

take!(client.stop_channel)
