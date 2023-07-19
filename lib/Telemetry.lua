--- library of functions for Telemetry
local Telemetry = {
    --- functions that put the origin on where the turtle starts
    relative = {}
}

-- NOTE: classes and types

--- @alias equipModem_t fun(): nil function that equips a modem for GPS

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
--- @field globalCheckpoint Vector most recent real coordinate checkpoint made, should match local space checkpoint

-- NOTE: private variables

--- @type telemetryState_t the config for this module
local __state = {
    localCoord = Telemetry.Coordinate:new({
        position = vector.new(0, 0, 0),
        direction = vector.new(0, 0, 1)
    }),
    localCheckpoint = Telemetry.Coordinate:new({
        position = vector.new(0, 0, 0),
        direction = vector.new(0, 0, 1)
    }),
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
--- @param equip equipModem_t
function Telemetry.init(equip)
    local handle, content
    equip()

    -- check for an existing telemetry file
    if not fs.exists("./telemetry.json") then
        -- this MUST be first boot
        print("TELEM: Generating config")

        ---@diagnostic disable-next-line: missing-parameter
        local x, y, z = gps.locate()

        __state.globalCheckpoint.position = vector.new(x, y, z)
        __state.globalCheckpoint.direction = vector.new(0, 0, 0)
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
                    __state.globalCheckpoint = vector.new(result.globalCheckpoint.x,
                        result.globalCheckpoint.y, result.globalCheckpoint.z)
                end
            end
        end
    end
end

--- adds the turtle's current position as a checkpoint
--- @param equip equipModem_t
function Telemetry.updateCheckpoint(equip)
    equip()

    ---@diagnostic disable-next-line: missing-parameter
    local x, y, z = gps.locate()

    __state.globalCheckpoint = vector.new(x, y, z)
    __state.localCheckpoint = __state.localCoord
    __writeToState(__state)
end

--- checks if the turtle is at the checkpoint
--- @param equip equipModem_t
--- @return boolean result
function Telemetry.atCheckpoint(equip)
    equip()

    ---@diagnostic disable-next-line: missing-parameter
    local x, y, z = gps.locate()
    local v = vector.new(x, y, z)

    -- if not in the same space
    if __state.globalCheckpoint ~= v then
        return false
    end

    if (__state.localCheckpoint.position ~= __state.localCoord.position) and (__state.localCheckpoint.direction ~= __state.localCoord.direction) then
        return false
    end

    return true
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
