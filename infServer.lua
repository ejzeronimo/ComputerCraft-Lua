--[[
    TODO: make this get latest turtle information
--]]

local Pretty = require "cc.pretty"
local TurtleNet = require("lib.TurtleNet")

-- NOTE: types

--- @enum state_t
local STATE = {
    idle = 0,
    toolRepair = 1,
    refueling = 2,
}

-- NOTE: globals

--- @type Modem
--- @diagnostic disable-next-line: assign-type-mismatch
local modem = peripheral.wrap("top")

--- @type Monitor
--- @diagnostic disable-next-line: assign-type-mismatch
local monitor = peripheral.wrap("monitor_0")

--- @type Computer
--- @diagnostic disable-next-line: assign-type-mismatch
local localTurtle = peripheral.wrap("turtle_0")

--- @type state_t
local state = STATE.idle

--- @type {[number]: state_t}
local remoteStates = {}

--- @type {[number]: { [number]: number}}
local remoteCoords = {}

--- @type {[number]: TurtleNet.Message}
local remoteMessages = {}

local butlerMsg, butler

-- NOTE: functions

--- @param st state_t
--- @return boolean
local function checkForState(st)
    for index, value in ipairs(remoteStates) do
        if value == st then
            return true
        end
    end

    return false
end

--- @param st requestType_t
local function butlerSetState(st)
    local fooMsg

    -- send the mode to set to
    TurtleNet.sendMessage({
        type = "request",
        origin = os.getComputerID(),
        target = butler,
        timestamp = os.epoch("ingame"),
        --- @type messageRequest_t
        request = {
            type = st
        }
    })

    -- wait for success
    repeat
        fooMsg = TurtleNet.getMessage()
    until fooMsg.type == "response" and fooMsg.origin == butler
end

-- NOTE: setup
TurtleNet.setConfig({
    channel = 54317,
    getModem = function()
        return true, modem
    end,
    server = {
        acceptedIds = {
            os.getComputerID(),
            -1
        }
    }
})

local success = TurtleNet.server.start()

monitor.clear()
monitor.setCursorPos(1,1)
term.redirect(monitor)

print("server started")
print("getting butler")

localTurtle.reboot()

-- get the butler
repeat
    print(".")
    butlerMsg = TurtleNet.getMessage()
until butlerMsg.type == "broadcast" and butlerMsg.broadcast.protocol == "infmine/identityButler"

butler = butlerMsg.origin

print("butler found")

-- NOTE: tasks

local function taskServer()
    while true do
        -- handle the messages in here
        local msg = TurtleNet.getMessage()

        Pretty.pretty_print(msg)
        remoteMessages[msg.origin] = msg

        if msg.type == "request" then
            if msg.request.type == TurtleNet.REQUEST_TYPE.start_repairTool then
                -- the start repair tool case
                if state ~= STATE.idle and state ~= STATE.toolRepair then
                    TurtleNet.sendMessage({
                        type = "response",
                        origin = os.getComputerID(),
                        target = msg.origin,
                        timestamp = os.epoch("ingame"),
                        --- @type messageResponse_t
                        response = {
                            type = TurtleNet.REQUEST_TYPE.start_repairTool,
                            result = false
                        }
                    })
                else
                    state = STATE.toolRepair

                    -- tell the butler to swap modes
                    butlerSetState(TurtleNet.REQUEST_TYPE.start_repairTool)

                    TurtleNet.sendMessage({
                        type = "response",
                        origin = os.getComputerID(),
                        target = msg.origin,
                        timestamp = os.epoch("ingame"),
                        --- @type messageResponse_t
                        response = {
                            type = TurtleNet.REQUEST_TYPE.start_repairTool,
                            result = true
                        }
                    })

                    remoteStates[msg.origin] = STATE.toolRepair
                end
            elseif msg.request.type == TurtleNet.REQUEST_TYPE.stop_repairTool then
                -- the end repair tool case
                TurtleNet.sendMessage({
                    type = "response",
                    origin = os.getComputerID(),
                    target = msg.origin,
                    timestamp = os.epoch("ingame"),
                    --- @type messageResponse_t
                    response = {
                        type = TurtleNet.REQUEST_TYPE.stop_repairTool,
                        result = true
                    }
                })

                remoteStates[msg.origin] = STATE.idle

                if not checkForState(STATE.toolRepair) and state == STATE.toolRepair then
                    -- reset to idle
                    state = STATE.idle

                    -- tell the butler to swap modes
                    butlerSetState(TurtleNet.REQUEST_TYPE.stop_repairTool)
                end
            elseif msg.request.type == TurtleNet.REQUEST_TYPE.start_refuel then
                -- the start refuel case
                if state ~= STATE.idle and state ~= STATE.refueling then
                    TurtleNet.sendMessage({
                        type = "response",
                        origin = os.getComputerID(),
                        target = msg.origin,
                        timestamp = os.epoch("ingame"),
                        --- @type messageResponse_t
                        response = {
                            type = TurtleNet.REQUEST_TYPE.start_refuel,
                            result = false
                        }
                    })
                else
                    state = STATE.refueling

                    -- tell the butler to swap modes
                    butlerSetState(TurtleNet.REQUEST_TYPE.start_refuel)

                    TurtleNet.sendMessage({
                        type = "response",
                        origin = os.getComputerID(),
                        target = msg.origin,
                        timestamp = os.epoch("ingame"),
                        --- @type messageResponse_t
                        response = {
                            type = TurtleNet.REQUEST_TYPE.start_refuel,
                            result = true
                        }
                    })

                    remoteStates[msg.origin] = STATE.refueling
                end
            elseif msg.request.type == TurtleNet.REQUEST_TYPE.stop_refuel then
                -- the end refuel case
                TurtleNet.sendMessage({
                    type = "response",
                    origin = os.getComputerID(),
                    target = msg.origin,
                    timestamp = os.epoch("ingame"),
                    --- @type messageResponse_t
                    response = {
                        type = TurtleNet.REQUEST_TYPE.stop_refuel,
                        result = true
                    }
                })

                remoteStates[msg.origin] = STATE.idle

                if not checkForState(STATE.refueling) and state == STATE.refueling then
                    -- reset to idle
                    state = STATE.idle

                    -- tell the butler to swap modes
                    butlerSetState(TurtleNet.REQUEST_TYPE.stop_refuel)
                end
            end
        elseif msg.type == "response" then
            if msg.response.type == TurtleNet.REQUEST_TYPE.send_coordinate then
                --- @diagnostic disable-next-line: undefined-field
                remoteCoords[msg.origin] = msg.response.globalCoord
            end
        elseif msg.type == "broadcast" then
            -- if a turtle is looking for our server
        end
    end
end

local function taskDisplay()
    while true do
        sleep(0)
    end
end

-- NOTE: main loop
parallel.waitForAny(taskServer, taskDisplay)

TurtleNet.server.stop()
