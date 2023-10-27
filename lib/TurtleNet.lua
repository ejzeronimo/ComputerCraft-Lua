--- library of functions for TurtleNet
local TurtleNet = {
    -- clientside functions
    client = {},
    -- serverside functions
    server = {}
}

-- NOTE: classes and types

--- @alias messageType_t  `"request"` the types of message turtlenet can send
---| `"response"`
---| `"broadcast"`

--- @enum requestType_t enum for all the commands/ actions turtlenet can use
TurtleNet.REQUEST_TYPE = {
    -- the tool repair enums
    start_repairTool = "start/repairTool",
    stop_repairTool = "stop/repairTool",
    -- the energy refill enums
    start_refuel = "start/refuel",
    stop_refuel = "stop/refuel",
    -- the telemetry enums
    send_coordinate = "telemetry/coordinate",
}

--- @class messageRequest_t request object for message schema
--- @field type requestType_t the type of request

--- @class messageResponse_t: messageRequest_t response object for message schema
--- @field result boolean whether the request was accepted or not

--- @class messageBroadcast_t broadcast object for the message schema
--- @field protocol string the protocol used by this broadcast
--- @field payload any the data

--- @alias getModem_t fun(): boolean, Modem function to equip the modem and return it

--- @alias channel_t number | `54317` channel to use for turtlenet

--- @class turtleNetServerConfig_t server exclusive config
--- @field acceptedIds number[] array of ids for the server to accept

--- @class turtleNetConfig_t config for this library
--- @field getModem getModem_t function to get the modem
--- @field channel channel_t channel for turtlenet to use
--- @field server? turtleNetServerConfig_t server exclusive config

--- @class TurtleNet.Message external facing message class with constructor
TurtleNet.Message = {
    --- @type messageType_t the type of message
    type = nil,
    --- @type number id of the computer sending the message
    origin = nil,
    --- @type number id of the computer receiving the message or -1
    target = nil,
    --- @type number epoch of the current time
    timestamp = os.epoch("ingame"),
    --- @type messageRequest_t? the request object
    request = nil,
    --- @type messageResponse_t? the response object
    response = nil,
    --- @type messageBroadcast_t? the response object
    broadcast = nil,
    --- makes a new instance of this object
    --- @return TurtleNet.Message
    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        return o
    end
}

-- NOTE: private variables

--- @type turtleNetConfig_t config for this library
local __config

-- NOTE: private functions

--- function to check if in a list
--- @param arr number[] array of items to search
--- @param val number the name to check for
--- @return boolean inList if the item is in the list
local function __inList(arr, val)
    for index, value in ipairs(arr) do
        -- we grab the first index of our sub-table instead
        if value == val then
            return true
        end
    end

    return false
end

--- private function that waits for a modem message
--- @param ids number[]? optional array of ids to accept
--- @return TurtleNet.Message message a turtleNet message to read
local function __waitForResponse(ids)
    local targets = (ids ~= nil) and ids or { os.computerID() }

    -- repeat until we get a response
    local event, side, channel, replyChannel, message, distance
    repeat
        event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
    until channel == __config.channel and __inList(targets, message.target)

    return message
end

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

-- NOTE: universal functions

--- function to broadcast protocol and data
--- @param protocol string name of the protocol
--- @param payload any? the data to send
function TurtleNet.broadcast(protocol, payload)
    -- get the modem
    local success, modem = __start()

    if success and modem then
        modem.transmit(__config.channel, __config.channel, {
            type = "broadcast",
            origin = os.computerID(),
            target = -1,
            timestamp = os.epoch("ingame"),
            broadcast = {
                protocol = protocol,
                payload = payload
            }
        })
    end
end

--- function to get a turtlenet message
--- @return TurtleNet.Message msg a message that is directed to the server
function TurtleNet.getMessage()
    if __config.server ~= nil and __config.server.acceptedIds ~= nil then
        return __waitForResponse(__config.server.acceptedIds)
    end

    return __waitForResponse()
end

--- function to send a turtlenet message
--- @param msg TurtleNet.Message a message for the server to send
function TurtleNet.sendMessage(msg)
    local success, modem = __start()

    if modem then
        modem.transmit(__config.channel, __config.channel, msg)
    end
end

-- NOTE: public client functions

