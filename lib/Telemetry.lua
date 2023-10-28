--- library of functions for Telemetry
local Telemetry = {
    --- functions that put the origin on where the turtle starts
    relative = {}
}

-- NOTE: classes and types

--- @alias getGpsCoord_t fun(): Vector function that gets the current GPS position

--- @alias getGpsDir_t fun(): Vector function that moves to calc the GPS direction

--- @class Telemetry.Coordinate external facing coordinate class with constructor
Telemetry.Coordinate = {
    --- @type Vector position in XYZ space
    position = nil,
    --- @type Vector direction in XYZ space
    direction = nil,
    __tostring = function(self)
        return "position: " .. tostring(self.position) .. " heading: " .. tostring(self.direction)
    end,
    --- makes a new instance of this object
    --- @return Telemetry.Coordinate
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

--- @class telemetryState_t config for this module
--- @field localCoord Telemetry.Coordinate coordinate relative to where the turtle was first placed
--- @field localCheckpoint Telemetry.Coordinate most recent relative checkpoint made
--- @field globalCheckpoint Telemetry.Coordinate most recent real coordinate checkpoint made, should match local space checkpoint

-- NOTE: private variables

--- @type telemetryState_t the config for this module
local __state = {
    localCoord = Telemetry.Coordinate:new({
        position = vector.new(0, 0, 0),
        direction = vector.new(1, 0, 0)
    }),
    localCheckpoint = Telemetry.Coordinate:new({
        position = vector.new(0, 0, 0),
        direction = vector.new(1, 0, 0)
    }),
    globalCheckpoint = Telemetry.Coordinate:new({
        position = vector.new(0, 0, 0),
        direction = vector.new(0, 0, 0)
    })
}

-- NOTE: private functions

--- write the current state to the save file
--- @param st telemetryState_t
local function __writeToState(st)
    local handle = fs.open("./telemetry.json", "w")

    if handle then
        handle.write(textutils.serializeJSON(st))
        handle.close()
    end
end

-- NOTE: public universal functions

--- function to start the telemetry module
--- @param getGlobalPos getGpsCoord_t function to get the GPS coords
--- @param getGlobalDirection getGpsDir_t function to get the global direction Vector
function Telemetry.init(getGlobalPos, getGlobalDirection)
    local handle, content

    -- check for an existing telemetry file
    if not fs.exists("./telemetry.json") then
        -- this MUST be first boot
        print("TELEM: Generating config")

        __state.globalCheckpoint.position = getGlobalPos()
        __state.globalCheckpoint.direction = getGlobalDirection()

        __writeToState(__state)
    else
        handle = fs.open("./telemetry.json", "r")

        if handle then
            content = handle.readAll()

            if content then
                local result = textutils.unserializeJSON(content)

                if result then
                    --- @cast result telemetryState_t
                    __state = result

                    -- fix the local vectors
                    __state.localCoord.direction = vector.new(result.localCoord.direction.x,
                        result.localCoord.direction.y, result.localCoord.direction.z)
                    __state.localCoord.position = vector.new(result.localCoord.position.x,
                        result.localCoord.position.y, result.localCoord.position.z)

                    -- fix the local checkpoint vectors
                    __state.localCheckpoint.direction = vector.new(result.localCheckpoint.direction.x,
                        result.localCheckpoint.direction.y, result.localCheckpoint.direction.z)
                    __state.localCheckpoint.position = vector.new(result.localCheckpoint.position.x,
                        result.localCheckpoint.position.y, result.localCheckpoint.position.z)

                    -- fix the global checkpoint vectors
                    __state.globalCheckpoint.direction = vector.new(result.globalCheckpoint.direction.x,
                        result.globalCheckpoint.direction.y, result.globalCheckpoint.direction.z)
                    __state.globalCheckpoint.position = vector.new(result.globalCheckpoint.position.x,
                        result.globalCheckpoint.position.y, result.globalCheckpoint.position.z)
                end
            end
        end
    end
end

--- adds the turtle's current position as a checkpoint
--- @param getGlobalPos getGpsCoord_t function to get the GPS coords
function Telemetry.updateCheckpoint(getGlobalPos)
    __state.globalCheckpoint.position = getGlobalPos()

    __state.localCheckpoint.position = __state.localCoord.position + vector.new(0, 0, 0)
    __state.localCheckpoint.direction = __state.localCoord.direction + vector.new(0, 0, 0)
    __writeToState(__state)
end

--- checks if the turtle is at the checkpoint
--- @param getGlobalPos getGpsCoord_t function to get the GPS coords
--- @param getGlobalDirection getGpsDir_t function to get the global direction Vector
--- @return boolean globalPositionResult
--- @return boolean globalDirectionResult
--- @return boolean localPositionResult
--- @return boolean localDirectionResult
function Telemetry.atCheckpoint(getGlobalPos, getGlobalDirection)
    local globalCheckpointPos, globalCheckpointDir = false, false
    local localCheckpointPos, localCheckpointDir   = false, false

    -- if not in the same space
    globalCheckpointPos = __state.globalCheckpoint.position:equals(getGlobalPos())
    globalCheckpointDir = __state.globalCheckpoint.direction:equals(getGlobalDirection())
    localCheckpointPos = __state.localCheckpoint.position:equals(__state.localCoord.position)
    localCheckpointDir = __state.localCheckpoint.direction:equals(__state.localCoord.direction)

    return globalCheckpointPos, globalCheckpointDir, localCheckpointPos, localCheckpointDir
end

--- get the checkpoint
--- @return Vector globalCheckpoint
--- @return Telemetry.Coordinate localCheckpoint
function Telemetry.getCheckpoint()
    return __state.globalCheckpoint.position, __state.localCheckpoint
end

-- tries to return to the checkpoint saved
--- @param gpsPos getGpsCoord_t function to get the GPS coords
--- @param gpsDir getGpsDir_t function to get the GPS direction
--- @param up function move up
--- @param down function move down
--- @param left function turn left
--- @param right function turn right
--- @param forward function move forward
--- @param back function move back
function Telemetry.returnToCheckpoint(gpsPos, gpsDir, up, down, left, right, forward, back)
    -- get the state of out checkpoints
    local atGlobalPos, atGlobalDir, atLocalPos, atLocalDir = Telemetry.atCheckpoint(gpsPos, gpsDir)

    local function moveToLocalCheckpoint()
        -- local y first
        local yDifference = __state.localCheckpoint.position.y - __state.localCoord.position.y

        while yDifference ~= 0 do
            if yDifference > 0 then
                up()
            else
                down()
            end

            yDifference = __state.localCheckpoint.position.y - __state.localCoord.position.y
            sleep(0)
        end

        -- local x
        local xDifference = __state.localCheckpoint.position.x - __state.localCoord.position.x
        local xHeading = xDifference / (xDifference == 0 and 1 or math.abs(xDifference))

        if xDifference ~= 0 then
            -- need to get the heading and change it
            while __state.localCoord.direction.x ~= xHeading do
                left()
                sleep(0)
            end

            -- then make the move
            while xDifference ~= 0 do
                forward()

                xDifference = __state.localCheckpoint.position.x - __state.localCoord.position.x
                sleep(0)
            end
        end

        -- local z
        local zDifference = __state.localCheckpoint.position.z - __state.localCoord.position.z
        local zHeading = zDifference / (zDifference == 0 and 1 or math.abs(zDifference))

        if zDifference ~= 0 then
            -- need to get the heading and change it
            while __state.localCoord.direction.z ~= zHeading do
                right()
                sleep(0)
            end

            -- then make the move
            while zDifference ~= 0 do
                forward()

                zDifference = __state.localCheckpoint.position.z - __state.localCoord.position.z
                sleep(0)
            end
        end
    end

    -- while all of our checkpoints dont match
    while (not atGlobalPos) or (not atGlobalDir) or (not atLocalPos) or (not atLocalDir) do
        if not atLocalPos then
            -- do local position first
            moveToLocalCheckpoint()
        end

        if not atLocalDir then
            -- rotate back to right direction
            repeat
                right()
                sleep(0)
            until __state.localCoord.direction.z == __state.localCheckpoint.direction.z and __state.localCoord.direction.x == __state.localCheckpoint.direction.x
        end

        -- do a mid update
        atGlobalPos, atGlobalDir, atLocalPos, atLocalDir = Telemetry.atCheckpoint(gpsPos, gpsDir)

        -- at this point only the globals should be wrong

        -- TODO: need to find a way to get global position
        -- calc global rotation
        -- convert to local space
        -- move to it
        -- check
        sleep(0)
    end
end

-- NOTE: public relative functions

--- function to reset the localCoord position
function Telemetry.relative.resetCoord()
    __state.localCoord.position = vector.new(0, 0, 0)
end

--- function to update the local position forward one block
--- @return Telemetry.Coordinate local the local coordinate
function Telemetry.relative.getCoord()
    return __state.localCoord
end

--- function to update the local position forward one block
function Telemetry.relative.forward()
    __state.localCoord.position = __state.localCoord.position + __state.localCoord.direction
    __writeToState(__state)
end

--- function to update the local position backward one block
function Telemetry.relative.back()
    __state.localCoord.position = __state.localCoord.position - __state.localCoord.direction
    __writeToState(__state)
end

--- function to update the local position to face left 90 degress
function Telemetry.relative.leftTurn()
    __state.localCoord.direction = vector.new(
        __state.localCoord.direction.x * math.cos(-math.pi / 2) +
        __state.localCoord.direction.z * math.sin(-math.pi / 2),
        __state.localCoord.direction.y,
        -__state.localCoord.direction.x * math.sin(-math.pi / 2) +
        __state.localCoord.direction.z * math.cos(-math.pi / 2)
    )

    __state.localCoord.direction = __state.localCoord.direction:round()
    __writeToState(__state)
end

--- function to update the local position to face right 90 degress
function Telemetry.relative.rightTurn()
    __state.localCoord.direction = vector.new(
        __state.localCoord.direction.x * math.cos(math.pi / 2) +
        __state.localCoord.direction.z * math.sin(math.pi / 2),
        __state.localCoord.direction.y,
        -__state.localCoord.direction.x * math.sin(math.pi / 2) +
        __state.localCoord.direction.z * math.cos(math.pi / 2)
    )

    __state.localCoord.direction = __state.localCoord.direction:round()
    __writeToState(__state)
end

--- function to update the local position upward one block
function Telemetry.relative.up()
    __state.localCoord.position = __state.localCoord.position + vector.new(0, 1, 0)
    __writeToState(__state)
end

--- function to update the local position downward one block
function Telemetry.relative.down()
    __state.localCoord.position = __state.localCoord.position + vector.new(0, -1, 0)
    __writeToState(__state)
end

-- NOTE: export statement
return Telemetry
