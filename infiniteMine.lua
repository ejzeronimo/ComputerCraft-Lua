--[[
    plan:

    on startup the turtle should have a backpack with tools

--]]


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

-- NOTE: globals
args = { ... }
configPath = "./mine.config"
configFile = nil
config = Config:new()

scaffolding = {
    "minecraft:cobbled_deepslate"
}

height = 4
length = 4
width = 4

-- NOTE: functions
stdLog = {
    error = function(message)
        printError(message)
    end
}

--- the position information about the turtle
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

inventoryManager = {
    selectScaffold = function()
        local oldSelect = turtle.getSelectedSlot()

        -- for each turtle slot
        for i = 1, 16, 1 do
            for j, v in ipairs(scaffolding) do
                local data = turtle.getItemDetail(i)
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
            reset = inventoryManager.selectScaffold()

            safeTurtle.placeUp()

            reset()
        end

        -- check for fluids in front of us
        present, info = turtle.inspect()

        if present and info.state.level ~= nil then
            reset = inventoryManager.selectScaffold()

            safeTurtle.place()

            reset()
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
            print("smartDig was smart!")
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

-- get the backpack/shulker that contains the tools and fuel for the turtle
function getToolsAndFuelStore()
    -- search the inventory for a backpack, then shulker, then add more
    storeTypes = {
        "sophisticatedbackpacks:backpack"
    }
end

function purgeInventory()
    turtle.select(1)
    turtle.digUp()
    turtle.placeUp()
    for i = 1, 16, 1 do
        if turtle.getItemCount(i) > 0 then
            turtle.select(i)
            if turtle.getItemDetail().name ~= "enderstorage:ender_storage" then
                turtle.dropUp()
            end
        end
    end
    turtle.select(1)
    turtle.digUp()
    modem.transmit(3, 1, os.getComputerLabel() .. " inventory cleared " .. os.clock())
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

-- NOTE: the setup
-- if the path is invalid
if not fs.exists(configPath) then
    printError("ERROR: invalid path to config")
    return
end

-- chunk controller ALWAYS on the left side

-- purge the current peripheral if it is there
if peripheral.isPresent("right") then
end

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

    if h <= (height - 1) then
        print("dig below current: " .. h .. " target: " .. height)
        safeTurtle.digDown()
    end

    -- at end of level
    print("current: " .. h .. " target: " .. height)
    if h < (height - 1) then
        print("called")
        turtleMine.moveDown()
        h = h + 1
    end
end

-- TODO: make turtle pathfind to new chunk
--moveToNewChunk()
--end

-- NOTE: after the stop message was received
