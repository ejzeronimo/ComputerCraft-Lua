--[[
    NOTE: chunk controller ALWAYS on the left side

    TODO: add in communication
--]]

local TurtleNet = require("lib.TurtleNet")
local Telemetry = require("lib.Telemetry")
local ToolChanger = require("lib.ToolChanger")
local InventoryManager = require("lib.InventoryManager")
local SafeTurtle = require("lib.SafeTurtle")
local TurtleMine = require("lib.TurtleMine")

-- NOTE: classes and types

--- @class infMineConfig_t
local DefaultConfig = {
    --- the server to target, not implemented
    target = -1,
    --- threshold for the fuel
    fuelThreshold = .6,
    --- the definition of mining dimensions and direction, ignores direction ATM
    mine = Telemetry.Coordinate:new(),
    --- scaffolding items to use
    scaffolding = {
        "minecraft:dirt",
        "minecraft:cobblestone",
        "minecraft:cobbled_deepslate",
        "minecraft:netherrack",
        "biomesoplenty:flesh"
    },
    --- @type toolMap_t toolmap to use
    tools = {
        ["modem"] = {
            peripheral = "computercraft:wireless_modem_advanced"
        },
        ["weakAutomata"] = {
            peripheral = "advancedperipherals:weak_automata_core",
            select = "minecraft:netherite_pickaxe"
        },
        standardMine = {
            peripheral = "minecraft:diamond_pickaxe",
        }
    }
}

-- NOTE: setup
local configPath = "./config.json"

local iterations = 0

--- @type infMineConfig_t
local config = {}

-- if the path is invalid
if not fs.exists(configPath) then
    printError("ERROR: invalid path to config")

    local handle = fs.open(configPath, "w")

    if handle then
        handle.write(textutils.serializeJSON(DefaultConfig))
        handle.close()
    end

    return
else
    local handle = fs.open(configPath, "r")

    if handle then
        local content = handle.readAll()

        if content then
            local result = textutils.unserializeJSON(content)

            if result then
                --- @cast result infMineConfig_t
                config = result

                config.mine.direction = vector.new(config.mine.direction.x, config.mine.direction.y, config.mine.direction.z)
                config.mine.position = vector.new(config.mine.position.x, config.mine.position.y, config.mine.position.z)
            end
        end
    end
end

if not config then
    printError("ERROR: config assignment failed")
    return
end

-- application implementations
TurtleNet.setConfig({
    channel = 54317,
    getModem = function()
        ---@diagnostic disable-next-line: return-type-mismatch
        return ToolChanger.equipStandardModem(), peripheral.wrap("right")
    end
})

ToolChanger.setConfig({
    scaffolding = config.scaffolding,
    toolMap = config.tools,
    getFreeSlot = InventoryManager.getFreeSlot,
    getNewItem = function(n)
        -- really this function is only for the netherite pickaxe
        if n ~= "minecraft:netherite_pickaxe" then
            return
        end

        InventoryManager.getNewItem(n, function(get, suck)
            local valid, refreshRequest, completeRequest = TurtleNet.client.requestToolRepair()
            local items = get()
            local success = false
            local info

            -- while request we cannot
            while not valid do
                valid, refreshRequest, completeRequest = refreshRequest()
                sleep(0)
            end

            while not success do
                while items[1].nbt == nil or items[1].nbt.Damage == nil do
                    items = get()
                    sleep(0)
                end

                if items[1].nbt.Damage == 0 and items[1].name == n then
                    suck()
                end

                info = turtle.getItemDetail(InventoryManager.findItem(n))

                if info then
                    completeRequest()
                    success = true
                else
                    sleep(5)
                end
            end

            ToolChanger.equipStandardMine()
            return success
        end)
    end
})

InventoryManager.setConfig({
    blacklist = {
        "computercraft:wireless_modem_advanced",
        "advancedperipherals:weak_automata_core",
        "minecraft:diamond_pickaxe",
        "minecraft:netherite_pickaxe"
    },
    scaffolding = config.scaffolding,
    minScaffolding = 16,
    remoteStorage = {
        item = "mekanism:quantum_entangloporter",
        getItems = function()
            local storage = peripheral.wrap("top")

            return {
                ---@diagnostic disable-next-line: need-check-nil
                [1] = storage.getBufferItem()
            }
        end,
        placeStorage = function()
            ---@diagnostic disable-next-line: param-type-mismatch
            turtle.select(InventoryManager.findItem("mekanism:quantum_entangloporter"))
            return SafeTurtle.placeUp()
        end,
        breakStorage = SafeTurtle.digUp,
        dropItem = turtle.dropUp,
        suckItem = turtle.suckUp
    }
})


