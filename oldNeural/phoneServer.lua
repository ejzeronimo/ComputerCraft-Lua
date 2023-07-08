local modem = peripheral.wrap("back")
local args = {...}

if #args < 2 then
    print("Usage: server, isListen")
    return
end

local port = tonumber(args[1])

function toboolean(b)
    if b == "true" then
        return true
    else
        return false
    end
end

function formatCommand(m)
    local command = ""
    if m == "Walk" then
        local x, y, z = gps.locate()
        command = "walk_" .. x .. "_" .. y .. "_" .. z
    else
        command = m
    end
    modem.transmit(port, 1, command)
    io.write("\nCommand: " .. command .. " Sent to Port: " .. port .."\n")

end

if toboolean(args[2]) then
    --if we listen
    modem.open(port)

    while true do
        local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
        print(message)
    end
else
    while true do
        io.write("Enter Command: \n")
        local input = io.read()
        formatCommand(input)
    end
end
