local modem = peripheral.wrap("top")
local modules = peripheral.find("neuralInterface")
args = {...}

if #args < 1 then
    print("Usage: server")
    return
end

if not modules.hasModule("plethora:kinetic") then
    error("Cannot find kinetic", 0)
end

local s = args[1]
modem.open(tonumber(s))
modules.disableAI()

function callCommand(event, modemSide, senderChannel, replyChannel, message, senderDistance)
    --parse command
    local command = {}
    for i in string.gmatch(message, "([^_]+)") do  
        command[#command + 1] = i
        print(i)
    end 
    local commands = {
        ["walk"] = function()
            local x, y, z = gps.locate()
            modules.walk(tonumber(command[2]) - x,tonumber(command[3]) - y,tonumber(command[4]) - z)
            modem.transmit(replyChannel, senderChannel,"Walked To Point!")
        end,
        [66] = function()
            --
        end
    }
    local com = commands[command[1]]
    if (com) then
        com()
    else
        modem.transmit(replyChannel, senderChannel,"Failed Command ... Plz Try Again!")
    end
end

while true do
    --check for commands
    local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")

    callCommand(event, modemSide, senderChannel, replyChannel, message, senderDistance)

    os.sleep(.05)
end
