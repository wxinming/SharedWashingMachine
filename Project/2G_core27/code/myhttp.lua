--[[
http模块，用于通讯
]]
module(...,package.seeall)
require"http"
require"algorithm"

local ADDR,PORT="f.okook.com",80

local connect,httpclient,http_switch

local function print(...)
	_G.print("myhttp",...)
end

local function discb()
	print("http disconnected")
end

local function setsn_cb(v)
	if v then
		rtos.restart()
	else
		print("failed to set sn")
	end
end

local function parse_http_data(data)
	local json_data,result,err = json.decode(data)
	if result then
		print("json_data[sn]",json_data["sn"])
		print("json_data[style]",json_data["style"])
		print("json_data[append]",json_data["append"])
		if json_data["sn"] ~= "0" and json_data["sn"] ~= misc.getsn() then
			local append,style = json_data["append"],json_data["style"]
			if append then
				style = style.."c"
			end
			if algorithm.set_config_style(style) then
				print("set_config_style success")
				misc.setsn(json_data["sn"],setsn_cb)
			end
		else
			print("invalid sn or equal sn")
		end
	else
		print("json.decode error",err)
	end
end

local function http_getsn_cb(result,statuscode,head,body)
	if result == 0 then
		parse_http_data(body)
	end
	httpclient:disconnect(discb)
end

local function connectedcb()
	--httpclient:request("GET","/index.php/api/getdata/getdevice?".."id="..misc.getimei().."&ac=getsecret",{},"",http_getsn_cb)
	httpclient:request("GET","/index.php/api/getdata/getdevicenew?id="..misc.getimei().."&ac=getsecret",{},"",http_getsn_cb)
end 

local function discb_err()
	print("$failed to send http get request")
end

--[[
	函数名：sckerrcb
	功能  ：SOCKET失败回调函数
	参数  ：
		r：string类型，失败原因值
		CONNECT: socket一直连接失败，不再尝试自动重连
		SEND：socket发送数据失败，不再尝试自动重连
	返回值：无
	重新完善了,http请求失败的处理.
]]
local function sckerrcb(r)
	if r == "CONNECT" then
		print("$http reconnect")
		connect()
	elseif r == "SEND" then
		print("$http send error")
		httpclient:disconnect(discb_err)
	else
		print("$http unknow error")
	end
end

connect = function()
	print("$http connecting")
	httpclient:connect(connectedcb,sckerrcb)
end

function http_run()
	if not http_switch then
		httpclient=http.create(ADDR,PORT)
		httpclient:setconnectionmode(false)
		connect()
		http_switch = true
	end
end
