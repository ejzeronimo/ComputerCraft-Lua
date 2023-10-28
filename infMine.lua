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
        "minecraft:basalt",
        "biomesoplenty:flesh"
    },
    --- @type toolMap_t toolmap to use
    tools = {
        ["modem"] = {
            peripheral = "computercraft:wireless_modem_advanced"
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

                config.mine.direction = vector.new(config.mine.direction.x, config.mine.direction.y,
                    config.mine.direction.z)
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
        -- we don't need this function with this usecase
    end
})

InventoryManager.setConfig({
    blacklist = {
        "computercraft:wireless_modem_advanced",
        "minecraft:diamond_pickaxe",
        "enderstorage:ender_chest"
    },
    scaffolding = config.scaffolding,
    minScaffolding = 16,
    remoteStorage = {
        item = "enderstorage:ender_chest",
        getItems = function()
            ---@as Inventory
            local storage = peripheral.wrap("top")

            ---@diagnostic disable-next-line: need-check-nil
            return storage.list();
        end,
        placeStorage = function()
            local present, info = turtle.inspectUp()

            if info.name ~= "enderstorage:ender_chest" then
                ---@diagnostic disable-next-line: param-type-mismatch
                turtle.select(InventoryManager.findItem("enderstorage:ender_chest"))
                return SafeTurtle.placeUp()
            end

            return true
        end,
        breakStorage = function()
            local success = SafeTurtle.digUp()

            if InventoryManager.findItem("enderstorage:ender_chest") == nil then
                printError("ERROR: Failed to pickup storage")
            end

            return success
        end,
        dropItem = turtle.dropUp,
        suckItem = turtle.suckUp
    }
})


SafeTurtle.setConfig({
    threshold = config.fuelThreshold,
    refuel = function()
        InventoryManager.getNewItem("quark:charcoal_block", function(get, suck)
            local valid, refreshRequest, completeRequest = TurtleNet.client.requestEnergyRefill()
            local items = get()
            local success = false

            -- while we cannot request
            while not valid do
                valid, refreshRequest, completeRequest = refreshRequest()
                sleep(0)
            end

            while not success do
                while items ~= nil and items[1] ~= nil and items[1].name ~= "quark:charcoal_block" do
                    items = get()
                    sleep(0)
                end

                if items ~= nil and items[1] ~= nil and items[1].name == "quark:charcoal_block" then
                    suck()

                    --- @diagnostic disable-next-line: param-type-mismatch
                    turtle.select(InventoryManager.findItem("quark:charcoal_block"))
                    turtle.refuel()
                end

                if turtle.getFuelLevel() >= (turtle.getFuelLimit() * (config.fuelThreshold * 1.1)) then
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
        selectScaffold = ToolChanger.selectScaffold
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

Telemetry.init(function()
        ToolChanger.equipStandardModem()
        return vector.new(gps.locate(2, false))
    end,
    function()
        local x, y, z, x2, y2, z2

        -- get current position
        ToolChanger.equipStandardModem()
        x2, y2, z2 = gps.locate(2, false)

        SafeTurtle.back()

        -- get current position
        ToolChanger.equipStandardModem()
        x, y, z = gps.locate(2, false)

        SafeTurtle.forward()

        return vector.new(x2, y2, z2) - vector.new(x, y, z)
    end)

-- NOTE: the final checks (things to run after configs set), pickup from a potentially dirty restart

-- check the inventory for all the tools we need
for _, value in pairs(config.tools) do
    if InventoryManager.findItem(value.peripheral) ~= nil or ToolChanger.getCurrentTool() == value.peripheral then
        if value.select ~= nil and InventoryManager.findItem(value.select) == nil then
            -- we are missing an item
            printError("ERROR: Missing peripheral item " .. value.select)
            return
        end
    else
        printError("ERROR: Missing peripheral " .. value.peripheral)
        return
    end
end

-- check for remoteStorage
if InventoryManager.findItem("enderstorage:ender_chest") == nil then
    local present, info = turtle.inspectUp()

    if (present and info.name ~= "enderstorage:ender_chest") or not present then
        -- we don't have the remoteStorage
        printError("ERROR: Missing remoteStorage")
        return
    elseif present and info.name == "enderstorage:ender_chest" then
        ToolChanger.equipStandardMine()
        SafeTurtle.digUp()
    end
end

-- if we are not a checkpoint, move to the last one we have
local gPos, gDir, lPos, lDir = Telemetry.atCheckpoint(function()
        ToolChanger.equipStandardModem()
        return vector.new(gps.locate(2, false))
    end,
    function()
        local x, y, z, x2, y2, z2

        -- get current position
        ToolChanger.equipStandardModem()
        x2, y2, z2 = gps.locate(2, false)

        SafeTurtle.back()

        -- get current position
        ToolChanger.equipStandardModem()
        x, y, z = gps.locate(2, false)

        SafeTurtle.forward()

        return vector.new(x2, y2, z2) - vector.new(x, y, z)
    end)

if (not gPos) or (not gDir) or (not lPos) or (not lDir) then
    ToolChanger.equipStandardMine()

    Telemetry.returnToCheckpoint(function()
            ToolChanger.equipStandardModem()
            return vector.new(gps.locate(2, false))
        end,
        function()
            local x, y, z, x2, y2, z2

            -- get current position
            ToolChanger.equipStandardModem()
            x2, y2, z2 = gps.locate(2, false)

            SafeTurtle.back()

            -- get current position
            ToolChanger.equipStandardModem()
            x, y, z = gps.locate(2, false)

            SafeTurtle.forward()

            return vector.new(x2, y2, z2) - vector.new(x, y, z)
        end,
        SafeTurtle.up,
        SafeTurtle.down,
        SafeTurtle.turnLeft,
        SafeTurtle.turnRight,
        SafeTurtle.forward,
        SafeTurtle.back
    )
end

-- cycle tools as a final test
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
    TurtleNet.client.sendCoordinate(Telemetry.relative.getCoord(), { gps.locate(2, false) })
    Telemetry.updateCheckpoint(function()
        return vector.new(gps.locate(2, false))
    end)
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
TurtleNet.client.sendCoordinate(Telemetry.relative.getCoord(), { gps.locate(2, false) })
