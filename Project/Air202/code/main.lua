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

--Air202(2G)和Air720(4G)通用代码,可以随意更改移植.
--只需修改PROJECT变量即可

--@release 2018:12:25:18:00
--@author WangHao
--@email 656325437@qq.com
--@note 所有lua文件结尾必须多一个换行
--@note PRODUCT_KEY代表官方更新服务器和获取经纬度唯一ID
--@note 关于更新服务器和经纬度服务器
--      URL(AES加密):U2FsdGVkX19ZkUuSh1MDguXILD1GTo04XDBbr/lKLbt8EZa+jleFLYZPdDYo89SC
--      账号(AES加密):U2FsdGVkX19KluxRhkEsStqnueMtyGNvk2S4VjpYZi8=
--      密码(AES加密):U2FsdGVkX1+gjMUrprBnGygwFSs6ZziuGldG5wUaz6w=
--      AES密码为后台admin登陆密码
PROJECT = "AIR202"

if PROJECT == "AIR202" then
    VERSION = "1.0.0"
	PRODUCT_KEY = "bpRyE77QKhHGd7urLkSioC3tHYYRctFw"
elseif PROJECT == "AIR720" then
    VERSION = "1.0.0"
	PRODUCT_KEY = "utjTDzOTGGj4w617fR5mHaPbk4kGLBHn"
end

--日志级别设置
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE

require "sys"
require "net"
--60s查询信号强度和基站信息
net.startQueryAll(60000,60000)

--启动网络指示灯
require "netLed"
if PROJECT == "AIR202" then
    netLed.setup(true,pio.P1_1)
elseif PROJECT == "AIR720" then
    netLed.setup(true,pio.P2_0)
end

--@note 模块内部报错上传是否使用,报错服务器按照协议自己搭建(未完成)
--require "errDump"
--errDump.request("udp://ota.airm2m.com:9072")

--@note	此处连接官方更新服务器,更新固件取决于PRODUCT_KEY
require "update"
update.request()

--初始化模块所有所需功能
require "myInit"

--初始化模块框架
sys.init(0, 0)
sys.run()

--90s一次回收内存垃圾
collectgarbage("setpause",90)
