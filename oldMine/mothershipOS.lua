--startup script for the Mothership
local args = {...}
local monitor = peripheral.find("monitor")
local modem = peripheral.find("modem")

function manager(event, modemSide, senderChannel, replyChannel, message, senderDistance)
    monitor.setCursorPos(1, 1)
    monitor.scroll(-1)
    monitor.write(message)
end

--redirect to screen
monitor.clear()
monitor.setCursorBlink(true)
monitor.setCursorPos(1, 1)
monitor.write("Redirected to screen ...")

--open modem on proper channel
modem.open(2)
monitor.setCursorPos(1, 1)
monitor.scroll(-1)
monitor.write("Modem opened on proper channel ...")

--start loop
monitor.setCursorPos(1, 1)
monitor.scroll(-1)
monitor.write("Starting event loop ...")
while true do
    local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
    manager(event, modemSide, senderChannel, replyChannel, message, senderDistance)
    --keep alive
    os.sleep(.0001)
end
