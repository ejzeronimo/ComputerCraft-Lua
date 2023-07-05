--- library of functions for TurtleNet
TurtleNet = {
    -- clientside functions
    client = {}
}

-- NOTE: classes and types

--- @package
--- @alias t_GetModem fun(): boolean, Modem

--- @package
--- @class t_Message standard messages between turtlenet computers
local __message = {
    --- @alias messageType "request" | "response"
    --- @type messageType the type of message
    type = nil,
    --- @type integer id of the computer sending the message
    origin = nil,
    --- @type integer id of the computer receiving the message or -1
    target = nil,
    --- @type integer epoch of the current time
    timestamp = os.epoch("ingame"),
    --- @type MessageRequest? the request object
    --- @class MessageRequest
    request = {
        --- @alias requestType "start/repairTool" | "stop/repairTool"
        --- @type requestType the type of request
        type = nil,
    },
    --- @type MessageResponse? the response object
    --- @class MessageResponse
    response = {
        --- @type requestType request to respond to
        type = nil,
        --- @type boolean whether the request was accepted or not
        result = nil
    }
}

-- NOTE: private variables

--- @package
--- private number for the turtleNet channel
--- @type integer
local __channel = 543178

--- @package
--- private implemenatation, used for no coupling, need to return a wrapped modem
--- @type t_GetModem
local __getModem


-- NOTE: private functions

--- @package
--- private function that waits for a modem message
--- @return t_Message message a turtleNet message to read
local function __waitForResponse()
    -- repeat until we get a response
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == __channel and message.target == os.computerID()

    return message
end

--- @package
--- starts the turtleNet instance
--- @return boolean success whether the oprtation worked
--- @return Modem? modem the modem peripheral
local function __start()
    -- get the modem
    local success, modem = __getModem()

    if success and modem then
        while not modem.isOpen(__channel) do
            modem.open(__channel)
            sleep(0)
        end

        return true, modem
    end

    return false
end

--- @package
--- stops the turtleNet instance
--- @return boolean success whether the oprtation worked
--- @return Modem? modem the modem peripheral
local function __stop()
    -- get the modem
    local success, modem = __getModem()

    if success and modem then
        while modem.isOpen(__channel) do
            modem.close(__channel)
            sleep(0)
        end

        return true, modem
    end

    return false
end


-- NOTE: public functions

--- application specific implemenatation of getting the modem
--- @param func t_GetModem function to implement
function TurtleNet.setGetModem(func)
    __getModem = func
end

--- function to start, modify, and end a repair tool request
--- @return boolean valid state of the given request
--- @return function refresh function to refresh request
--- @return function comlete function to complete the request, optional boolean
function TurtleNet.client.requestToolRepair()
    --- function to end a tool repair event
    local function completeToolRepair()
        -- get the modem
        local success, modem = __start()

        if success and modem then
            modem.transmit(__channel, __channel, {
                type = "request",
                origin = os.computerID(),
                target = -1,
                timestamp = os.epoch("ingame"),
                request = {
                    type = "stop/repairTool"
                }
            })

            -- repeat until we get a response
            local message
            repeat
                message = __waitForResponse()
            until message.response.type == "stop/repairTool" and message.response.result
        end

        __stop()
    end


    --- function to start or refresh tool repair
    --- @return boolean valid state of the given request
    --- @return function refresh function to refresh request
    --- @return function comlete function to complete the request, optional boolean
    local function startOrRefreshToolRepair()
        -- get the modem
        local success, modem = __start()
        local result = false

        if success and modem then
            --- @type t_Message
            local data = {
                type = "request",
                origin = os.computerID(),
                target = -1,
                timestamp = os.epoch("ingame"),
                request = {
                    type = "start/repairTool"
                }
            }

            modem.transmit(__channel, __channel, data)

            -- repeat until we get a response
            local message
            repeat
                message = __waitForResponse()
            until message.response.type == "start/repairTool" and (message.response.result ~= nil)

            result = message.response.result
        end

        __stop()
        return result, startOrRefreshToolRepair, completeToolRepair
    end

    -- start the chain
    local result = startOrRefreshToolRepair()
    return result, startOrRefreshToolRepair, completeToolRepair
end

-- NOTE: export statement
return TurtleNet
