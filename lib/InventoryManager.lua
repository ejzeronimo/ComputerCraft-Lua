-- functions for managing the turtle inventory
local InventoryManager = {}

-- NOTE: classes and types

--- @alias returnedItem_t turtleDetails|turtleDetailsDetailed|{name: string, count: number, [string]: any} catch all for item information returned

--- function to get an array of items from a storage block
--- @alias getItems_t fun(): returnedItem_t[]

--- function to to handle getting an item
--- @alias getItemHandler_t fun(g: getItems_t, s: suckItem_t): boolean

--- @class remoteStorage_t
--- @field item string the item name
--- @field getItems getItems_t function to get the items
--- @field placeStorage placeBlock_t function to place the storage block
--- @field breakStorage breakBlock_t function to break the storage block
--- @field dropItem dropItem_t function to put items into the storage block
--- @field suckItem suckItem_t function to get items from the storage block

--- @class inventorManagerConfig_t config for this library
--- @field blacklist string[] array of items not to remotely store
--- @field scaffolding string[] array for blocks the turtle might place
--- @field minScaffolding number minimum number of blocks of scaffoling the turtle must have
--- @field remoteStorage remoteStorage_t remoteStorage object

-- NOTE: private variables

--- @type inventorManagerConfig_t config for the library
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

-- NOTE: public functions

--- application specific function to set config
--- @param config inventorManagerConfig_t
function InventoryManager.setConfig(config)
    __config = config
end

--- get a free slot in the turtle, or makes one
--- @param name? string name of the item to check for
--- @return number|nil index returns a number if successful or nil if failed
function InventoryManager.getFreeSlot(name)
    local count, space, data

    for i = 1, 16, 1 do
        count = turtle.getItemCount(i)
        space = turtle.getItemSpace(i)
        data = turtle.getItemDetail(i)

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

--- find the item index given the name
--- @param name string name of the item to check for
--- @return number|nil index returns a number if successful or nil if failed
function InventoryManager.findItem(name)
    local data

    for i = 1, 16, 1 do
        data = turtle.getItemDetail(i)

        if data and data.name == name then
            return i
        end
    end

    return nil
end

--- empties the inventory
function InventoryManager.emptyInventory()
    local hasScaffold = false
    local item

    -- place the storage block
    __config.remoteStorage.placeStorage()

    -- go through and empty inventory
    for j = 1, 16, 1 do
        item = turtle.getItemDetail(j)
        -- if not a tool
        if item and not __inList(__config.blacklist, item.name) and item ~= __config.remoteStorage.item then
            if __inList(__config.scaffolding, item.name) and (not hasScaffold and item.count >= __config.minScaffolding) then
                -- do nothing
                hasScaffold = true
            else
                -- put it in the storage
                turtle.select(j)
                __config.remoteStorage.dropItem()
            end
        end
    end

    -- break the storage block
    __config.remoteStorage.breakStorage()
end

--- gets a new item, if no handler defined then it gets a new item
--- @param item string the name of the item to replace
--- @param handler? getItemHandler_t function to handle getting the new item
function InventoryManager.getNewItem(item, handler)
    local data, success, items = nil, false, nil

    -- place the storage block
    __config.remoteStorage.placeStorage()

    -- select the old item, it must not pass the condition
    for i = 1, 16, 1 do
        data = turtle.getItemDetail(i, true)
        if data and data.name == item then
            turtle.select(i)

            while not __config.remoteStorage.dropItem() do
                sleep(0)
            end
            break
        end
    end


    -- if there is an external handler
    if handler then
        while not success do
            success = handler(__config.remoteStorage.getItems, __config.remoteStorage.suckItem)
        end
    else
        while not success do
            -- for each item in storage
            items = __config.remoteStorage.getItems()

            for k, v in pairs(items) do
                if v.name == item then
                    __config.remoteStorage.suckItem()
                    success = true
                end
            end
        end
    end

    -- break the block after we are done
    __config.remoteStorage.breakStorage()
end

-- NOTE: export statement
return InventoryManager
