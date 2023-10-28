--[[
    Server controlled turtle to modify the remote storage
--]]

local TurtleNet = require("lib.TurtleNet")

-- NOTE: types

--- @enum butlerState_t
local STATE = {
    idle = 0,
    toolRepair = 1,
    refueling = 2,
}

-- NOTE: globals

--- @type butlerState_t
local state = STATE.idle

--- @type Inventory
--- @diagnostic disable-next-line: assign-type-mismatch
local remoteChest = peripheral.wrap("front")

--- @type Inventory
--- @diagnostic disable-next-line: assign-type-mismatch
local inputChest = peripheral.wrap("top")

--- @type Inventory
--- @diagnostic disable-next-line: assign-type-mismatch
local outputChest = peripheral.wrap("bottom")

--- @type TurtleNet.Message
local msg

-- NOTE: setup
TurtleNet.setConfig({
    channel = 54317,
    getModem = function()
        ---@diagnostic disable-next-line: return-type-mismatch
        return true, peripheral.wrap("left")
    end
})

print("sending broadcast")
TurtleNet.broadcast("infmine/identityButler")

-- NOTE: functions

local function runModem()
    -- handle the messages in here
    msg = TurtleNet.getMessage()

    if msg.type == "request" then
        if msg.request.type == TurtleNet.REQUEST_TYPE.start_repairTool then
            state = STATE.toolRepair
        elseif msg.request.type == TurtleNet.REQUEST_TYPE.stop_repairTool then
            state = STATE.idle
        elseif msg.request.type == TurtleNet.REQUEST_TYPE.start_refuel then
            state = STATE.refueling
        elseif msg.request.type == TurtleNet.REQUEST_TYPE.stop_refuel then
            state = STATE.idle
        end


        TurtleNet.sendMessage({
            type = "response",
            origin = os.getComputerID(),
            target = msg.origin,
            timestamp = os.epoch("ingame"),
            --- @type messageResponse_t
            response = {
                type = msg.request.type,
                result = false
            }
        })
    end
end


local function runSorter()
    -- cache the state
    local st = state

    print("new state is: " .. st)

    while true do
        if st == STATE.toolRepair then
            -- do nothing
        elseif st == STATE.refueling then
            -- empty buffer until there is nothing
            --- @diagnostic disable-next-line: need-check-nil
            local remoteItems = remoteChest.list()

            if remoteItems[1].name == "quark:charcoal_block" and remoteItems[1].count == 64 then
                -- do nothing
                sleep(1)
            elseif remoteItems[1].name ~= nil then
                -- remove stack there and replace with coal
                remoteChest.pushItems(peripheral.getName(outputChest), 1)
            else
                -- if there are no blocks there, add blocks
                local items = inputChest.list()

                for i, v in pairs(items) do
                    -- if the item is a cell
                    if v.name == "quark:charcoal_block" then
                        -- move to the other chest
                        inputChest.pushItems(peripheral.getName(remoteChest), i)
                        break
                    end
                end
            end
        elseif st == STATE.idle then
            -- empty inventory
            for i = 1, 16, 1 do
                count = turtle.getItemCount(i)
                if count then
                    turtle.select(i)
                    turtle.dropDown()
                end
            end

            -- do nothing
        end
    end
end


-- NOTE: run the tasks
while true do
    -- runModem returns when a message is recieved so we use this to update state
    parallel.waitForAny(runModem, runSorter)
end
