--- library of functions for Telemetry
local Telemetry = {
    --- functions that put the origin on where the turtle starts
    relative = {}
}

-- NOTE: classes and types

--- @class Telemetry.Coordinate
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

-- NOTE: private variables

--- @package
--- coordinate relative to where the turtle was first placed
--- @type Telemetry.Coordinate
local localCoord = Telemetry.Coordinate:new({
    position = vector.new(0, 0, 0),
    direction = vector.new(0, 0, 1)
})

-- NOTE: private functions

-- NOTE: public functions

--- function to update the local position forward one block
function Telemetry.relative.forward()
    localCoord.position = localCoord.position + localCoord.direction
end

--- function to update the local position backward one block
function Telemetry.relative.back()
    localCoord.position = localCoord.position - localCoord.direction
end

--- function to update the local position to face left 90 degress
function Telemetry.relative.leftTurn()
    localCoord.direction = vector.new(
    --- @diagnostic disable: undefined-field
        localCoord.direction.x * math.cos(-math.pi / 2) +
        localCoord.direction.z * math.sin(-math.pi / 2),
        localCoord.direction.y,
        -localCoord.direction.x * math.sin(-math.pi / 2) +
        localCoord.direction.z * math.cos(-math.pi / 2)
    --- @diagnostic enable: undefined-field
    )

    localCoord.direction = localCoord.direction:round()
end

--- function to update the local position to face right 90 degress
function Telemetry.relative.rightTurn()
    localCoord.direction = vector.new(
    --- @diagnostic disable: undefined-field
        localCoord.direction.x * math.cos(math.pi / 2) +
        localCoord.direction.z * math.sin(math.pi / 2),
        localCoord.direction.y,
        -localCoord.direction.x * math.sin(math.pi / 2) +
        localCoord.direction.z * math.cos(math.pi / 2)
    --- @diagnostic enable: undefined-field
    )

    localCoord.direction = localCoord.direction:round()
end

--- function to update the local position upward one block
function Telemetry.relative.up()
    localCoord.position = localCoord.position + vector.new(0, 1, 0)
end

--- function to update the local position downward one block
function Telemetry.relative.down()
    localCoord.position = localCoord.position + vector.new(0, -1, 0)
end

-- NOTE: export statement
return Telemetry