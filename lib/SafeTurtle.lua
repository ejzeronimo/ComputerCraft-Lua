--- functions with smart and fallback modes built in, extension of the turtle api
local SafeTurtle = {}

-- NOTE: classes and types

--- function to handle getting an item
--- @alias getEmptySlot_t fun(n?: string): number?

--- function to select the scaffold item then reset the selected slot
--- @alias selectScaffold_t fun(): function

--- function to equip a silk mine
--- @alias breakSilk_t fun(n: string): boolean

--- @class safeToolChangerFunctions_t functions to change the tool the turtle is useing
--- @field selectScaffold selectScaffold_t function to select the scaffold item
--- @field breakSilk breakSilk_t? function to use the silk tool

--- @class safeTelemetryFunctions_t telemetry functions that store position of the turtle
--- @field forward function function to log a forward move
--- @field back function function to log a backward move
--- @field up function function to log a upward move
--- @field down function function to log a downward move
--- @field turnLeft function function to log a left turn
--- @field turnRight function function to log a right turn

--- @class safeTurtleConfig_t config for this library
--- @field threshold number the number at which the turtle shgould refuel
--- @field refuel function function to refuel the turtle
--- @field getEmptySlot getEmptySlot_t function to get a slot for the listed item
--- @field toolChanger safeToolChangerFunctions_t config for toolchanger functions
--- @field telemetry safeTelemetryFunctions_t config for telemetry functions

-- NOTE: private variables

--- @type safeTurtleConfig_t config for the library
local __config

-- NOTE: private functions

--- private dig function
--- @param d function the directional dig function to invoke
--- @param i function the directional inspect function to invoke
--- @return boolean success if a block was broken
--- @return string|nil errorMessage the reason no block was broken
function __dig(d, i)
    local success, reason = d()
    local present, info = i()
    local retry = 0

    -- make sure we have a free spot
    __config.getEmptySlot(info.name)

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
end

--- private place function
--- @param p function the directional place function to invoke
--- @param d function the directional dig function to invoke
--- @param i function the directional inspect function to invoke
--- @param t? string text to pass to the place function
--- @return boolean success if a block was placed
--- @return string|nil errorMessage the reason no block was placed
function __place(p, d, i, t)
    local present, info = i()
    local success, reason = p(t)
    local fail = 0

    while (not success and present) and fail < 3 do
        -- try to mine, there might be a block
        __dig(d, i)

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
end

--- private move function
--- @param m function the directional move function to invoke
--- @param d function the directional dig function to invoke
--- @param t function the directional telemetry function to invoke
--- @return boolean success if move was successful
--- @return string|nil errorMessage the reason no move was made
function __move(m, d, t)
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
    if turtle.getFuelLevel() < (turtle.getFuelLimit() * __config.threshold) then
        __config.refuel()
    end

    t()
    return true
end

-- NOTE: public functions

--- application specific function to set config
--- @param config safeTurtleConfig_t
function SafeTurtle.setConfig(config)
    __config = config
end

--- move the turtle forward
--- @return boolean success if move was successful
--- @return string|nil errorMessage the reason no move was made
function SafeTurtle.forward()
    return __move(turtle.forward, SafeTurtle.dig, __config.telemetry.forward)
end

--- move the turtle backward
--- @return boolean success if move was successful
--- @return string|nil errorMessage the reason no move was made
function SafeTurtle.back()
    local function d()
        SafeTurtle.right()
        SafeTurtle.right()

        SafeTurtle.dig()

        SafeTurtle.right()
        SafeTurtle.right()
    end

    return __move(turtle.back, d, __config.telemetry.back)
end

--- move the turtle up
--- @return boolean success if move was successful
--- @return string|nil errorMessage the reason no move was made
function SafeTurtle.up()
    return __move(turtle.up, SafeTurtle.digUp, __config.telemetry.up)
end

--- move the turtle down
--- @return boolean success if move was successful
--- @return string|nil errorMessage the reason no move was made
function SafeTurtle.down()
    return __move(turtle.down, SafeTurtle.digDown, __config.telemetry.down)
end

--- rotate the turtle left
function SafeTurtle.turnLeft()
    turtle.turnLeft()
    __config.telemetry.turnLeft()
end

--- rotate the turtle right
function SafeTurtle.turnRight()
    turtle.turnRight()
    __config.telemetry.turnRight()
end

--- dig in front of the turtle
--- @return boolean success if a block was broken
--- @return string|nil errorMessage the reason no block was broken
function SafeTurtle.dig()
    local present, data = turtle.inspect()

    -- if this is an ore and not ancient debris
    if  __config.toolChanger.breakSilk and present and data.tags["forge:ores"] and data.name ~= "minecraft:ancient_debris" then
        return __config.toolChanger.breakSilk(data.name)
    end

    -- just a normal dig
    return __dig(turtle.dig, turtle.inspect)
end

--- dig above the turtle
--- @return boolean success if a block was broken
--- @return string|nil errorMessage the reason no block was broken
function SafeTurtle.digUp()
    return __dig(turtle.digUp, turtle.inspectUp)
end

--- dig below the turtle
--- @return boolean success if a block was broken
--- @return string|nil errorMessage the reason no block was broken
function SafeTurtle.digDown()
    return __dig(turtle.digDown, turtle.inspectDown)
end

--- place a block in front
--- @param text? string text to put on a sign
--- @return boolean success if a block was placed
--- @return string|nil errorMessage the reason no block was placed
function SafeTurtle.place(text)
    return __place(turtle.place, SafeTurtle.dig, turtle.inspect, text)
end

--- place a block above
--- @param text? string text to put on a sign
--- @return boolean success if a block was placed
--- @return string|nil errorMessage the reason no block was placed
function SafeTurtle.placeUp(text)
    return __place(turtle.placeUp, SafeTurtle.digUp, turtle.inspectUp, text)
end

--- place a block below
--- @param text? string text to put on a sign
--- @return boolean success if a block was placed
--- @return string|nil errorMessage the reason no block was placed
function SafeTurtle.placeDown(text)
    return __place(turtle.placeDown, SafeTurtle.digDown, turtle.inspectDown, text)
end

--- function that checks for fluid in front of and above turtle. Places blocks to remove them
function SafeTurtle.stopFluid()
    -- check for fluids above us
    local present, info = turtle.inspectUp()
    local reset

    if present and info.state.level ~= nil then
        reset = __config.toolChanger.selectScaffold()

        SafeTurtle.placeUp()

        reset()
    end

    -- check for fluids in front of us
    present, info = turtle.inspect()

    if present and info.state.level ~= nil then
        reset = __config.toolChanger.selectScaffold()

        SafeTurtle.place()

        reset()
    end
end

-- NOTE: export statement
return SafeTurtle
