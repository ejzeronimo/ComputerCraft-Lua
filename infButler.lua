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

local quantumStorage = peripheral.wrap("front")

--- @type Inventory
--- @diagnostic disable-next-line: assign-type-mismatch
local aboveChest = peripheral.wrap("ironchest:crystal_chest_1")

--- @type Inventory
--- @diagnostic disable-next-line: assign-type-mismatch
local outputChest = peripheral.wrap("minecraft:chest_1")

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
            -- turn ejecting off
            --- @diagnostic disable: need-check-nil
            if quantumStorage.isEjecting("item") then
                quantumStorage.setEjecting("item", false)
                --- @diagnostic enable: need-check-nil
            end

            -- empty buffer until there is nothing
            --- @diagnostic disable-next-line: need-check-nil
            local item = quantumStorage.getBufferItem()

            if item.name == "minecraft:netherite_pickaxe" and (item.nbt ~= nil and item.nbt.Damage ~= nil) and item.nbt.Damage == 0 then
                -- do nothing
                sleep(1)

                --- @diagnostic disable-next-line: need-check-nil
                item = quantumStorage.getBufferItem()

                if item.name == "minecraft:netherite_pickaxe" then
                    turtle.select(1)
                    turtle.dropDown()

                    turtle.suck()
                    turtle.dropDown()
                end
            elseif item.count == 0 then
                -- add a pickaxe
                local items = aboveChest.list()

                for i, v in pairs(items) do
                    -- if the item is a netherite pickaxe
                    if v.name == "minecraft:netherite_pickaxe" then
                        -- move to the other chest
                        aboveChest.pushItems(peripheral.getName(outputChest), i)
                        break
                    end
                end
            else
                turtle.select(1)
                turtle.dropDown()

                turtle.suck()
                turtle.dropDown()
            end
        elseif st == STATE.refueling then
            -- turn ejecting off
            --- @diagnostic disable: need-check-nil
            if quantumStorage.isEjecting("item") then
                quantumStorage.setEjecting("item", false)
                --- @diagnostic enable: need-check-nil
            end

            -- empty buffer until there is nothing
            --- @diagnostic disable-next-line: need-check-nil
            local item = quantumStorage.getBufferItem()

            if item.name == "mekanism:energy_tablet" and (item.nbt ~= nil and item.nbt.mekData ~= nil and item.nbt.mekData.EnergyContainers[0] ~= nil and item.nbt.mekData.EnergyContainers[0].stored ~= nil) and item.nbt.mekData.EnergyContainers[0].stored == "1000000" then
                -- do nothing
                sleep(1)

                --- @diagnostic disable-next-line: need-check-nil
                item = quantumStorage.getBufferItem()

                if item.name == "mekanism:energy_tablet" then
                    turtle.select(1)
                    turtle.dropDown()

                    turtle.suck()
                    turtle.dropDown()
                end
            elseif item.count == 0 then
                -- add a cell
                local items = aboveChest.list()

                for i, v in pairs(items) do
                    -- if the item is a cell
                    if v.name == "mekanism:energy_tablet" then
                        -- move to the other chest
                        aboveChest.pushItems(peripheral.getName(outputChest), i)
                        break
                    end
                end
            else
                turtle.select(1)
                turtle.dropDown()

                turtle.suck()
                turtle.dropDown()
            end
        elseif st == STATE.idle then
            -- turn ejecting on
            --- @diagnostic disable: need-check-nil
            if not quantumStorage.isEjecting("item") then
                quantumStorage.setEjecting("item", true)
                --- @diagnostic enable: need-check-nil
            end

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
