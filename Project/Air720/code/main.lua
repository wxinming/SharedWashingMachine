--         ┌─┐       ┌─┐
--      ┌──┘ ┴───────┘ ┴──┐
--      │                 │
--      │       ───       │
--      │  ─┬┘       └┬─  │
--      │                 │
--      │       ─┴─       │
--      │                 │
--      └───┐         ┌───┘
--          │         │
--          │         │
--          │         │
--          │         └──────────────┐
--          │     神兽保佑                       │
--          │                        ├─┐
--          │         ＮＯ    ＢＵＧ       ┌─┘
--          │                        │
--          └─┐  ┐  ┌───────┬  ┐  ┌──┘
--            │ ─┤ ─┤       │ ─┤ ─┤
--            └──┴──┘       └──┴──┘
--[[
    Air202(2G)和Air720(4G)通用代码,可以随意更改移植.
    只需修改FRAMEWORK变量即可
]]

--@author  王浩
--@release 2018:10:13:18:00
FRAMEWORK = "AIR720"

if FRAMEWORK == "AIR202" then
    PROJECT = "AIR202"
    VERSION = "1.0.0"
elseif FRAMEWORK == "AIR720" then
    PROJECT = "AIR720"
    VERSION = "1.0.0"
end

require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE

require "sys"
require "net"
net.startQueryAll(60000,60000)

require "netLed"
if FRAMEWORK == "AIR202" then
    netLed.setup(true,pio.P1_1)
elseif FRAMEWORK == "AIR720" then
    netLed.setup(true,pio.P2_0)
end

--require "errDump"
--errDump.request("udp://ota.airm2m.com:9072")

if FRAMEWORK == "AIR202" then
    PRODUCT_KEY = "bpRyE77QKhHGd7urLkSioC3tHYYRctFw"
elseif FRAMEWORK == "AIR720" then
    PRODUCT_KEY = "utjTDzOTGGj4w617fR5mHaPbk4kGLBHn"
end

require "update"
update.request()

require "myInit"
sys.init(0, 0)
sys.run()

collectgarbage("setpause",90)
