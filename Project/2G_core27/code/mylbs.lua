--[[
定位模块
]]
module(...,package.seeall)
require"lbsloc"
require"myaliyun"
require"body"
require"misc"
require"sim"
require"net"
require"sys"

local function myquery(lat,lng)
	local mydata = {
		id=misc.getimei(),iccid=sim.geticcid(),
		lat=lat,lng=lng,signal=net.getrssi(),
		version="2G_"..string.sub(sys.getcorever(),9,10).."_".._G.VERSION,
		reason=rtos.poweron_reason(),style=body.style
	}
	myaliyun.send_mqtt_message(mydata)
end

--[[
	1.函数名:getgps
	2.函数功能:获取地理位置
	3.参数:略
	4.返回值:无
]]
local function getgps(result,lat,lng,addr,latdm,lngdm)
	if result ~= 0 then
		lat,lng = 0,0
	end
	myquery(lat,lng)
end

--[[
	1.函数名:qrygps
	2.函数功能:请求基站定位
	3.返回值:无
]]
function qrygps()
	if net.getrssi() >= 15 then
		lbsloc.request(getgps,false)
	else
		myquery(0,0)
	end
end
