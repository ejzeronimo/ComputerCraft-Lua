--[[
    TODO: finish equipment change

    TODO: finish turtle recharge'

    TODO: add in communication

    TODO: add in config file use

    TODO: add in commuication thread

    FIXME:
    TODO: decouple function libs
--]]


local TurtleNet = require("lib.TurtleNet")
local Telemetry = require("lib.Telemetry")
local ToolChanger = require("lib.ToolChanger")
local InventoryManager = require("lib.InventoryManager")

-- NOTE: application implementations
TurtleNet.setConfig({
    channel = 543178,
    getModem = function()
        ---@diagnostic disable-next-line: return-type-mismatch
        return ToolChanger.equipStandardModem(), peripheral.wrap("right")
    end
})

ToolChanger.setConfig({
    scaffolding = {
        "minecraft:dirt",
        "minecraft:cobblestone",
        "minecraft:cobbled_deepslate",
        "minecraft:netherrack",
        "biomesoplenty:flesh"
    },
    toolMap = {
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
    },
    getFreeSlot = InventoryManager.getFreeSlot,
    getNewItem = function()
        -- FIXME: implement this
    end
})

InventoryManager.setConfig({})

-- NOTE: classes and objects

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

-- NOTE: functions
-- functions for managing the inventory
local inventoryManager = {
    -- --- checks to see if there is a free slot in the turtle
    -- --- @param name? string name of the item to check for
    -- ensureFreeSlot = function(name)
    --     for i = 1, 16, 1 do
    --         local count = turtle.getItemCount(i)
    --         local space = turtle.getItemSpace(i)
    --         local data = turtle.getItemDetail(i)

    --         if count and data and name then
    --             if data.name == name and space ~= 0 then
    --                 return
    --             end
    --         elseif count == 0 then
    --             return
    --         end
    --     end

    --     -- empty inventory if we hit this point
    --     inventoryManager.emptyInventory()
    -- end,
    -- refuelEnergy = function()
    --     local curTool = ToolChanger.getCurrentTool()

    --     -- TODO: get fuel
    --     -- "mekanism:energy_tablet"
    --     -- inspect.nbt.mekData.EnergyContainers[0].stored ~= 1000000

    --     -- equip pickaxe
    --     if curTool ~= "minecraft:diamond_pickaxe" then
    --         ToolChanger.equipStandardMine()
    --     end

    --     safeTurtle.digUp()

    --     -- TODO: change tool back
    -- end,
}

