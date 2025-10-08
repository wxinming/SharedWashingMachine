module(...,package.seeall)
require"myInit"
require"myUart"
require"sys"
require"net"

--根据风格设置配置文件
--@param  style:设备风格
--@return bool:成功true,失败false
function setConfigStyle(style)
	if not style then return false end
	local content = ""
	if style == "uartc" then
		content = "config\
		<style:uartc>\
		<1:AA20DBFB00000000000202FF01FF09052001030303000000FFFF00FFFFFFFFFFD6>\
		<2:AA20DBFB00000000000202FF01FF02052001030100010100FFFF00FFFFFFFFFFE0>\
		<3:AA20DBFB00000000000202FF01FF03052001030003010100FFFF00FFFFFFFFFFDD>\
		<4:AA20DBFB00000000000202FF01FF03052001030103010100FFFF00FFFFFFFFFFDC>\
		<5:AA20DBFB00000000000202FF01FF03052003030103010100FFFF00FFFFFFFFFFDA>\
		<6:AA20DBFB00000000000202FF01FF16000100040000000000FFFF0000FFFFFFFFF2>\
		<7:AA20DBFB00000000000202FF01FF03052101030000010100FFFF0000FFFFFFFFDE>"
	elseif style == "uart" then
		content = "config\
		<style:uart>"
	elseif style == "pul_uart" then
		content = "config\
		<style:pul_uart>"
	elseif style == "pul_uartc" then
		content = "config\
		<style:pul_uartc>\
		<1:AA1EDAC400000000000202FF01FF1BFFFF00FFFFFFFFFFFFFFFFFFFFFFFF34>\
		<2:AA1EDAC400000000000202FF01FF01FFFF00FFFFFFFFFFFFFFFFFFFFFFFF4E>\
		<3:AA1EDAC400000000000202FF01FF00FFFF00FFFFFFFFFFFFFFFFFFFFFFFF4F>\
		<4:AA1EDAC400000000000202FF01FF12FFFF00FFFFFFFFFFFFFFFFFFFFFFFF3D>"
	elseif string.sub(style,1,9) == "hili_uart" then
		content = "config\
		<style:hili_uart>"
	elseif string.sub(style,1,4) == "gpio" then
		content = "config\
		<style:gpio>"
	else
		return false
	end
	return writeFile("/config.txt",content)
end

