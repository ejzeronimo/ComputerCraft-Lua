--[[
    TODO: finish equipment change

    TODO: finish turtle recharge'

    TODO: add in communication

    TODO: add in config file use

    TODO: add in commuication thread
--]]

local TurtleNet = require("lib.TurtleNet")
local Telemetry = require("lib.Telemetry")
local ToolChanger = require("lib.ToolChanger")
local InventoryManager = require("lib.InventoryManager")
local SafeTurtle = require("lib.SafeTurtle")
local TurtleMine = require("lib.TurtleMine")

-- NOTE: classes and types

Config = {
    target = "",
    mine = Telemetry.Coordinate:new(),
    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        return o
    end
}

-- NOTE: globals
local configPath = "./mine.json"
local configFile = nil
local config = Config:new()

local height = 4
local length = 4
local width = 4

local scaffolds = {
    "minecraft:dirt",
    "minecraft:cobblestone",
    "minecraft:cobbled_deepslate",
    "minecraft:netherrack",
    "biomesoplenty:flesh"
}

--- @type toolMap_t
local tools = {
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

-- application implementations
TurtleNet.setConfig({
    channel = 54317,
    getModem = function()
        ---@diagnostic disable-next-line: return-type-mismatch
        return ToolChanger.equipStandardModem(), peripheral.wrap("right")
    end
})

ToolChanger.setConfig({
    scaffolding = scaffolds,
    toolMap = tools,
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
                while items[1].nbt.Damage ~= 0 and items[1].name ~= n do
                    items = get()
                    sleep(0)
                end

                suck()

                info = turtle.getItemDetail(InventoryManager.findItem(n))

                if info then
                    completeRequest()
                    success = true
                else
                    sleep(5)
                end
            end

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
    scaffolding = scaffolds,
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
    threshold = .1,
    refuel = function()
        -- FIXME:

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
                while items[1].nbt.mekData.EnergyContainers[0].stored < 1000000 and items[1].name ~= "mekanism:energy_tablet" do
                    items = get()
                    sleep(0)
                end

                suck()

                info = turtle.getItemDetail(InventoryManager.findItem("mekanism:energy_tablet"))

                if info then
                    completeRequest()
                    success = true
                else
                    sleep(5)
                end
            end

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

            -- try to equip the silk mine
            if ToolChanger.equipTool(tools["weakAutomata"]) then
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
                ToolChanger.checkTool(tools["weakAutomata"], .1);
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


-- NOTE: functions



-- NOTE: the setup
-- if the path is invalid
if not fs.exists(configPath) then
    printError("ERROR: invalid path to config")
    --return
end

-- chunk controller ALWAYS on the left side

-- purge the current peripheral if it is there
if peripheral.isPresent("right") then
end

ToolChanger.equipTool(tools["weakAutomata"])
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
-- while true do
for h = 1, height, 2 do
    for w = 1, width, 1 do
        for l = 1, (length - 1), 1 do
            -- dig the block in front
            TurtleMine.smartDig(h, height)

            -- move forward
            SafeTurtle.forward()
        end

        --at end of column
        if w <= (width - 1) then
            TurtleMine.uTurn(w, h, height)
        end
    end

    -- last block in level
    if h <= (height - 1) then
        SafeTurtle.digDown()
    end

    -- at end of level
    if h < (height - 1) then
        TurtleMine.moveDown(width)
        h = h + 1
    end
end

TurtleMine.moveToNextChunk(length)
-- end

-- NOTE: after the stop message was received
