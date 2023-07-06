--- library of functions for TurtleNet
local TurtleNet = {
    -- clientside functions
    client = {}
}

-- NOTE: classes and types

--- @package
--- @alias getModem_t fun(): boolean, Modem

--- @package
--- @alias channel_t integer | `543178` channel to use for TurtleNet

--- @package
--- @alias turtleNetConfig_t { getModem: getModem_t, channel: channel_t }

--- @type turtleNetMessage_t
--- @class turtleNetMessage_t
TurtleNet.Message = {
    --- @package
    --- @alias messageType_t `"request"` | `"response"`
    --- @type messageType_t the type of message
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
        --- @package
        --- @alias requestType_t `"start/repairTool"` | `"stop/repairTool"`
        --- @type requestType_t the type of request
        type = nil,
    },
    --- @type MessageResponse? the response object
    --- @class MessageResponse
    response = {
        --- @type requestType_t request to respond to
        type = nil,
        --- @type boolean whether the request was accepted or not
        result = nil
    },
    --- makes a new instance of this object
    --- @return turtleNetMessage_t
    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        return o
    end
}

-- NOTE: private variables

--- @package
--- @type turtleNetConfig_t config for this library
local __config

-- NOTE: private functions

--- @package
--- private function that waits for a modem message
--- @return turtleNetMessage_t message a turtleNet message to read
local function __waitForResponse()
    -- repeat until we get a response
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == __config.channel and message.target == os.computerID()

    return message
end

--- @package
--- starts the turtleNet instance
--- @return boolean success whether the oprtation worked
--- @return Modem? modem the modem peripheral
local function __start()
    -- get the modem
    local success, modem = __config.getModem()

    if success and modem then
        while not modem.isOpen(__config.channel) do
            modem.open(__config.channel)
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
    local success, modem = __config.getModem()

    if success and modem then
        while modem.isOpen(__config.channel) do
            modem.close(__config.channel)
        end

        return true, modem
    end

    return false
end

-- NOTE: public functions

--- application specific function to set config
--- @param config turtleNetConfig_t
function TurtleNet.setConfig(config)
    __config = config
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

        --- @type turtleNetMessage_t
        local data = {
            type = "request",
            origin = os.computerID(),
            target = -1,
            timestamp = os.epoch("ingame"),
            request = {
                type = "stop/repairTool"
            }
        }

        if success and modem then
            modem.transmit(__config.channel, __config.channel, data)

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
            --- @type turtleNetMessage_t
            local data = {
                type = "request",
                origin = os.computerID(),
                target = -1,
                timestamp = os.epoch("ingame"),
                request = {
                    type = "start/repairTool"
                }
            }

            modem.transmit(__config.channel, __config.channel, data)

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
