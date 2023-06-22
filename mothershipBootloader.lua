--startup script for the Mothership
local args = {...}
local programName = "mothership"
local programCode = "ZEa0NR7k"

--on start fetch new version

if (fs.exists(programName) == false or args[1] == "update") then
    print("Case 2")
    shell.run("pastebin get " .. programCode .. " " .. programName)
elseif fs.exists(programName) == true then
    print("Case 2")
    shell.run("rm " .. programName)
    shell.run("pastebin get " .. programCode .. " " .. programName)
end

print("Mothership Booting Up ...")
shell.run(programName)