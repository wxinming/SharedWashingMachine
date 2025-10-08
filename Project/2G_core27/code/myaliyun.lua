module(...,package.seeall)
require"aliyuniotssl"
require"sys"
require"aliyuniotota"
require"mylbs"
require"misc"
require"body"
PRODUCT_KEY = "CKeWl7aRY0y"

local get_location,counter,status = true,0,""

local function send_mqtt_messagecb(usertag,result)
	if result then
		print("SEND MQTT MESSAGE SUCCESS")
	else
		print("SEND MQTT MESSAGE FAILURE")
	end
end

function send_mqtt_message(payload)
	local json_data = json.encode(payload)
	aliyuniotssl.publish("/"..PRODUCT_KEY.."/"..misc.getimei().."/post",json_data,0,send_mqtt_messagecb,"MQTTMSG")
end

local function get_error()
	local err_data = sys.getextliberr()
	if err_data == "" then
		send_mqtt_message({id=misc.getimei(),error="null"})
	else
		send_mqtt_message({id=misc.getimei(),error=err_data})
	end
end

--[[
	解析收到的Qos = 0的MQTT消息
	此处解析的其他命令,包含的字母或数字一定要有一个超过0~9&&A~F的ASCII码范围,否则会当做串口数据发送
]]
local function parse_data(payload)
	--接收从服务器发送的%d+,%w+,%w+,%d+格式进行解析,发送串口1数据
	if algorithm.recv_server_hex(payload) then
		print("SEND UART DATA SUCCESS")
	--重启模块指令
	elseif payload == "reboot" then
		rtos.restart()
	--获取串口设备是否在工作，true代表不在工作，false代表正在工作中，或者为离线状态
	elseif payload == "get_uart_status" then
		send_mqtt_message({id=misc.getimei(),mode="query",breakdown=tostring(myuart.uart_breakdown),working=tostring(myuart.uart_working),signal=net.getrssi()})
	--获取脉冲设备是否在工作，true代表不在工作，false代表正在工作中，或者为离线状态
	elseif payload == "get_gpio_status" then
		send_mqtt_message({id=misc.getimei(),mode="query",working=tostring(pincfg.gpio_working),signal=net.getrssi()})
	--获取模块部分数据
	elseif payload == "get_data" then
		mylbs.qrygps()
	--获取模块错误信息
	elseif payload == "get_error" then
		get_error()
	--设置配置文件,成功将重启
	elseif algorithm.set_config_file(payload) then
		rtos.restart()
	--其他消息
	else
		send_mqtt_message({id=misc.getimei(),msg="uartmsg"})
	end
end

--[[
	MQTT的消息回调函数
]]
local function rcvmessagecb(topic,payload,qos)
	--print("rcvmessagecb topic = "..topic.." payload = "..payload.." qos = "..qos)
	if qos == 0 then
		parse_data(payload)
	else
		if algorithm.recv_server_gpio(payload) then
			print("SEND GPIO DATA SUCCESS")
		else
			send_mqtt_message({id=misc.getimei(),msg="gpiomsg"})
		end
	end
end

local function subackcb(usertag,result)
	print("subackcb",usertag,result)
	if result then
		print("SUBSCRIBE TO THE TOPIC SUCCESS")
	else
		print("SUBSCRIBE TO THE TOPIC FAILURE")
	end
end

local function connectedcb()
	print("CONNECT MQTT SERVER SUCCESS")
	aliyuniotssl.subscribe({{topic="/"..PRODUCT_KEY.."/"..misc.getimei().."/get",qos=0},
	{topic="/"..PRODUCT_KEY.."/"..misc.getimei().."/get",qos=1}},subackcb,"subscribegetopic")
	--注册事件的回调函数，MESSAGE事件表示收到了PUBLISH消息
	aliyuniotssl.regevtcb({MESSAGE=rcvmessagecb})
	
	--mqtt连接成功发送当前模块数据
	if get_location then
		get_location = false
		if rtos.poweron_reason() == 0 then
			mylbs.qrygps()
		else
			send_mqtt_message({
				id=misc.getimei(),signal=net.getrssi(),
				version="2G_"..string.sub(sys.getcorever(),9,10).."_".._G.VERSION,
				reason=rtos.poweron_reason(),style=body.style
			})
		end
	end
end

local function connecterrcb(r)
	print("CONNECT MQTT SERVER FAILURE",r)
end

local function loop_get_status()
	status = aliyuniotssl.getMqttStatus()
	if status ~= "CONNECTED" then
		if counter >= 5 then
			sys.restart("MQTT TIMEOUT")
		end
		counter = counter + 1
	else
		counter = 0
	end
	print("MQTT STATUS:",status,counter)
end

function initaliyunmqtt()
	aliyuniotssl.setMqtt(nil,nil,120)
	aliyuniotssl.config(PRODUCT_KEY,nil,misc.getimei(),misc.getsn())
	aliyuniotssl.regcb(connectedcb,connecterrcb)
	sys.timer_loop_start(loop_get_status,60000)
end