--- function to start, modify, and end a repair tool request
--- @return boolean valid state of the given request
--- @return function refresh function to refresh request
--- @return function comlete function to complete the request, optional boolean
function TurtleNet.client.requestToolRepair()
    --- function to end a tool repair event
    local function completeToolRepair()
        -- get the modem
        local success, modem = __start()

        --- @type TurtleNet.Message
        local data = {
            type = "request",
            origin = os.computerID(),
            target = -1,
            timestamp = os.epoch("ingame"),
            request = {
                type = TurtleNet.REQUEST_TYPE.stop_repairTool
            }
        }

        if success and modem then
            modem.transmit(__config.channel, __config.channel, data)

            -- repeat until we get a response
            local message
            repeat
                message = __waitForResponse()
            until message.response.type == TurtleNet.REQUEST_TYPE.stop_repairTool and message.response.result
        end
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
            --- @type TurtleNet.Message
            local data = {
                type = "request",
                origin = os.computerID(),
                target = -1,
                timestamp = os.epoch("ingame"),
                request = {
                    type = TurtleNet.REQUEST_TYPE.start_repairTool
                }
            }

            modem.transmit(__config.channel, __config.channel, data)

            -- repeat until we get a response
            local message
            repeat
                message = __waitForResponse()
            until message.response.type == TurtleNet.REQUEST_TYPE.start_repairTool and (message.response.result ~= nil)

            result = message.response.result

            print(result)
        end

        return result, startOrRefreshToolRepair, completeToolRepair
    end

    -- start the chain
    local result = startOrRefreshToolRepair()
    return result, startOrRefreshToolRepair, completeToolRepair
end

--- function to start, modify, and end a refill request
--- @return boolean valid state of the given request
--- @return function refresh function to refresh request
--- @return function comlete function to complete the request, optional boolean
function TurtleNet.client.requestEnergyRefill()
    --- function to end a refill event
    local function completeRefill()
        -- get the modem
        local success, modem = __start()

        --- @type TurtleNet.Message
        local data = {
            type = "request",
            origin = os.computerID(),
            target = -1,
            timestamp = os.epoch("ingame"),
            request = {
                type = TurtleNet.REQUEST_TYPE.stop_refuel
            }
        }

        if success and modem then
            modem.transmit(__config.channel, __config.channel, data)

            -- repeat until we get a response
            local message
            repeat
                message = __waitForResponse()
            until message.response.type == TurtleNet.REQUEST_TYPE.stop_refuel and message.response.result
        end
    end


    --- function to start or refresh refill
    --- @return boolean valid state of the given request
    --- @return function refresh function to refresh request
    --- @return function comlete function to complete the request, optional boolean
    local function startOrRefreshRefill()
        -- get the modem
        local success, modem = __start()
        local result = false

        if success and modem then
            --- @type TurtleNet.Message
            local data = {
                type = "request",
                origin = os.computerID(),
                target = -1,
                timestamp = os.epoch("ingame"),
                request = {
                    type = TurtleNet.REQUEST_TYPE.start_refuel
                }
            }

            modem.transmit(__config.channel, __config.channel, data)

            -- repeat until we get a response
            local message
            repeat
                message = __waitForResponse()
            until message.response.type == TurtleNet.REQUEST_TYPE.start_refuel and (message.response.result ~= nil)

            result = message.response.result

            print(result)
        end

        return result, startOrRefreshRefill, completeRefill
    end

    -- start the chain
    local result = startOrRefreshRefill()
    return result, startOrRefreshRefill, completeRefill
end

--- function to send the data as a coordinate to the server
--- @param localCoord any local coordinate
--- @param globalCoord any global coordinate
function TurtleNet.client.sendCoordinate(localCoord, globalCoord)
    local success, modem = __start()

    --- @type TurtleNet.Message
    local data = {
        type = "response",
        origin = os.computerID(),
        target = -1,
        timestamp = os.epoch("ingame"),
        response = {
            type = TurtleNet.REQUEST_TYPE.send_coordinate,
            localCoord = localCoord,
            globalCoord = globalCoord,
        }
    }

    if modem then
        modem.transmit(__config.channel, __config.channel, data)
    end
end

-- NOTE: public server functions

--- function to start a turtlenet server
function TurtleNet.server.start()
    return __start()
end

--- function to stop a turtlenet server
function TurtleNet.server.stop()
    return __stop()
end

-- NOTE: export statement
return TurtleNet
