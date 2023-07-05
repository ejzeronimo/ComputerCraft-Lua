--[[
    TODO: finish equipment change

    TODO: finish turtle recharge'

    TODO: add in communication

    TODO: add in config file use

    TODO: add in commuication thread

    TODO: decouple function libs
--]]


TurtleNet = require("lib.TurtleNet")
Telemetry = require("lib.Telemetry")

-- NOTE: application implementations

local function getModem()
    return toolChanger.equipModem(), peripheral.wrap("right")
end

TurtleNet.setGetModem(getModem)

-- NOTE: classes and objects

--- @class Coordinate
Coordinate = {
    position = vector.new(0, 0, 0),
    direction = vector.new(0, 0, 0),
    __tostring = function(self)
        return "position: " .. tostring(self.position) .. " heading: " .. tostring(self.direction)
    end,
    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self

        if o.position == nil then
            o.position = vector.new(0, 0, 0)
        end

        if o.direction == nil then
            o.direction = vector.new(0, 0, 0)
        end

        return o
    end
}

Config = {
    target = "",
    mine = Coordinate:new(),
    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
        return o
    end
}

-- NOTE: functions

--- the position information about the turtle, decoupled
turtleTelemetry = {
    --- coordinate relative to where the turtle was first placed
    --- @type Coordinate
    localCoord = Coordinate:new({
        position = vector.new(0, 0, 0),
        direction = vector.new(0, 0, 1)
    }),
    --- function to update the local position forward one block
    forward = function()
        turtleTelemetry.localCoord.position = turtleTelemetry.localCoord.position + turtleTelemetry.localCoord.direction
    end,
    --- function to update the local position backward one block
    back = function()
        turtleTelemetry.localCoord.position = turtleTelemetry.localCoord.position - turtleTelemetry.localCoord.direction
    end,
    --- function to update the local position to face left 90 degress
    left = function()
        turtleTelemetry.localCoord.direction = vector.new(
        --- @diagnostic disable: undefined-field
            turtleTelemetry.localCoord.direction.x * math.cos(-math.pi / 2) +
            turtleTelemetry.localCoord.direction.z * math.sin(-math.pi / 2),
            turtleTelemetry.localCoord.direction.y,
            -turtleTelemetry.localCoord.direction.x * math.sin(-math.pi / 2) +
            turtleTelemetry.localCoord.direction.z * math.cos(-math.pi / 2)
        --- @diagnostic enable: undefined-field
        )

        turtleTelemetry.localCoord.direction = turtleTelemetry.localCoord.direction:round()
    end,
    --- function to update the local position to face right 90 degress
    right = function()
        turtleTelemetry.localCoord.direction = vector.new(
        --- @diagnostic disable: undefined-field
            turtleTelemetry.localCoord.direction.x * math.cos(math.pi / 2) +
            turtleTelemetry.localCoord.direction.z * math.sin(math.pi / 2),
            turtleTelemetry.localCoord.direction.y,
            -turtleTelemetry.localCoord.direction.x * math.sin(math.pi / 2) +
            turtleTelemetry.localCoord.direction.z * math.cos(math.pi / 2)
        --- @diagnostic enable: undefined-field
        )

        turtleTelemetry.localCoord.direction = turtleTelemetry.localCoord.direction:round()
    end,
    --- function to update the local position upward one block
    up = function()
        turtleTelemetry.localCoord.position = turtleTelemetry.localCoord.position + vector.new(0, 1, 0)
    end,
    --- function to update the local position downward one block
    down = function()
        turtleTelemetry.localCoord.position = turtleTelemetry.localCoord.position + vector.new(0, -1, 0)
    end,
}

