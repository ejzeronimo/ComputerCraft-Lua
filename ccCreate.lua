--[[
    plan:

    on startup the turtle should have a backpack with tools and fuel

--]]

-- NOTE: global functions

-- get the backpack/shulker that contains the tools and fuel for the turtle
function getToolsAndFuelStore()
    -- search the inventory for a backpack, then shulker, then add more
    storeTypes = {
        "sophisticatedbackpacks:backpack",
        "minecraft:shulker_box"
    }

    
end

-- chunk controller ALWAYS on the left side

-- purge the current peripheral if it is there
if peripheral.isPresent("right") then
    
    
end



args = {...}

if #args < 3 then
    print("Usage: quarry x:forward y:right z:up")
    return
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

--loop through area
turtle.refuel()
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