local module = {}
local run = false

local host = 'localhost'
local port = 1883
local username = nil
local password = nil
local prefix = 'homed'

local json = require('cjson')
local mosq = require('mosquitto')
local mqtt = mosq.new()

local loop = coroutine.create(function()
    local tick = os.time()

    while run do
        local now = os.time()

        if tick ~= now then
            module.tickEvent(now)
            tick = now
        end
    end
end)

function module.tickEvent(timestamp) end
function module.deviceEvent(service, device, endpoint, data) end

function module.deviceRequest(service, device, endpoint, data)
    local topic = prefix .. '/td/' .. service .. '/' .. device

    if endpoint and endpoint ~= 0 then
        topic = topic .. '/' .. endpoint
    end

    mqtt:publish(topic, json.encode(data))
end

function module.setHost(value) host = value end
function module.setPort(value) port = value end
function module.setUsername(value) username = value end
function module.setPassword(value) password = value end
function module.setPrefix(value) prefix = value end

function module.start()
    run = true
    mqtt:login_set(username, password)
    mqtt:connect(host, port)
    mqtt:loop_start()
    coroutine.resume(loop)
end

function module.stop()
    run = false
    mqtt:disconnect()
    mqtt:loop_stop()
end

mqtt.ON_CONNECT = function()
    print('mqtt connected')
    mid = mqtt:subscribe(prefix .. '/fd/#', 0)
end

mqtt.ON_DISCONNECT = function()
    print('mqtt disconnected')

    if (run) then
        mqtt:reconnect()
    end
end

mqtt.ON_MESSAGE = function(mid, topic, payload)
    local list = {}

    for item in topic:gsub(prefix .. '/fd/', ''):gmatch('([^/]+)') do
        table.insert(list, item)
    end

    module.deviceEvent(list[1], list[2], list[3], json.decode(payload))
end

return module