--设置配置文件
--@param  value:配置文件数据
--@return bool:成功true,失败false
function setConfigFile(value)
	--[[
	local action,style,result = string.match(value,"<action:(%a+)>"),getStyle(value),false
	if action == "config" and style ~= "" then
		result = writeFile("/config.txt",value)
	else
		result = false
	end
	return result
	]]
	local result = false
	if string.sub(value,1,6) == "config" and getStyle(value) ~= "" then
		result = writeFile("/config.txt",string.sub(value,7,#value))
	end
	return result
end

--获取配置文件风格
--@param  value:配置文件数据
--@return string:设备风格
function getStyle(value)
	local data = string.match(value,"<style:(%a+)>") or
	string.match(value,"<style:(%a+%p+%a+)>")
	if not data then data = "" end
	return data
end

--获取最大金额和最大串口指令
--@param  无
--@return number:最大金额
--@return string:最大串口指令
function getMaxMoneyHex()
	local temp_n,temp_hex,hex,max = "","","",-1
	local file = io.open("/config.txt","r")
	if file then
		for line in file:lines() do
			temp_n,temp_hex = string.match(line,"<(%d+):(%w+)>")
			if temp_n then
				temp_n = tonumber(temp_n)
				if max < temp_n then
					max = temp_n
					hex = temp_hex
				end
			end
		end
		file:close()
	end
	return max,hex
end

--根据value获取串口投币指令
--@param  value:投币金额
--@return string:金额对应串口指令
function getUartCoinHex(value)
	local data,hex = myInit.configData,nil
	local hex = string.match(data,"<"..tostring(value)..":(%w+)")
	if not hex then hex = "" end
	return hex
end

--获取单片机校验码
--@param  hex:十六进制字符串
--@return string:校验码
function getMcuCc(hex)
	local num,len = 0,string.len(hex)
	for i = 1,len,2 do
		if i == len - 1 then
			break
		end
		num = num + tonumber(string.sub(hex,i,i + 1),16)
	end
	return string.sub(string.format("%X",num),-2,-1)
end

--获取海尔校验码
--@param  hex:十六进制字符串
--@return string:校验码
function getHaierCc(hex)
	local sum,len = 0,string.len(hex)
	for i = 1,len,2 do
		if i == len - 1 then
			sum = sum + 2
			break
		end
		sum = sum + tonumber(string.sub(hex,i,i+1),16)
	end
	return string.sub(string.format("%X",tostring(sum)),2,3)
end

--获取单片机脉冲3时间校验码
--@param  hex:十六进制字符串
--@return string:校验码
function getTimeCc(hex)
	local num,len = 0,string.len(hex)
	for i = 1,len,2 do
		num = num + tonumber(string.sub(hex,i,i + 1),16)
	end
	return string.sub(string.format("%X",num),-2,-1)
end

--获取美的校验码
--@param  hex:十六进制字符串
--@return string:校验码
function getMideaCc(hex)
	local mylen = string.len(hex)
	local total,head = 0,tonumber(string.sub(hex,1,2),16)
	for i = 1,mylen,2 do
		if i == mylen - 1 then
			break
		end
		total = total + tonumber(string.sub(hex,i,i + 1),16)
	end
	return string.sub(string.format("%X",head-total),-2,-1)
end

--获取网络模式
--@note   获取到的模式由_G.FRAMEWORK决定
--@param  无
--@return string:网络模式
function getNetMode()
	local mode,result = 0,""
	if _G.FRAMEWORK == "AIR720" then
		mode = net.getnetmode()
		if mode == 0 then
			result = "noNet"
		elseif mode == 1 then
			result = "2G_GSM"
		elseif mode == 2 then
			result = "2.5G_EDGE"
		elseif mode == 3 then
			result = "3G_TD"
		elseif mode == 4 then
			result = "4G_LTE"
		elseif mode == 5 then
			result = "3G_WCDMA"
		else
			result = "unknow"
		end
	elseif _G.FRAMEWORK == "AIR202" then
		result = "2G_GSM_ONLY"
	end
	return result
end

--写入文件
--@param  path:文件路径
--@param  content:要写入的文本内容
--@return bool:成功true,失败false
function writeFile(path,content) 
	local file = io.open(path,"w")
	if not file then return false end
	file:write(content)
	file:close()
	return true
end

--读取文件
--@param  path:文件路径
--@return string:读取成功返回文件内容,失败返回""
function readFile(path)
	local file,data = io.open(path,"r"),""
	if not file then return data end
	data = file:read("*a")
	file:close()
	return data
end

--向串口写入字符串
--@param  port:串口号
--@param  hex:十六进制字符串
--@return bool:成功true,失败false
function uartWriteStr(port,hex)
	if not port or not hex then
		log.info("algorithm.uartWriteStr","arguments port or hex exist a nil value")
		return false
	end
	local len,num = string.len(hex),0
	for i = 1,len,2 do
		num = tonumber(string.sub(hex,i,i + 1),16)
		if num then
			uart.write(port,num)
		else
			return false
		end
	end
	return true
end

--停止正在运行的定时器
--@param  调用定时器的回调函数
--@param  可变参数(定时器的标识)
--@return bool:成功true,失败false
function stopRunningTimer(callback,...)
	if sys.timerIsActive(callback,unpack(arg)) then
		log.info("algorithm.stopRunningTimer","success")
        sys.timerStop(callback,unpack(arg))
        return true
    end
    return false
end

--将秒转换成对应的十六进制脉冲3字符串
--@param  sec:秒
--@return stirng:十六进制字符串
--				时	分	秒
--BB	03	01	00	00	01	01	C0
function calcTime(sec)
	local head,reserved = "BB0301","01"
	local minu,hour = 0,0
    if sec > 60 then
    	minu = sec / 60
    	sec = sec % 60
    	if minu > 60 then
    		hour = minu / 60
    		minu = minu % 60
    	end
	end
	if sec < 16 then
		sec = "0"..string.format("%X",sec)
	else
		sec = string.format("%X",sec)
	end
	if minu > 0 then
		if minu < 16 then
			minu = "0"..string.format("%X",minu)
		else
			minu = string.format("%X",minu)
		end	
	else
		minu = "00"
	end
	if hour > 0 then
		if hour < 16 then
			hour = "0"..string.format("%X",hour)
		else
			hour = string.format("%X",hour)
		end	
	else
		hour = "00"
	end
	local data = head..hour..minu..sec..reserved
	data = data..getTimeCc(data)
	return data
end

--获取脉冲3倒计时
--@param  sec:秒
--@return string:时分秒
function getCountDown(sec)
    local minu,hour = 0,0
    if sec > 60 then
    	minu = sec / 60
    	sec = sec % 60

    	if minu > 60 then
    		hour = minu / 60
    		minu = minu % 60
    	end
    end
    local result = tostring(sec).."s"

    if minu > 0 then
    	result = tostring(minu).."m:"..result
    end

    if hour > 0 then
    	result = tostring(hour).."h:"..result
    end
    return result
end

--按照脉冲3十六进制格式转秒
--@param  hex:脉冲3十六进制
--@return number:秒
function hexToSec(hex)
	local time = hex:sub(7,12)
	local hour,min,sec = tonumber(time:sub(1,2),16),
	tonumber(time:sub(3,4),16),tonumber(time:sub(5,6),16)
	return hour * 60 * 60 + min * 60 + sec
end

--添加洗衣液
--@param  wtime:代表添加多久(单位s)
--@return bool:true成功,false失败
function addFluid(wtime)
	if not wtime or wtime > 120 then return false end
	return uartWriteStr(myUart.MCU_ID,calcTime(wtime))
end

--任务发送十六进制字符串
--@param  count:次数
--@param  time:延时时间
--@param  hex1:第一个十六进制字符串
--@param  hex2:第二个十六进制字符串
--@return 无
local function taskSendHex(count,time,hex1,hex2)
	for i = 1,count do
		if not myUart.uartWorking then
			break
		end
		uartWriteStr(myUart.UART_ID,hex1)
		sys.wait(time)
		uartWriteStr(myUart.UART_ID,hex2)
		sys.wait(time)
	end
end

--启动脉冲3时间时长(单位s)
uartWtime = 0

--解析服务器所发串口指令
--@param  str:服务器指令
--@return bool:成功true,失败false
function recvServerHex(str)
	local result = false
	local time,hex1,hex2,wtime = string.match(str,"<time:(%d+),hex1:(%w+),hex2:(%w+),wtime:(%d+)")
	if time then
		result = true
		time,uartWtime = tonumber(time),tonumber(wtime)
		if time <= 0 then time = 800 end
		
		if uartWriteStr(myUart.UART_ID,hex1) then
			sys.timerStart(uartWriteStr,time,myUart.UART_ID,hex2)
		end

		sys.taskInit(taskSendHex,10,time,hex1,hex2)
	else
		result = uartWriteStr(myUart.UART_ID,str)
	end
	return result
end

--启动脉冲2,延时时间(单位ms)
gpioDelayTime = 0

--解析服务器所发脉冲指令
--@param  str:服务器指令
--@return bool:成功true,失败false
function recvServerGpio(str)
	local result = false
	local time,hex1,wtime = string.match(str,"<time:(%d+),hex1:(%w+),hex2:%w+,wtime:(%d+)")
	if time then
		gpioDelayTime,wtime = tonumber(time),tonumber(wtime)
		result = uartWriteStr(myUart.MCU_ID,hex1)
		if result and wtime ~= 0 then
			sys.timerStart(addFluid,5000,wtime)
		end
	else
		result = uartWriteStr(myUart.MCU_ID,str)
	end
	return result
end