--- functions with smart and fallback modes built in, extension of the turtle api
local safeTurtle = {
    --- move the turtle forward
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    forward = function()
        return safeTurtle.__move(turtle.forward, safeTurtle.dig, Telemetry.relative.forward)
    end,
    --- move the turtle backward
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    back = function()
        local function d()
            safeTurtle.right()
            safeTurtle.right()

            safeTurtle.dig()

            safeTurtle.right()
            safeTurtle.right()
        end

        return safeTurtle.__move(turtle.back, d, Telemetry.relative.back)
    end,
    --- move the turtle up
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    up = function()
        return safeTurtle.__move(turtle.up, safeTurtle.digUp, Telemetry.relative.up)
    end,
    --- move the turtle down
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    down = function()
        return safeTurtle.__move(turtle.down, safeTurtle.digDown, Telemetry.relative.down)
    end,
    --- rotate the turtle left
    left = function()
        turtle.turnLeft()
        Telemetry.relative.leftTurn()
    end,
    --- rotate the turtle right
    right = function()
        turtle.turnRight()
        Telemetry.relative.rightTurn()
    end,
    --- dig in front of the turtle
    --- @return boolean success if a block was broken
    --- @return string|nil errorMessage the reason no block was broken
    dig = function()
        local present, data = turtle.inspect()

        -- if this is an ore and not ancient debris
        if present and data.tags["forge:ores"] and data.name ~= "minecraft:ancient_debris" then
            local result = false

            -- make sure we have a free spot
            inventoryManager.ensureFreeSlot(data.name)

            -- try to equip the silk mine
            if ToolChanger.equipSilkMine() then
                local auto = peripheral.wrap("right")

                -- HACK: workaround to get digBlock to work()
                ---@diagnostic disable-next-line: need-check-nil
                result, err = pcall(auto.digBlock)

                while not result do
                    ---@diagnostic disable-next-line: need-check-nil
                    result = pcall(auto.digBlock)
                end

                ---@diagnostic disable-next-line: need-check-nil
                result = result and auto.collectSpecificItem(data.name)

                ToolChanger.equipStandardMine();
                ToolChanger.checkSilk();
            end

            return result
        end

        -- just a normal dig
        return safeTurtle.__dig(turtle.dig, turtle.inspect)
    end,
    --- dig above the turtle
    --- @return boolean success if a block was broken
    --- @return string|nil errorMessage the reason no block was broken
    digUp = function()
        return safeTurtle.__dig(turtle.digUp, turtle.inspectUp)
    end,
    --- dig below the turtle
    --- @return boolean success if a block was broken
    --- @return string|nil errorMessage the reason no block was broken
    digDown = function()
        return safeTurtle.__dig(turtle.digDown, turtle.inspectDown)
    end,
    --- place a block in front
    --- @param text? string text to put on a sign
    --- @return boolean success if a block was placed
    --- @return string|nil errorMessage the reason no block was placed
    place = function(text)
        return safeTurtle.__place(turtle.place, turtle.inspect, text)
    end,
    --- place a block above
    --- @param text? string text to put on a sign
    --- @return boolean success if a block was placed
    --- @return string|nil errorMessage the reason no block was placed
    placeUp = function(text)
        return safeTurtle.__place(turtle.placeUp, turtle.inspectUp, text)
    end,
    --- place a block below
    --- @param text? string text to put on a sign
    --- @return boolean success if a block was placed
    --- @return string|nil errorMessage the reason no block was placed
    placeDown = function(text)
        return safeTurtle.__place(turtle.placeDown, turtle.inspectDown, text)
    end,
    --- function that checks for fluid in front of and above turtle. Places blocks to remove them
    stopFluid = function()
        -- check for fluids above us
        local present, info = turtle.inspectUp()
        local reset

        if present and info.state.level ~= nil then
            reset = ToolChanger.selectScaffold()

            safeTurtle.placeUp()

            reset()
        end

        -- check for fluids in front of us
        present, info = turtle.inspect()

        if present and info.state.level ~= nil then
            reset = ToolChanger.selectScaffold()

            safeTurtle.place()

            reset()
        end
    end,
    --- function to check the fuel level and handle refuel call
    checkFuel = function()
        if turtle.getFuelLevel < (turtle.getFuelLimit() * .01) then
            inventoryManager.refuelEnergy()
        end
    end,
    --- private move function
    --- @param m function the directional move function to invoke
    --- @param d function the directional dig function to invoke
    --- @param t function the directional telemetry function to invoke
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    __move = function(m, d, t)
        local success, reason = m()
        local fail = 0

        while not success and fail < 3 do
            -- try to mine, there might be a block
            d()
            success, reason = m()

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not move, reason: " .. reason)

            return false, reason
        end

        -- check fuel state
        safeTurtle.checkFuel()

        t()
        return true
    end,
    --- private dig function
    --- @param d function the directional dig function to invoke
    --- @param i function the directional inspect function to invoke
    --- @return boolean success if a block was broken
    --- @return string|nil errorMessage the reason no block was broken
    __dig = function(d, i)
        local success, reason = d()
        local present, info = i()
        local retry = 0

        -- make sure we have a free spot
        inventoryManager.ensureFreeSlot(info.name)

        while (present and info.state.level == nil) and retry < 32 do
            -- mine the block
            success, reason = d()
            -- then check if it is still there
            present, info = i()

            retry = retry + 1
            sleep(0)
        end

        -- we failed, print an error
        if retry == 32 then
            printError("ERROR: could not break block " .. info.name .. ", reason: " .. reason)

            return false, reason
        end

        return true
    end,
    --- private place function
    --- @param p function the directional place function to invoke
    --- @param i function the directional inspect function to invoke
    --- @param t? string text to pass to the place function
    --- @return boolean success if a block was placed
    --- @return string|nil errorMessage the reason no block was placed
    __place = function(p, i, t)
        local present, info = i()
        local success, reason = p(t)
        local fail = 0

        while (not success and present) and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.dig()

            -- retry the place
            present, info = i()
            success, reason = p(t)

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not place block, reason: " .. reason)

            return false, reason
        end

        return true
    end,
}

---  functions to help with the mining of a cubic volume
local turtleMine = {
    --- hidden variable for the state of the uturn
    __isTurnLeft = false,
    --- function to dig, stops potential fluids and mines below to save fuel
    --- @param h number the current height of the turtle relative to the mining area
    smartDig = function(h)
        -- check for fluids
        safeTurtle.stopFluid()

        -- dig in front for the move
        safeTurtle.dig()

        if h <= (height - 1) then
            -- if we have more one more layer below us, dig below
            safeTurtle.digDown()
        end
    end,
    --- function to turn around and start new line for mining, is "safe"
    --- @param w number the current horizontal distance into the mining area
    --- @param h number the current height of the turtle relative to the mining area
    uTurn = function(w, h)
        local result = math.fmod(w, 2) == 0
        if turtleMine.__isTurnLeft then
            result = not result
        end

        safeTurtle.stopFluid()
        -- if even or odd
        if result then
            safeTurtle.left()
        else
            safeTurtle.right()
        end

        turtleMine.smartDig(h)
        safeTurtle.forward()

        safeTurtle.stopFluid()
        -- if even or odd
        if result then
            safeTurtle.left()
        else
            safeTurtle.right()
        end
    end,
    --- function to move to the next horizontal slice, is "safe"
    moveDown = function()
        -- check for fluids
        safeTurtle.stopFluid()

        safeTurtle.digDown()
        safeTurtle.down()
        safeTurtle.digDown()
        safeTurtle.down()
        safeTurtle.right()
        safeTurtle.right()

        if math.fmod(width, 2) == 0 and turtleMine.__isTurnLeft == false then
            turtleMine.__isTurnLeft = true
        else
            turtleMine.__isTurnLeft = false
        end
    end
}

