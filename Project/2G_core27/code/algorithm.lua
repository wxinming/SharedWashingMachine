--[[
算法文件,algorithm核心模块
]]
module(...,package.seeall)
require"sys"
require"misc"
require"body"

local function print(...)
	_G.print("algorithm",...)
end

--[[
1.函数功能:写文件
2.函数参数:path文件路径,2.content文本内容
3.返回值:成功 true，失败 false
]]
function write_file(path,content)
	local file = io.open(path,"w")
	if not file then return false end
	file:write(content)
	file:close()
	return true
end

--[[
1.函数功能：读文件
2.path文件路径
3.返回值：成功返回读取的数据，失败返回""(空)
]]
function read_file(path)
	local file,data = io.open(path,"r"),""
	if not file then return data end
	data = file:read("*a")
	file:close()
	return data
end

function set_config_style(style)
	if not style then
		print("set_config_style invalid argument")
		return false
	end
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
		print("set_config_style style not matche")
		return false
	end
	return write_file("/config.txt",content)
end

--[[
1.函数功能:向串口port，写入十六进制字符串
2.参数port:串口号，hex：要写入的十六进制字符串
3.返回值:true代表成功，false代表失败
]]
function uart_write_str(port,hex)
	if not port or not hex then
		print("function:uart_write_str exist a nil value")
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

--[[
1.函数功能：获取美的设备串口数据校验码
2.函数参数:hex代表16进制字符串
3.返回值：string
]]
function getcc_md(hex)
	local mylen = string.len(hex)
	local total,head = 0,tonumber(string.sub(hex,1,2),16)
	for i = 1,mylen,2 do
		if i == mylen - 1 then
			break
		end
		total = total + tonumber(string.sub(hex,i,i + 1),16)
	end
	return string.sub(string.format("%X",head - total),-2,-1)
end

--[[
1.函数功能:获取看门狗校验码
2.函数参数:hex代表16进制字符串
3.返回值:string
]]
function getcc_dog(hex)
	local num,len = 0,string.len(hex)
	for i = 1,len,2 do
		if i == len - 1 then
			break
		end
		num = num + tonumber(string.sub(hex,i,i + 1),16)
	end
	return string.sub(string.format("%X",num),-2,-1)
end

--[[
	1.函数功能:计算时间校验码
	2.函数参数:string类型十六进制字符串
	3.返回值:string
]]
function getcc_time(hex)
	local num,len = 0,string.len(hex)
	for i = 1,len,2 do
		num = num + tonumber(string.sub(hex,i,i + 1),16)
	end
	return string.sub(string.format("%X",num),-2,-1)
end

--[[
	1.函数功能:把秒换算成时分秒,再转成16进制字符串
	并发送
	2.函数参数:sec_t(string类型)秒,reserved_t预留参
	数00代表烘干机,01代表加洗衣液..以此类推
	3.返回值:成功 true 失败false
]]
--				时	分	秒
--BB	03	01	00	00	01	01	C0
function calc_time(sec)
	local head,reserved = "BB0301","01"
	local minu,hour=0,0
	
    if sec > 60 then
    	minu = sec / 60
    	sec = sec % 60
    	if minu > 60 then
    		hour = minu / 60
    		minu = minu % 60
    	end
    end
	--local result = tostring(sec).."sec"
	if sec < 16 then
		sec = "0"..string.format("%X",sec)
	else
		sec = string.format("%X",sec)
	end
	--print("sec",sec)

	if minu > 0 then
		--result = tostring(minu).."minu"..result
		if minu < 16 then
			minu = "0"..string.format("%X",minu)
		else
			minu = string.format("%X",minu)
		end	
	else
		minu = "00"
	end
	--print("minu",minu)
	
	if hour > 0 then
		--result = tostring(hour).."hour"..result
		if hour < 16 then
			hour = "0"..string.format("%X",hour)
		else
			hour = string.format("%X",hour)
		end	
	else
		hour = "00"
	end
	--print("hour",hour)

	--print("result",result)
	local data = head..hour..minu..sec..reserved
	data = data..getcc_time(data)
	--print("data",data)
    return uart_write_str(2,data)
end

--[[
	根据秒转换为时分秒
]]
function get_count_down(sec)
    local minu,hour = 0,0
    if sec > 60 then
    	minu = sec / 60
    	sec = sec % 60

    	if minu > 60 then
    		hour = minu / 60
    		minu = minu % 60
    	end
    end
    local result = tostring(sec).."sec"

    if minu > 0 then
    	result = tostring(minu).."minu"..result
    end

    if hour > 0 then
    	result = tostring(hour).."hour"..result
    end
    return result
end

--[[
	按照指定格式十六进制转秒
]]
function hextosec(hex)
	local time = hex:sub(7,12)
	local hour,minu,sec = tonumber(time:sub(1,2),16),
	tonumber(time:sub(3,4),16),tonumber(time:sub(5,6),16)
	return hour * 60 * 60 + minu * 60 + sec