-- functions for managing the inventory
inventoryManager = {
    --- get a free slot in the turtle
    --- @return number|nil index returns a number if successful or nil if failed
    getFreeSlot = function()
        for i = 1, 16, 1 do
            local result = turtle.getItemCount(i)
            if result == 0 then
                return i
            end
        end
        return nil
    end,
    --- empties the inventory
    emptyInventory = function()
        local hasScaffold = false
        local blacklist = {
            "mekanism:quantum_entangloporter",
            "minecraft:diamond_pickaxe",
            "minecraft:netherite_pickaxe",
            "advancedperipherals:weak_automata_core",
            "computercraft:wireless_modem_advanced"
        }

        --- function to check if in a list
        --- @param arr string[] array of items to search
        --- @param val string the name to check for
        --- @return boolean inList if the item is in the list
        local function inList(arr, val)
            for index, value in ipairs(arr) do
                -- we grab the first index of our sub-table instead
                if value == val then
                    return true
                end
            end

            return false
        end

        inventoryManager.__placeStorage()

        -- TODO: make this ask for permission first

        -- go through and empty inventory
        for j = 1, 16, 1 do
            local item = turtle.getItemDetail(j)
            -- if not a tool
            if item and not inList(blacklist, item.name) then
                if inList(toolChanger.__scaffolding, item.name) and (not hasScaffold and item.count >= 16) then
                    -- do nothing
                    hasScaffold = true
                else
                    -- try to put it in the entangloporter
                    turtle.select(j)
                    local success, error = turtle.dropUp()

                    while not success and error == "no space for items" do
                        -- sleep for a bit
                        sleep(.5)
                    end
                end
            end
        end

        -- since this can be called anywhere in the code, we need to ensure that the right tool is on
        local tool = toolChanger.getCurrentTool()

        toolChanger.equipStandardMine()
        safeTurtle.digUp()

        switch = {
            ["modem"] = function()
                toolChanger.equipModem()
            end,
            ["weakAutomata"] = function()
                toolChanger.equipSilkMine()
            end,
            ["minecraft:diamond_pickaxe"] = function()
                -- do nothing
            end,
        }

        switch[tool]()
    end,
    --- checks to see if there is a free slot in the turtle
    --- @param name? string name of the item to check for
    ensureFreeSlot = function(name)
        for i = 1, 16, 1 do
            local count = turtle.getItemCount(i)
            local space = turtle.getItemSpace(i)
            local data = turtle.getItemDetail(i)

            if count and data and name then
                if data.name == name and space ~= 0 then
                    return
                end
            elseif count == 0 then
                return
            end
        end

        -- empty inventory if we hit this point
        inventoryManager.emptyInventory()
    end,
    getNewTool = function()
        local success = false
        local curTool = toolChanger.getCurrentTool()

        -- put down the remote storage
        inventoryManager.__placeStorage()

        -- get it as a peripheral
        local remote = peripheral.wrap("top")

        -- select the pickaxe
        for i = 1, 16, 1 do
            local data = turtle.getItemDetail(i)
            if data and data.name == "minecraft:netherite_pickaxe" then
                turtle.select(i)
                break
            end
        end

        -- just in case we have the wrong item
        while not success do
            -- request tool fix
            local valid, refreshRequest, completeRequest = TurtleNet.client.requestToolRepair()

            -- while we cannot
            while not valid do
                valid, refreshRequest, completeRequest = refreshRequest()
                sleep(0)
            end

            turtle.dropUp()

            -- while there is not a pickaxe with full health
            ---@diagnostic disable-next-line: need-check-nil
            local info = remote.getBufferItem()

            while info.nbt.Damage ~= 0 and info.name ~= "minecraft:netherite_pickaxe" do
                ---@diagnostic disable-next-line: need-check-nil
                info = remote.getBufferItem()
                sleep(0)
            end

            turtle.suckUp()

            local data = turtle.getItemDetail(turtle.getSelectedSlot())

            if data and data.name == "minecraft:netherite_pickaxe" then
                completeRequest()

                success = true
            else
                sleep(5)
            end
        end

        -- equip pickaxe
        if curTool ~= "minecraft:diamond_pickaxe" then
            toolChanger.equipStandardMine()
        end

        safeTurtle.digUp()

        -- TODO: change tool back
    end,
    refuelEnergy = function()
        local curTool = toolChanger.getCurrentTool()

        -- TODO: get fuel
        -- "mekanism:energy_tablet"
        -- inspect.nbt.mekData.EnergyContainers[0].stored ~= 1000000

        -- equip pickaxe
        if curTool ~= "minecraft:diamond_pickaxe" then
            toolChanger.equipStandardMine()
        end

        safeTurtle.digUp()

        -- TODO: change tool back
    end,
    __placeStorage = function()
        -- place entangloporter
        for i = 1, 16, 1 do
            local data = turtle.getItemDetail(i)
            if data and data.name == "mekanism:quantum_entangloporter" then
                turtle.select(i)
                safeTurtle.placeUp()
                break
            end
        end
    end
}

