--[[
    plan:

    on startup the turtle should have a backpack with tools

--]]


-- NOTE: classes and objects
Coordinate = {
    position = {
        x = 0,
        y = 0,
        z = 0
    },
    direction = {
        x = 0,
        y = 0,
        z = 0
    },
    new = function(self, o)
        o = o or {}
        setmetatable(o, self)
        self.__index = self
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
stdLog = {
    error = function(message)
        printError(message)
    end
}

safeTurtle = {
    forward = function()
        local success, reason = turtle.forward()
        local fail = 0

        while not success and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.dig()
            success, reason = turtle.forward()

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not move forward, reason: " .. reason)

            return false, reason
        end

        return true
    end,
    back = function()
        local success, reason = turtle.back()
        local fail = 0

        while not success and fail < 3 do
            -- turn around
            turtle.turnLeft()
            turtle.turnLeft()

            -- try to mine, there might be a block
            safeTurtle.dig()

            -- turn around
            turtle.turnRight()
            turtle.turnRight()

            success, reason = turtle.back()

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not move forward, reason: " .. reason)

            return false, reason
        end

        return true
    end,
    up = function()
        local success, reason = turtle.up()
        local fail = 0

        while not success and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.digUp()
            success, reason = turtle.up()

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not move up, reason: " .. reason)

            return false, reason
        end

        return true
    end,
    down = function()
        local success, reason = turtle.down()
        local fail = 0

        while not success and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.digDown()
            success, reason = turtle.down()

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not move down, reason: " .. reason)

            return false, reason
        end

        return true
    end,
    dig = function()
        local success, reason = turtle.dig()
        local present, info = turtle.inspect()
        local retry = 0

        while present and retry < 32 do
            -- mine the block
            success, reason = turtle.dig()
            -- then check if it is still there
            present, info = turtle.inspect()

            retry = retry + 1
            sleep(0)
        end

        -- we failed, print an error
        if retry == 32 then
            printError("ERROR: could not break front block " .. info.name .. ", reason: " .. reason)

            return false, reason
        end

        return true
    end,
    digUp = function()
        local success, reason = turtle.digUp()
        local present, info = turtle.inspectUp()
        local retry = 0

        while present and retry < 32 do
            -- mine the block
            success, reason = turtle.digUp()
            -- then check if it is still there
            present, info = turtle.inspectUp()

            retry = retry + 1
            sleep(0)
        end

        -- we failed, print an error
        if retry == 32 then
            printError("ERROR: could not break above block " .. info.name .. ", reason: " .. reason)

            return false, reason
        end

        return true
    end,
    digDown = function()
        local success, reason = turtle.digDown()
        local present, info = turtle.inspectDown()
        local retry = 0

        while present and retry < 32 do
            -- mine the block
            success, reason = turtle.digDown()
            -- then check if it is still there
            present, info = turtle.inspectDown()

            retry = retry + 1
            sleep(0)
        end

        -- we failed, print an error
        if retry == 32 then
            printError("ERROR: could not break below block " .. info.name .. ", reason: " .. reason)

            return false, reason
        end

        return true
    end,
    place = function(text)
        local present, info = turtle.inspect()
        local success, reason = turtle.place(text)
        local fail = 0

        while (not success and present) and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.dig()

            -- retry the place
            present, info = turtle.inspect()
            success, reason = turtle.place(text)

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not place front block, reason: " .. reason)

            return false, reason
        end

        return true
    end,
    placeUp = function(text)
        local present, info = turtle.inspectUp()
        local success, reason = turtle.placeUp(text)
        local fail = 0

        while (not success and present) and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.digUp()

            -- retry the place
            present, info = turtle.inspectUp()
            success, reason = turtle.placeUp(text)

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not place above block, reason: " .. reason)

            return false, reason
        end

        return true
    end,
    placeDown = function(text)
        local present, info = turtle.inspectDown()
        local success, reason = turtle.placeDown(text)
        local fail = 0

        while (not success and present) and fail < 3 do
            -- try to mine, there might be a block
            safeTurtle.digDown()

            -- retry the place
            present, info = turtle.inspectDown()
            success, reason = turtle.placeDown(text)

            fail = fail + 1
            sleep(0)
        end

        -- we failed, print an error
        if fail == 3 then
            printError("ERROR: could not place below block, reason: " .. reason)

            return false, reason
        end

        return true
    end
}

-- get the backpack/shulker that contains the tools and fuel for the turtle
function getToolsAndFuelStore()
    -- search the inventory for a backpack, then shulker, then add more
    storeTypes = {
        "sophisticatedbackpacks:backpack"
    }
end

-- chunk controller ALWAYS on the left side

-- purge the current peripheral if it is there
if peripheral.isPresent("right") then
end

turtle.select(1)
length = args[1]
width = args[2]
depth = args[3]
invert = false

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

function changeLane(i, h)
    result = math.fmod(i, 2) == 0
    if invert then
        result = not result
    end
    if result then
        --even
        turtle.turnLeft()
        turtle.dig()
        if h <= (depth - 1) then
            turtle.digDown()
        end
        turtle.forward()
        turtle.turnLeft()
    else
        --odd
        turtle.turnRight()
        turtle.dig()
        if h <= (depth - 1) then
            turtle.digDown()
        end
        turtle.forward()
        turtle.turnRight()
    end
    modem.transmit(3, 1, os.getComputerLabel() .. " changed lane " .. os.clock())
    checkTurtle()
end

function changeLevel()
    turtle.digDown()
    turtle.down()
    turtle.digDown()
    turtle.down()
    turtle.turnRight()
    turtle.turnRight()
    modem.transmit(3, 1, os.getComputerLabel() .. " changed level " .. os.clock())
    if math.fmod(width, 2) == 0 and invert == false then
        invert = true
    else
        invert = false
    end
    checkTurtle()
end

-- NOTE: the setup
args = { ... }
configFile = nil
config = Config:new()

-- if the path is wrong
if #args < 1 then
    printError("ERROR: need to give a path to a config file")
    return
end

-- if the path is invalid
if not fs.exists(args[1]) then
    printError("ERROR: invalid path to config")
    return
end

print("Initial checks past")

-- NOTE: the main loop
local h = 1
while h < tonumber(depth) + 1 do
    print(h)
    for i = 1, width, 1 do
        for j = 1, length - 1, 1 do
            --break block in front move forward
            turtle.dig()
            if h <= (depth - 1) then
                turtle.digDown()
            end
            turtle.forward()
            checkTurtle()
        end
        --at end of line
        if i <= (width - 1) then
            changeLane(i, h)
        end
    end
    --at end of level
    if h <= (depth - 1) then
        changeLevel()
        h = h + 1
    end
    h = h + 1
end
purgeInventory()
modem.transmit(3, 1, os.getComputerLabel() .. " mission complete " .. os.clock())
