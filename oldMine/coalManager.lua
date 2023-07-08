local modem = peripheral.wrap("back")
local chest = peripheral.wrap("left")

local fuel = "minecraft:coal"

--pastebin get kSL7Xk3z manager

while true do
    --check the chest
    for k, v in pairs(chest.list()) do
        --if the item is coal
        if v.name == fuel and k > 3 then
            chest.pushItems("west",k)
        elseif (v.name == fuel  or v.name == nil)and k < 4 then
            chest.pullItems("west",2,64,k)
        end
    end    
end