--- functions to swap what the turtle is using / holding
toolChanger = {
    --- array of blocks accepted as scaffolding
    __scaffolding = {
        "minecraft:dirt",
        "minecraft:cobblestone",
        "minecraft:cobbled_deepslate",
        "minecraft:netherrack",
        "biomesoplenty:flesh"
    },
    --- function to selct a block that can be used for scaffolding
    --- @return function reset a function to reset the slot to where it was
    selectScaffold = function()
        local oldSelect = turtle.getSelectedSlot()

        -- for each turtle slot
        for i = 1, 16, 1 do
            local data = turtle.getItemDetail(i)

            for j, v in ipairs(toolChanger.__scaffolding) do
                if data and data.name == v then
                    turtle.select(i)
                    break
                end
            end
        end

        return function()
            turtle.select(oldSelect)
        end
    end,
    --- gives the current tool being used
    --- @return string name name of the tool being used or reason for failure
    getCurrentTool = function()
        if peripheral.getType("right") ~= nil then
            return peripheral.getType("right")
        end

        inventoryManager.ensureFreeSlot()
        local slot = inventoryManager.getFreeSlot()

        if slot then
            turtle.select(slot)

            turtle.equipRight()
            local item = turtle.getItemDetail()
            turtle.equipRight()

            return (item ~= nil and item.name or "none")
        end

        return "none"
    end,
    --- function to equip a standard diamond pickaxe
    --- @return boolean success result of the operation
    equipStandardMine = function()
        local oldSlot = turtle.getSelectedSlot()
        local toolSlot = -1

        -- if it is already equipped
        if toolChanger.getCurrentTool() == "minecraft:diamond_pickaxe" then
            return true
        end

        -- for each turtle slot
        for i = 1, 16, 1 do
            local data = turtle.getItemDetail(i)
            if data and data.name == "minecraft:diamond_pickaxe" then
                toolSlot = i
                break
            end
        end

        inventoryManager.ensureFreeSlot()
        local slot = inventoryManager.getFreeSlot()

        if slot and toolSlot ~= -1 then
            turtle.select(slot)
            turtle.equipRight()

            ---@diagnostic disable-next-line: param-type-mismatch
            turtle.select(toolSlot)
            turtle.equipRight()

            turtle.select(oldSlot)

            return true
        end

        -- if it can't be found
        printError("ERROR: tool not found")
        turtle.select(oldSlot)
        return false
    end,
    --- function to equip a automata core and silk pickaxe
    --- @return boolean success result of the operation
    equipSilkMine = function()
        local toolSlot = -1
        local itemSlot = -1
        local peripheralCorrect = toolChanger.getCurrentTool() == "weakAutomata"
        local curSlotName = turtle.getItemDetail(turtle.getSelectedSlot())
        local slotCorrect = (curSlotName and curSlotName.name or "") == "minecraft:netherite_pickaxe"

        -- if it is already equipped
        if peripheralCorrect and slotCorrect then
            return true
        end

        -- if we need to change peripheral
        if not peripheralCorrect then
            -- for each turtle slot
            for i = 1, 16, 1 do
                local data = turtle.getItemDetail(i)
                if data and data.name == "advancedperipherals:weak_automata_core" then
                    toolSlot = i
                    break
                end
            end

            local slot = inventoryManager.getFreeSlot()
            if slot and toolSlot ~= -1 then
                turtle.select(slot)
                turtle.equipRight()

                ---@diagnostic disable-next-line: param-type-mismatch
                turtle.select(toolSlot)
                turtle.equipRight()

                peripheralCorrect = true
            end
        end

        -- for each turtle slot
        for i = 1, 16, 1 do
            local data = turtle.getItemDetail(i)
            if data and data.name == "minecraft:netherite_pickaxe" then
                itemSlot = i
                break
            end
        end

        inventoryManager.ensureFreeSlot()
        local slot = inventoryManager.getFreeSlot()

        if slot and itemSlot ~= -1 then
            -- move item in first slot out of the way
            if itemSlot ~= 1 then
                turtle.select(1)
                turtle.transferTo(slot)
            end

            ---@diagnostic disable-next-line: param-type-mismatch
            turtle.select(itemSlot)

            if itemSlot ~= 1 then
                turtle.transferTo(1)
                turtle.select(1)
            end

            slotCorrect = true
        end

        if slotCorrect and peripheralCorrect then
            return true
        end

        -- if it can't be found
        printError("ERROR: silk tool and peripheral not found")
        return false
    end,
    --- function to check the durability of the pickaxe, will replace if nessecary
    checkSilk = function()
        local data

        -- get the data for the netherite pickaxe
        for i = 1, 16, 1 do
            data = turtle.getItemDetail(i, true)
            if data and data.name == "minecraft:netherite_pickaxe" then
                break
            end
        end

        ---@diagnostic disable-next-line: undefined-field
        if data and data.durability < .1 then
            inventoryManager.getNewTool()
        end
    end,
    --- function to equip the network modem
    --- @return boolean success result of the operation
    equipModem = function()
        local oldSlot = turtle.getSelectedSlot()
        local toolSlot = -1

        -- if it is already equipped
        if toolChanger.getCurrentTool() == "modem" then
            return true
        end

        -- for each turtle slot
        for i = 1, 16, 1 do
            local data = turtle.getItemDetail(i)
            if data and data.name == "computercraft:wireless_modem_advanced" then
                toolSlot = i
                break
            end
        end

        local slot = inventoryManager.getFreeSlot()
        if slot and toolSlot ~= -1 then
            turtle.select(slot)
            turtle.equipRight()

            ---@diagnostic disable-next-line: param-type-mismatch
            turtle.select(toolSlot)
            turtle.equipRight()

            turtle.select(oldSlot)

            return true
        end

        -- if it can't be found
        printError("ERROR: modem not found")
        turtle.select(oldSlot)
        return false
    end,
}