end

--[[
1.函数功能:添加洗衣液
2.函数参数:t_time代表添加多久
3.返回值:true代表成功，false代表失败
]]
function add_fluid(t_time)
	if not t_time or t_time > 120 then 
		print("invalid add_fluid argument",t_time)
		return false 
	end
	return calc_time(t_time)
end

--[[
1.函数功能:接收服务器一段格式指令,串口2发送
2.函数参数:str为接收的字符串
3.返回值:成功:true，失败:false
2018.3.9修改
更改格式，兼容uart格式。
<time:1000,hex1:AA0102010A0400BC,hex2:AA0202010A0A00C3,wtime:0>
]]
gpio_delay_time = 0
function recv_server_gpio(value)
	local result = false
	local time,hex1,wtime = string.match(value,"<time:(%d+),hex1:(%w+),hex2:%w+,wtime:(%d+)")
	if time then
		gpio_delay_time,wtime = tonumber(time),tonumber(wtime)
		result = uart_write_str(2,hex1)
		if result and wtime ~= 0 then
			sys.timer_start(add_fluid,5000,wtime)
		end
	else
		result = uart_write_str(2,value)
	end
	return result
end


--[[
1.函数功能:接收服务器一段格式指令,串口1发送
2.函数参数:value为接收的字符串
3.返回值:成功 true 失败 false
]]
uart_wtime = 0
function recv_server_hex(value)
	local result = false
	local time,hex1,hex2,wtime = string.match(value,"<time:(%d+),hex1:(%w+),hex2:(%w+),wtime:(%d+)")
	if time then
		result = true
		time,uart_wtime = tonumber(time),tonumber(wtime)
		if time <= 0 then time = 800 end
		
		if uart_write_str(1,hex1) then
			sys.timer_start(uart_write_str,time,1,hex2)
		end
		
		if string.sub(body.style,1,4) == "uart" then
			local sent_counter,sent_timer_id = 0,0
			sent_timer_id = sys.timer_loop_start(function()
				print("counter,id",sent_counter,sent_timer_id)
				if not myuart.uart_working or sent_counter >= 10 then
					sys.timer_stop(sent_timer_id)
					sent_counter = 0
				else
					if uart_write_str(1,hex1) then
						sys.timer_start(uart_write_str,time,1,hex2)
					end
				end
				sent_counter = sent_counter + 1
			end,time + 200)
		end
	else
		result = uart_write_str(1,value)
	end
	return result
end

--[[
1.函数功能:判断文件是否存在
2.返回值:存在true,反之false

function file_exist(path)
	local file = open(path,"r")
	if file then file:close() end
	return file ~= nil
end

1.函数功能:删除一个文件
2.返回值:成功true,失败nil

function delete_file(path)
	return os.remove(path)
end
]]

--[[
1.函数功能:设置配置文件参数
2.函数参数:value为配置参数
3.返回值：
	false,设置文件参数失败
	true,设置文件参数成功
]]
function set_config_file(value)
	if string.sub(value,1,6) == "config" then
		return write_file("/config.txt",string.sub(value,7,#value))
	end
	return false
end

--[[
1.函数功能:获取设备config.txt配置文件value:(串口指令)值
2.函数参数:value为价格值
3.返回值:成功 对应16进制指令 失败 ""
]]
function uart_coin(value)
	local data,hex = body.g_config_data,nil
	local hex = string.match(data,"<"..tostring(value)..":(%w+)")
	if not hex then hex = "" end
	return hex
end

--[[
1.函数功能：获取配置文件中的最大值和对应指令值
2.函数参数:无
3.返回值：
	max:为最大金额
	hex:为最大金额对应的16进制字符串
]]
function get_max_money()
	local temp_n,temp_hex,hex,max = "","","",-1
	local file = io.open("/config.txt","r")
	if file then
		for line in file:lines() do
			temp_n,temp_hex = string.match(line,"<(%d+):(%w+)>")
			if temp_n then
				temp_n = tonumber(temp_n,10)
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

--[[
1.函数功能:获取config.txt配置文件style值
2.函数参数:value为配置文件内容
3.返回值:存在返回所对应的style,不存在""
]]
function get_style(value)
	local data = string.match(value,"<style:(%a+)>") or 
	string.match(value,"<style:(%a+%p+%a+)>")
	if not data then data = "" end
	return data
end

--[[
1.函数功能:获取海尔设备校验码
2.返回值:string
]]
function getcc_haier(value)
	local sum,len = 0,string.len(value)
	for i = 1,len,2 do
		if i == len - 1 then
			sum = sum + 2
			break
		end
		sum = sum + tonumber(string.sub(value,i,i+1),16)
	end
	sum = string.sub(string.format("%X",tostring(sum)),2,3)
	return sum
end
