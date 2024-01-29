--[[
    NOTE: blows up when there is a player in range that is in the text file
--]]

print("Starting 'BoomTurtle Entertainment Extravaganza'...")

--- @class playerDetctor_t
--- @field getPlayersInRange fun(n: number): table

--- @type playerDetctor_t
--- @diagnostic disable-next-line: assign-type-mismatch
local playerDetector = peripheral.wrap("right")

-- NOTE: the main loop
-- until we get the stop message
while true do
    local players = playerDetector.getPlayersInRange(16)

    for index, value in ipairs(players) do
        if value ~= "riggyz505" then
            print("Boom boom boom boom, I want you in mye room <3")
            redstone.setOutput("top", true)
        end
    end

    os.sleep(20)
end