--- functions with smart and fallback modes built in, extension of the turtle api
safeTurtle = {
    --- move the turtle forward
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    forward = function()
        return safeTurtle.__move(turtle.forward, safeTurtle.dig, turtleTelemetry.forward)
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

        return safeTurtle.__move(turtle.back, d, turtleTelemetry.back)
    end,
    --- move the turtle up
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    up = function()
        return safeTurtle.__move(turtle.up, safeTurtle.digUp, turtleTelemetry.up)
    end,
    --- move the turtle down
    --- @return boolean success if move was successful
    --- @return string|nil errorMessage the reason no move was made
    down = function()
        return safeTurtle.__move(turtle.down, safeTurtle.digDown, turtleTelemetry.down)
    end,
    --- rotate the turtle left
    left = function()
        turtle.turnLeft()
        turtleTelemetry.left()
    end,
    --- rotate the turtle right
    right = function()
        turtle.turnRight()
        turtleTelemetry.right()
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
            if toolChanger.equipSilkMine() then
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

                toolChanger.equipStandardMine();
                toolChanger.checkSilk();
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
            reset = toolChanger.selectScaffold()

            safeTurtle.placeUp()

            reset()
        end

        -- check for fluids in front of us
        present, info = turtle.inspect()

        if present and info.state.level ~= nil then
            reset = toolChanger.selectScaffold()

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
turtleMine = {
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
    local yDifference = targetRelativePosition.y - turtleTelemetry.localCoord.position.y

    while yDifference ~= 0 do
        if yDifference > 0 then
            safeTurtle.up()
        else
            safeTurtle.down()
        end

        --- @diagnostic disable-next-line: undefined-field
        yDifference = targetRelativePosition.y - turtleTelemetry.localCoord.position.y
    end

    -- move in the X direction now
    --- @diagnostic disable: undefined-field
    local xDifference = targetRelativePosition.x - turtleTelemetry.localCoord.position.x
    local xHeading = xDifference / (xDifference == 0 and 1 or xDifference)
    --- @diagnostic enable: undefined-field

    if xDifference ~= 0 then
        -- need to get the heading and change it
        --- @diagnostic disable-next-line: undefined-field
        while turtleTelemetry.localCoord.direction.x ~= xHeading do
            safeTurtle.left()
        end

        -- then make the move
        while xDifference ~= 0 do
            safeTurtle.forward()

            --- @diagnostic disable-next-line: undefined-field
            xDifference = targetRelativePosition.x - turtleTelemetry.localCoord.position.x
        end
    end

    -- move in the X direction now
    --- @diagnostic disable: undefined-field
    local zDifference = targetRelativePosition.z - turtleTelemetry.localCoord.position.z
    local zHeading = zDifference / (zDifference == 0 and 1 or zDifference)
    --- @diagnostic enable: undefined-field

    if zDifference ~= 0 then
        -- need to get the heading and change it
        --- @diagnostic disable-next-line: undefined-field
        while turtleTelemetry.localCoord.direction.z ~= zHeading do
            safeTurtle.right()
        end

        -- then make the move
        while zDifference ~= 0 do
            safeTurtle.forward()

            --- @diagnostic disable-next-line: undefined-field
            zDifference = targetRelativePosition.z - turtleTelemetry.localCoord.position.z
        end
    end

    print("location is: " .. tostring(turtleTelemetry.localCoord))
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

toolChanger.equipSilkMine()
print(toolChanger.getCurrentTool())
sleep(1)
toolChanger.equipModem()
print(toolChanger.getCurrentTool())
sleep(1)
toolChanger.equipStandardMine()
print(toolChanger.getCurrentTool())

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
