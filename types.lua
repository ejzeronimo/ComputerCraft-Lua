---@meta

-- NOTE: this file is used for universal typedefs only

-- NOTE: types

-- NOTE: classes

--- @type number the X component of a Vector
Vector.x = nil
--- @type number the Y component of a Vector
Vector.y = nil
--- @type number the Z component of a Vector
Vector.z = nil

-- NOTE: functions

--- function to place a block
--- @alias placeBlock_t fun(): boolean

--- function to break a block
--- @alias breakBlock_t fun(): boolean

--- function to take item
--- @alias suckItem_t fun(n: number?): boolean

--- function to drop item
--- @alias dropItem_t fun(n: number?): boolean