--[[
    This downloads from GitHub the correct application and all Lib files

    Pastebin link: https://pastebin.com/SX7mYFmk
--]]

-- NOTE: types

--- @class githubLinks_t
--- @field self string
--- @field git string
--- @field html string

--- @class githubFile_t
--- @field name string
--- @field path string
--- @field sha string
--- @field size number
--- @field url string
--- @field html_url string
--- @field git_url string
--- @field download_url string
--- @field type string
--- @field _links githubLinks_t

-- NOTE: code
local args = { ... }

local application = args[1]
local branch = args[2]

-- default to master branch just in case
if branch == nil then
    branch = "master"
end

-- generate the startup script
if not fs.exists("./startup.lua") then
    -- make the new file
    local file = fs.open("./startup.lua", "w")

    ---@diagnostic disable: need-check-nil
    file.write('shell.run("./bootloader.lua ' .. application .. ' ' .. branch .. '")')
    file.close()
    ---@diagnostic enable: need-check-nil

    print("Generated startup script")
end

-- download all the libs
local rawRequest = http.get("https://api.github.com/repos/ejzeronimo/cc-lua/contents/lib?ref=" .. branch)
--- @diagnostic disable-next-line: need-check-nil
local requestData = rawRequest.readAll()

if requestData then
    --- @type githubFile_t[]
    --- @diagnostic disable-next-line: assign-type-mismatch
    local libArray = textutils.unserializeJSON(requestData)

    for index, value in ipairs(libArray) do
        -- for each file get the raw content
        local content = http.get(value.download_url).readAll()

        if content ~= nil then
            -- delete old file
            fs.delete("./lib/" .. value.name)

            -- make the new file
            local file = fs.open("./lib/" .. value.name, "w")

            ---@diagnostic disable: need-check-nil
            file.write(content)
            file.close()
            ---@diagnostic enable: need-check-nil

            print("Downloaded lib/" .. value.name)
        end
    end
end

if application then
    -- now that the libs are downloaded we can run our application
    if not fs.exists("./" .. application .. ".lua") then
        rawRequest = http.get("https://api.github.com/repos/ejzeronimo/cc-lua/contents/" ..
        application .. ".lua?ref=" .. branch)
        --- @diagnostic disable-next-line: need-check-nil
        requestData = rawRequest.readAll()

        if requestData then
            --- @type githubFile_t
            --- @diagnostic disable-next-line: assign-type-mismatch
            local value = textutils.unserializeJSON(requestData)
            local content = http.get(value.download_url).readAll()

            if content ~= nil then
                -- delete old file
                fs.delete(value.name)

                -- make the new file
                local file = fs.open("./" .. value.name, "w")

                ---@diagnostic disable: need-check-nil
                file.write(content)
                file.close()
                ---@diagnostic enable: need-check-nil

                print("Downloaded " .. value.name)
            end
        end
    end

    for i = 10, 1, -1 do
        print("Starting in " .. i .. "...")
        sleep(1)
    end

    -- now run the function
    print("Starting application")
    shell.run("./" .. application .. ".lua")
end