SafeTurtle.setConfig({
    threshold = config.fuelThreshold,
    refuel = function()
        InventoryManager.getNewItem("mekanism:energy_tablet", function(get, suck)
            local valid, refreshRequest, completeRequest = TurtleNet.client.requestEnergyRefill()
            local items = get()
            local success = false
            local info

            -- while request we cannot
            while not valid do
                valid, refreshRequest, completeRequest = refreshRequest()
                sleep(0)
            end

            while not success do
                while items[1].nbt == nil or items[1].nbt.mekData == nil or items[1].nbt.mekData.EnergyContainers[0] == nil or items[1].nbt.mekData.EnergyContainers[0].stored == nil do
                    items = get()
                    sleep(0)
                end

                if items[1].nbt.mekData.EnergyContainers[0].stored == "1000000" and items[1].name == "mekanism:energy_tablet" then
                    suck()
                end

                info = turtle.getItemDetail(InventoryManager.findItem("mekanism:energy_tablet"))

                -- use the tablet to refuel
                if info and ToolChanger.equipTool(config.tools["weakAutomata"]) then
                    local recharge = peripheral.wrap("right")
                    local curCharge = turtle.getFuelLevel()

                    --- @diagnostic disable-next-line: param-type-mismatch
                    turtle.select(InventoryManager.findItem("mekanism:energy_tablet"))

                    --- @diagnostic disable undefined-field
                    while turtle.getFuelLevel() < (turtle.getFuelLimit() * (config.fuelThreshold * 1.1)) and (recharge and recharge.chargeTurtle) do
                        curCharge = turtle.getFuelLevel()
                        recharge.chargeTurtle()
                        --- @diagnostic enable: undefined-field

                        if curCharge == turtle.getFuelLevel() then
                            -- ran out of charge, get a new unit
                            break
                        end
                    end
                end

                turtle.dropUp()

                if turtle.getFuelLevel() == turtle.getFuelLimit() then
                    completeRequest()
                    success = true
                else
                    sleep(5)
                end
            end

            ToolChanger.equipStandardMine()
            return success
        end)
    end,
    getEmptySlot = InventoryManager.getFreeSlot,
    toolChanger = {
        selectScaffold = ToolChanger.selectScaffold,
        breakSilk = function(name)
            local result, err, auto

            -- make sure we have a free spot
            InventoryManager.getFreeSlot()
            ToolChanger.checkTool(config.tools["weakAutomata"], .1);

            -- try to equip the silk mine
            if ToolChanger.equipTool(config.tools["weakAutomata"]) then
                auto = peripheral.wrap("right")

                -- HACK: workaround to get digBlock to work()
                ---@diagnostic disable-next-line: need-check-nil
                result, err = pcall(auto.digBlock)

                while not result do
                    ---@diagnostic disable-next-line: need-check-nil
                    result = pcall(auto.digBlock)
                end

                ---@diagnostic disable-next-line: need-check-nil
                result = result and auto.collectSpecificItem(name)

                ToolChanger.equipStandardMine();
            end

            return result
        end
    },
    telemetry = {
        forward = Telemetry.relative.forward,
        back = Telemetry.relative.back,
        up = Telemetry.relative.up,
        down = Telemetry.relative.down,
        turnLeft = Telemetry.relative.leftTurn,
        turnRight = Telemetry.relative.rightTurn,
    }
})

TurtleMine.setConfig({
    getCoordinate = Telemetry.relative.getCoord,
    stopFluid = SafeTurtle.stopFluid,
    dig = {
        dig = SafeTurtle.dig,
        digUp = SafeTurtle.digUp,
        digDown = SafeTurtle.digDown
    },
    movement = {
        forward = SafeTurtle.forward,
        back = SafeTurtle.back,
        up = SafeTurtle.up,
        down = SafeTurtle.down,
        turnLeft = SafeTurtle.turnLeft,
        turnRight = SafeTurtle.turnRight,
    }
})


-- NOTE: the final checks (things to run after configs set)

-- cycle tools as a test
ToolChanger.equipTool(config.tools["weakAutomata"])
print(ToolChanger.getCurrentTool())
sleep(1)
ToolChanger.equipStandardModem()
print(ToolChanger.getCurrentTool())
sleep(1)
ToolChanger.equipStandardMine()
print(ToolChanger.getCurrentTool())

print("Initial checks past")

-- NOTE: the main loop
-- until we get the stop message
while true do
    ToolChanger.equipStandardModem()
    TurtleNet.client.sendCoordinate(Telemetry.relative.getCoord(), { gps.locate() })
    ToolChanger.equipStandardMine()

    for h = 1, config.mine.position.y, 2 do
        for w = 1, config.mine.position.x, 1 do
            for l = 1, (config.mine.position.z - 1), 1 do
                -- dig the block in front
                TurtleMine.smartDig(h, config.mine.position.y)

                -- move forward
                SafeTurtle.forward()
            end

            --at end of column
            if w <= (config.mine.position.x - 1) then
                TurtleMine.uTurn(w, h, config.mine.position.y)
            end
        end

        -- last block in level
        if h <= (config.mine.position.y - 1) then
            SafeTurtle.digDown()
        end

        -- at end of level
        if h < (config.mine.position.y - 1) then
            TurtleMine.moveDown(config.mine.position.x)
            h = h + 1
        end
    end

    iterations = iterations + 1
    TurtleMine.moveToNextChunk(config.mine.direction, config.mine.position.z, iterations)
end

-- NOTE: after the stop message was received
ToolChanger.equipStandardModem()
TurtleNet.client.sendCoordinate(Telemetry.relative.getCoord(), { gps.locate() })