--- unique function meant to find the next chunk based off of current location
function moveToNextChunk()
    -- local position of end point
    local targetRelativePosition = vector.new(0, 0, 1) * length

    print("target is: " .. tostring(targetRelativePosition))

    -- move in the Y direction first
    --- @diagnostic disable-next-line: undefined-field
    local yDifference = targetRelativePosition.y - Telemetry.relative.localCoord.position.y

    while yDifference ~= 0 do
        if yDifference > 0 then
            safeTurtle.up()
        else
            safeTurtle.down()
        end

        --- @diagnostic disable-next-line: undefined-field
        yDifference = targetRelativePosition.y - Telemetry.relative.localCoord.position.y
    end

    -- move in the X direction now
    --- @diagnostic disable: undefined-field
    local xDifference = targetRelativePosition.x - Telemetry.relative.localCoord.position.x
    local xHeading = xDifference / (xDifference == 0 and 1 or xDifference)
    --- @diagnostic enable: undefined-field

    if xDifference ~= 0 then
        -- need to get the heading and change it
        --- @diagnostic disable-next-line: undefined-field
        while Telemetry.relative.localCoord.direction.x ~= xHeading do
            safeTurtle.left()
        end

        -- then make the move
        while xDifference ~= 0 do
            safeTurtle.forward()

            --- @diagnostic disable-next-line: undefined-field
            xDifference = targetRelativePosition.x - Telemetry.relative.localCoord.position.x
        end
    end

    -- move in the X direction now
    --- @diagnostic disable: undefined-field
    local zDifference = targetRelativePosition.z - Telemetry.relative.localCoord.position.z
    local zHeading = zDifference / (zDifference == 0 and 1 or zDifference)
    --- @diagnostic enable: undefined-field

    if zDifference ~= 0 then
        -- need to get the heading and change it
        --- @diagnostic disable-next-line: undefined-field
        while Telemetry.relative.localCoord.direction.z ~= zHeading do
            safeTurtle.right()
        end

        -- then make the move
        while zDifference ~= 0 do
            safeTurtle.forward()

            --- @diagnostic disable-next-line: undefined-field
            zDifference = targetRelativePosition.z - Telemetry.relative.localCoord.position.z
        end
    end

    print("location is: " .. tostring(Telemetry.relative.localCoord))
end

function fuelTurtle()
    turtle.select(1)
    turtle.digUp()
    turtle.placeUp()
    turtle.suckUp(16)
    turtle.refuel()
    turtle.digUp()
    modem.transmit(3, 1, os.getComputerLabel() .. " turtle refueled " .. os.clock())
end

function checkTurtle()
    --check the fuel level and inv fullness
    if turtle.getFuelLevel() < 30 then
        fuelTurtle()
    end

    num = 0
    for i = 1, 16, 1 do
        if turtle.getItemCount(i) > 0 then
            num = num + 1
        end
    end

    if num > 12 then
        purgeInventory()
    end

    turtle.select(1)
end

-- NOTE: globals
configPath = "./mine.json"
configFile = nil
config = Config:new()

height = 4
length = 4
width = 4

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

ToolChanger.equipSilkMine()
print(ToolChanger.getCurrentTool())
sleep(1)
ToolChanger.equipModem()
print(ToolChanger.getCurrentTool())
sleep(1)
ToolChanger.equipStandardMine()
print(ToolChanger.getCurrentTool())

print("Initial checks past")



-- NOTE: the main loop
-- until we get the stop message
--while true do
for h = 1, height, 2 do
    for w = 1, width, 1 do
        for l = 1, (length - 1), 1 do
            -- dig the block in front
            turtleMine.smartDig(h)

            -- move forward
            safeTurtle.forward()
        end

        --at end of column
        if w <= (width - 1) then
            turtleMine.uTurn(w, h)
        end
    end

    -- last block in level
    if h <= (height - 1) then
        safeTurtle.digDown()
    end

    -- at end of level
    if h < (height - 1) then
        turtleMine.moveDown()
        h = h + 1
    end
end

moveToNextChunk()
-- end

-- NOTE: after the stop message was received
