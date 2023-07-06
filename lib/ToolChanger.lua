--- functions to swap what a turtle is using / holding
local ToolChanger = {}

-- NOTE: classes and types

--- @package
--- @alias getFreeSlot_t fun(): integer|nil private implementation, used for no coupling, needs to return a slot or nil

--- @package
--- @alias getNewItem_t fun(name: string): nil private implementation, used for no coupling, needs to get a new one of item given

--- @package
--- @type peripheral_t
--- @class peripheral_t
local peripheral_t = {
    --- the item name of the peripheral
    peripheral = ""
}

--- @package
--- @type peripheralSelect_t
--- @class peripheralSelect_t: peripheral_t
local peripheralSelect_t = {
    --- the item name to select when peripheral is equipped
    select = ""
}

--- @package
--- @alias tool_t peripheral_t | peripheralSelect_t

--- @package
--- @alias toolMap_t { standardMine: tool_t, [string]: tool_t }

--- @package
--- @alias toolChangerConfig_t { scaffolding: string[], toolMap: toolMap_t, getFreeSlot: getFreeSlot_t, getNewItem: getNewItem_t }

-- NOTE: private variables

--- @package
--- @type toolChangerConfig_t config for this library
local __config

-- NOTE: private functions

--- @package
--- private function, iterates through inventory
local function __getItem(name)
    -- for each turtle slot
    for i = 1, 16, 1 do
        local data = turtle.getItemDetail(i)
        if data and data.name == name then
            return i
        end
    end
end

--- private function to equip a peripheral
--- @param tool tool_t peripheral to equip
--- @return boolean success result of the operation
local function __equipTool(tool)
    -- save the current slot just incase
    local oldSlot = turtle.getSelectedSlot()
    local toolSlot, itemSlot

    if ToolChanger.getCurrentTool() == tool.peripheral then
        return true
    end

    -- get the tool we need
    toolSlot = __getItem(tool.peripheral)

    if toolSlot then
        turtle.select(toolSlot)
        turtle.equipRight()

        if tool.select then
            itemSlot = __getItem(tool.select)
            turtle.select(itemSlot)
        else
            turtle.select(oldSlot)
        end

        return true
    end

    -- if it can't be found
    return false
end

-- NOTE: public functions

--- application specific function to set config
--- @param config toolChangerConfig_t
function ToolChanger.setConfig(config)
    __config = config
end

--- function to selct a block that can be used for scaffolding
--- @return function reset a function to reset the slot to where it was
function ToolChanger.selectScaffold()
    local oldSelect = turtle.getSelectedSlot()

    -- for each turtle slot
    for i = 1, 16, 1 do
        local data = turtle.getItemDetail(i)

        for j, v in ipairs(__config.scaffolding) do
            if data and data.name == v then
                turtle.select(i)
                break
            end
        end
    end

    return function()
        turtle.select(oldSelect)
    end
end

--- gives the current tool being used
--- @return string? name name of the tool being used or nil
function ToolChanger.getCurrentTool()
    if peripheral.getType("right") ~= nil then
        return __config.toolMap[peripheral.getType("right")].peripheral
    end

    local slot = __config.getFreeSlot()

    if slot then
        turtle.select(slot)

        turtle.equipRight()
        local item = turtle.getItemDetail()
        turtle.equipRight()

        return (item ~= nil and item.name or nil)
    end

    return nil
end

--- function to equip a standard diamond pickaxe
--- @return boolean success result of the operation
function ToolChanger.equipStandardMine()
    return __equipTool(__config.toolMap.standardMine)
end

--- function to equip the network modem
--- @return boolean success result of the operation
function ToolChanger.equipStandardModem()
    return __equipTool(__config.toolMap["modem"])
end

--- function to equip any tool
--- @param tool tool_t peripheral to equip
--- @return boolean success result of the operation
function ToolChanger.equipTool(tool)
    return __equipTool(tool)
end

--- function to check the durability of any tool
--- @param tool tool_t peripheral to equip
--- @param threshold integer percent at which the tool is deemed too damaged
function ToolChanger.checkTool(tool, threshold)
    local data

    if tool.select then
        data = turtle.getItemDetail(__getItem(tool.select), true)
    else
        data = turtle.getItemDetail(__getItem(tool.peripheral), true)
    end

    ---@diagnostic disable-next-line: undefined-field
    if data and data.durability < .1 then
        __config.getNewItem(data.name)
    end
end

-- NOTE: export statement
return ToolChanger
