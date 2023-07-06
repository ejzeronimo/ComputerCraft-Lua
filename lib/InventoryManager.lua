-- functions for managing the turtle inventory
local InventoryManager = {}

-- NOTE: classes and types

--- @package
--- @alias place_t fun(): boolean function to place a block

--- @package
--- @alias break_t fun(): boolean function to break a block

--- @package
--- @alias suck_t fun(): boolean function to take item from the inventory

--- @package
--- @alias drop_t fun(): boolean function to place item from the inventory

--- @package
--- @type item_t
--- @class item_t
local item_t = {
    --- the item name
    item = ""
}

--- @package
--- @type remoteStorage_t
--- @class remoteStorage_t: item_t
local remoteStorage_t = {
    --- is the item managed by another turtle
    remotelyManaged = false
}

--- @package
--- @alias inventorManagerConfig_t { blacklist: string[], remoteStorage: remoteStorage_t, place: place_t }

-- NOTE: private variables

--- @package
--- @type inventorManagerConfig_t does things
local __config


-- NOTE: private functions

--- function to check if in a list
--- @param arr string[] array of items to search
--- @param val string the name to check for
--- @return boolean inList if the item is in the list
local function __inList(arr, val)
    for index, value in ipairs(arr) do
        -- we grab the first index of our sub-table instead
        if value == val then
            return true
        end
    end

    return false
end

local function __placeStorage()
    -- place entangloporter
    for i = 1, 16, 1 do
        local data = turtle.getItemDetail(i)
        if data and data.name == "mekanism:quantum_entangloporter" then
            turtle.select(i)
            safeTurtle.placeUp()
            break
        end
    end
end


-- NOTE: public functions

--- get a free slot in the turtle, or makes one
--- @param name? string name of the item to check for
--- @return number|nil index returns a number if successful or nil if failed
function InventoryManager.getFreeSlot(name)
    for i = 1, 16, 1 do
        local count = turtle.getItemCount(i)
        local space = turtle.getItemSpace(i)
        local data = turtle.getItemDetail(i)

        if count and data and name then
            if data.name == name and space ~= 0 then
                return i
            end
        elseif count == 0 then
            return i
        end
    end

    -- empty inventory if we hit this point
    InventoryManager.emptyInventory()
    return nil
end

--- empties the inventory
function InventoryManager.emptyInventory()
    local hasScaffold = false

    __placeStorage()

    -- TODO: make this ask for permission first

    -- go through and empty inventory
    for j = 1, 16, 1 do
        local item = turtle.getItemDetail(j)
        -- if not a tool
        if item and not __inList(__config.blacklist, item.name) then
            if __inList(ToolChanger.__scaffolding, item.name) and (not hasScaffold and item.count >= 16) then
                -- do nothing
                hasScaffold = true
            else
                -- try to put it in the entangloporter
                turtle.select(j)
                local success, error = turtle.dropUp()

                while not success and error == "no space for items" do
                    -- sleep for a bit
                    sleep(.5)
                end
            end
        end
    end

    -- since this can be called anywhere in the code, we need to ensure that the right tool is on
    local tool = ToolChanger.getCurrentTool()

    ToolChanger.equipStandardMine()
    safeTurtle.digUp()

    switch = {
        ["modem"] = function()
            ToolChanger.equipModem()
        end,
        ["weakAutomata"] = function()
            ToolChanger.equipSilkMine()
        end,
        ["minecraft:diamond_pickaxe"] = function()
            -- do nothing
        end,
    }

    switch[tool]()
end

function InventoryManager.getNewTool()
    local success = false
    local curTool = ToolChanger.getCurrentTool()

    -- put down the remote storage
    inventoryManager.__placeStorage()

    -- get it as a peripheral
    local remote = peripheral.wrap("top")

    -- select the pickaxe
    for i = 1, 16, 1 do
        local data = turtle.getItemDetail(i)
        if data and data.name == "minecraft:netherite_pickaxe" then
            turtle.select(i)
            break
        end
    end

    -- just in case we have the wrong item
    while not success do
        -- request tool fix
        local valid, refreshRequest, completeRequest = TurtleNet.client.requestToolRepair()

        -- while we cannot
        while not valid do
            valid, refreshRequest, completeRequest = refreshRequest()
            sleep(0)
        end

        turtle.dropUp()

        -- while there is not a pickaxe with full health
        ---@diagnostic disable-next-line: need-check-nil
        local info = remote.getBufferItem()

        while info.nbt.Damage ~= 0 and info.name ~= "minecraft:netherite_pickaxe" do
            ---@diagnostic disable-next-line: need-check-nil
            info = remote.getBufferItem()
            sleep(0)
        end

        turtle.suckUp()

        local data = turtle.getItemDetail(turtle.getSelectedSlot())

        if data and data.name == "minecraft:netherite_pickaxe" then
            completeRequest()

            success = true
        else
            sleep(5)
        end
    end

    -- equip pickaxe
    if curTool ~= "minecraft:diamond_pickaxe" then
        ToolChanger.equipStandardMine()
    end

    safeTurtle.digUp()

    -- TODO: change tool back
end

-- NOTE: export statement
return InventoryManager
