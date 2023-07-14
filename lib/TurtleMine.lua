---  functions to help with the mining of a cubic volume
local TurtleMine = {}

-- NOTE: classes and types

--- function to get a local coordinate
--- @alias getCoordinate_t fun(): Telemetry.Coordinate

--- @class digFunctions_t
--- @field dig function function to dig forward
--- @field digUp function function to dig up
--- @field digDown function function to dig down

--- @class locomotionFunctions_t
--- @field forward function function to forward move
--- @field back function function to backward move
--- @field up function function to upward move
--- @field down function function to downward move
--- @field turnLeft function function to do a left turn
--- @field turnRight function function to do a right turn

--- @class turtleMineConfig_t config for this library
--- @field getCoordinate getCoordinate_t to return the local telemetry coordinate
--- @field stopFluid function
--- @field dig digFunctions_t
--- @field movement locomotionFunctions_t config for mining functions

-- NOTE: private variables

--- @type turtleMineConfig_t config for the library
local __config

--- hidden variable for the state of the uturn
local __isTurnLeft = false

-- NOTE: private functions

-- NOTE: public functions

--- application specific function to set config
--- @param config turtleMineConfig_t
function TurtleMine.setConfig(config)
    __config = config
end

--- function to dig, stops potential fluids and mines below to save fuel
--- @param h number the current height of the turtle relative to the mining area
--- @param totalH number the total height of the mining areaa
function TurtleMine.smartDig(h, totalH)
    -- check for fluids
    __config.stopFluid()

    -- dig in front for the move
    __config.dig.dig()

    -- FIXME:
    if h <= (totalH - 1) then
        -- if we have more one more layer below us, dig below
        __config.dig.digDown()
    end
end

--- function to turn around and start new line for mining, is "safe"
--- @param w number the current horizontal distance into the mining area
--- @param h number the current height of the turtle relative to the mining area
--- @param totalH number the total height of the mining areaa
function TurtleMine.uTurn(w, h, totalH)
    local result = math.fmod(w, 2) == 0
    if __isTurnLeft then
        result = not result
    end

    __config.stopFluid()
    -- if even or odd
    if result then
        __config.movement.turnLeft()
    else
        __config.movement.turnRight()
    end

    TurtleMine.smartDig(h, totalH)
    __config.movement.forward()

    __config.stopFluid()
    -- if even or odd
    if result then
        __config.movement.turnLeft()
    else
        __config.movement.turnRight()
    end
end

--- function to move to the next horizontal slice, is "safe"
--- @param w number the horizontal distance of the mining area
function TurtleMine.moveDown(w)
    -- check for fluids
    __config.stopFluid()

    __config.dig.digDown()
    __config.movement.down()
    __config.dig.digDown()
    __config.movement.down()
    __config.movement.turnRight()
    __config.movement.turnRight()

    if math.fmod(w, 2) == 0 and __isTurnLeft == false then
        __isTurnLeft = true
    else
        __isTurnLeft = false
    end
end

--- unique function meant to find the next chunk based off of current location
--- @param v Vector the mining direction vector
--- @param l number the length distance of the mining area
--- @param i Vector the number of iterations that have passed
function TurtleMine.moveToNextChunk(v, l, i)
    -- local position of end point
    local targetRelativePosition = v:mul(l * i)

    print("target is: " .. tostring(targetRelativePosition))

    -- move in the Y direction first
    local yDifference = targetRelativePosition.y - __config.getCoordinate().position.y

    while yDifference ~= 0 do
        if yDifference > 0 then
            __config.movement.up()
        else
            __config.movement.down()
        end

        yDifference = targetRelativePosition.y - __config.getCoordinate().position.y
    end

    -- move in the X direction now
    local xDifference = targetRelativePosition.x - __config.getCoordinate().position.x
    local xHeading = xDifference / (xDifference == 0 and 1 or xDifference)

    if xDifference ~= 0 then
        -- need to get the heading and change it
        while __config.getCoordinate().direction.x ~= xHeading do
            __config.movement.turnLeft()
        end

        -- then make the move
        while xDifference ~= 0 do
            __config.movement.forward()

            xDifference = targetRelativePosition.x - __config.getCoordinate().position.x
        end
    end

    -- move in the X direction now
    local zDifference = targetRelativePosition.z - __config.getCoordinate().position.z
    local zHeading = zDifference / (zDifference == 0 and 1 or zDifference)

    if zDifference ~= 0 then
        -- need to get the heading and change it
        while __config.getCoordinate().direction.z ~= zHeading do
            __config.movement.turnRight()
        end

        -- then make the move
        while zDifference ~= 0 do
            __config.movement.forward()

            zDifference = targetRelativePosition.z - __config.getCoordinate().position.z
        end
    end

    -- rotate back to right direction and reset left turn
    while __config.getCoordinate().direction.z ~= v.z and __config.getCoordinate().direction.x ~= v.x do
        __config.movement.turnRight()
    end

    __isTurnLeft = false

    print("location is: " .. tostring(__config.getCoordinate()))
end

-- NOTE: export statement
return TurtleMine
