--[[
串口数据处理文件，myuart
]]
module(...,package.seeall)
require"common"
require"pincfg"
require"misc"
require"algorithm"
require"sys"
require"myaliyun"
require"body"

--判断美的设备启动成功、工作完成参数
local b_code,b_start,b_end = "0102",23,26
local s_code,s_start,s_end = "040000",21,26

--串口设备故障次数统计
local err_count = 0

--串口1,2接收数据拼接变量
local mytmp,mytemp = "",""

--串口设备是否正在工作，默认true,是否故障,默认false
uart_working,uart_breakdown,old_mcu = true,false,false

local function print(...)
	_G.print("myuart",...)
end

--[[
	1.函数名:set_pulsator_uart_param
	2.函数功能:设置判断美的波轮设备启动成功,工作完成参数
	3:返回值:无
]]
function set_pulsator_uart_param()
	b_code,b_start,b_end = "040101",21,26
end

function setup_uart(port,callback)
	uart.setup(port,9600,8,uart.PAR_NONE,uart.STOP_1)
	sys.reguart(port,callback)
end

--发送串口设备关机指令
function send_shutdown(style)
	if not style then return end
	local sdorder = ""
	if string.sub(style,1,4) == "uart" then
		sdorder = "AA20DBFB0000000000020200FFFFFFFFFFFFFFFFFFFFFF00FFFF00FFFFFFFFFF18"
	elseif style == "hili_uart" then
		sdorder = "FFFF0A000000000000014D035B"
	elseif string.sub(style,1,8) == "pul_uart" then
		sdorder = "AA1EDAC40000000000020200FFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFF51"
	end
	if algorithm.uart_write_str(1,sdorder) then
		sys.timer_start(algorithm.uart_write_str,1000,1,sdorder)
	end
end

--[[
	1.函数名:sendtostart
	2.函数功能:设备启动成功,发送数据到服务器
	3.函数参数:money投币金额
	4.函数返回值:无
]]
local function sendtostart(money)
	if money == 0 then
		myaliyun.send_mqtt_message({id=misc.getimei(),mode="auto",working="false"})
	else
		myaliyun.send_mqtt_message({id=misc.getimei(),mode="auto",working="false",money=money})
	end
end

--[[
	1.函数名:sendtocomplete
	2.函数功能:设备工作完成,发送数据到服务器
	3.返回值:无
]]
local function sendtocomplete()
	myaliyun.send_mqtt_message({id=misc.getimei(),mode="auto",working="true"})
end

--[[
	1.函数名:devicefault
	2.函数功能:设备故障,发送数据到服务器
	3.返回值:无
]]
local function devicefault(myerr)
	myaliyun.send_mqtt_message({id=misc.getimei(),errorcode=myerr})
end

--[[
	1.函数名:sendtocontinue
	2.函数功能:设备故障,再次工作发送数据到服务器
	3.返回值:无
]]
local function sendtocontinue()
	myaliyun.send_mqtt_message({id=misc.getimei(),mode="auto",working="continue"})
end

--[[
	1.函数名:stop_running_timer
	2.函数功能:停止正在运行的定时器
	3.返回值:无
]]
local function stop_running_timer(fnc,reserved)
	if sys.timer_is_active(fnc,reserved) then
		print("$stop running timer success")
		sys.timer_stop(fnc,reserved)
	end
end

--[[
	1.函数名:midea_uartc
	2.函数功能:处理串口所接收到的美的滚筒设备数据
	3.返回值:无
]]
function midea_uartc()
	local data = ""
	while true do
		data = uart.read(1,"*l",0)
		if not data or string.len(data) ==  0 then
			break
		end
		mytmp = mytmp..common.binstohexs(data)
		
		if string.sub(mytmp,1,2) ~= "AA" then
			mytmp = ""
		else
			if string.sub(mytmp,1,6) == "AA29DB" or string.sub(mytmp,1,6) == "AA11DB" then
				if string.len(mytmp) == 84 and string.sub(mytmp,-2,-1) == algorithm.getcc_md(mytmp) then
					if string.sub(mytmp,b_start,b_end) == b_code then
						if uart_working then
							if uart_breakdown then
								stop_running_timer(send_shutdown,body.style)
								sendtocontinue()
							else
								sendtostart(pincfg.g_uart_coin)
								if pincfg.g_uart_coin_switch then
									pincfg.set_coin_security()
									pincfg.g_uart_coin = 0
									pins.set(false,pincfg.PIN10)
								end
							end
							uart_working = false
							uart_breakdown = false
							err_count = 0
						end
					elseif string.sub(mytmp,s_start,s_end) == s_code then
						if not uart_working or uart_breakdown then
							if uart_breakdown then
								stop_running_timer(send_shutdown,body.style)
							end
							if pincfg.g_uart_coin_switch then
								pincfg.set_coin_security()
								pins.set(true,pincfg.PIN10)
							end
							uart_working = true
							uart_breakdown = false
							sendtocomplete()
							algorithm.uart_wtime = 0
							err_count = 0
						end
					end

					if algorithm.uart_wtime ~= 0 then
						if string.sub(mytmp,25,26) == "02" and string.sub(mytmp,53,54) == "04" then
							algorithm.add_fluid(algorithm.uart_wtime)
							algorithm.uart_wtime = 0
						end
					end
					mytmp = ""
					break
				elseif string.len(mytmp) == 36 and string.sub(mytmp,-2,-1) == algorithm.getcc_md(mytmp) then
					err_count = err_count + 1
					if err_count == 2 then
						uart_breakdown,uart_working = true,true
						devicefault(mytmp)
						sys.timer_start(send_shutdown,60000 * 120,body.style)
					elseif err_count == 1 then
						sys.timer_start(algorithm.uart_write_str,5000,1,"AA20DBFB00000000000202FF01FFFFFFFFFFFFFFFFFFFF00FFFF00FFFFFFFFFF17")
					end
					mytmp = ""
					break
				end
			else
				mytmp = ""
			end
		end
		
		if string.len(mytmp) > 84 then
			print("$midea_uartc data over flow")
			mytmp = ""
		end
	end
end

--[[
	1.函数名:midea_pulsator_uartc
	2.函数功能:处理串口所接收到的美的波轮设备数据
	3.返回值:无
]]
function midea_pulsator_uartc()
	local data = ""
	while true do
		data = uart.read(1,"*l",0)
		if not data or string.len(data) ==  0 then
			break
		end
		mytmp = mytmp..common.binstohexs(data)
		if string.sub(mytmp,1,2) ~= "AA" then
			mytmp = ""
		else
			if string.sub(mytmp,1,4) == "AA23" or string.sub(mytmp,1,4) == "AA11" then
				if string.len(mytmp) == 72 and string.sub(mytmp,-2,-1) == algorithm.getcc_md(mytmp) then
					if string.sub(mytmp,b_start,b_end) == b_code then
						if uart_working then
							uart_working = false
							uart_breakdown = false
							sendtostart(pincfg.g_uart_coin)								
							if pincfg.g_uart_coin_switch then
								pincfg.set_coin_security()
								pincfg.g_uart_coin = 0
								pins.set(false,pincfg.PIN10)
							end
							err_count = 0
						end
					elseif string.sub(mytmp,s_start,s_end) == s_code then
						if not uart_working then								
							if pincfg.g_uart_coin_switch then
								pincfg.set_coin_security()
								pins.set(true,pincfg.PIN10)
							end								
							uart_working = true
							uart_breakdown = false
							sendtocomplete()																
							algorithm.uart_wtime = 0
							err_count = 0
						end
					end

					if algorithm.uart_wtime ~= 0 then							
						if string.sub(mytmp,25,26) == "02" and string.sub(mytmp,53,54) == "04" then																	
							algorithm.add_fluid(algorithm.uart_wtime)
							algorithm.uart_wtime = 0
						end
					end
					mytmp = ""
					break
				elseif string.len(mytmp) == 36 and string.sub(mytmp,-2,-1) == algorithm.getcc_md(mytmp) then
					err_count = err_count + 1
					if err_count == 1 then
						devicefault(mytmp)
						uart_breakdown = true
					end
					mytmp = ""
					break
				end
			else
				mytmp = ""
			end
		end
		
		if string.len(mytmp) > 72 then
			print("$midea_pulsator_uartc data over flow")
			mytmp = ""
		end
	end
end 

--[[
	1.函数名:hili_send_data
	2.函数功能:发送海狸波轮设备数据
	3.函数参数:reserved保留参数
	4.返回值无
]]
local function hili_send_data(reserved)
	algorithm.uart_write_str(1,"FFFF0A000000000000014D0159")
end

--[[
	1.函数名:hili_query_timer
	2.函数功能:定时查询海狸数据
	3.函数参数:time间隔ms
	4.返回值:无
]]
function hili_query_timer(time)
	if sys.timer_is_active(hili_send_data,"hili_send_data") then
		--print("timer is running")
		sys.timer_stop(hili_send_data,"hili_send_data")
		sys.timer_loop_start(hili_send_data,time,"hili_send_data")
	else
		--print("timer is not running")
		sys.timer_loop_start(hili_send_data,time,"hili_send_data")
	end
end

--[[
	1.函数名:hili_uart
	2.函数功能:处理串口所接收到的海狸波轮设备数据
	3.返回值:无
]]
function hili_uart()
	local data = ""
	while true do
		data = uart.read(1,"*l",0)
		if not data or string.len(data) == 0 then break end
		mytmp = mytmp..common.binstohexs(data)
		
		if string.sub(mytmp,1,6) ~= "FFFF2C" then
			mytmp = ""
		else
			if string.len(mytmp) == 94 and string.sub(mytmp,-2,-1) == algorithm.getcc_haier(mytmp) then
				if string.sub(mytmp,25,26) == "0D" or string.sub(mytmp,35,36) == "F1" then
					if uart_working then
						sendtostart(0)
						uart_working = false
						uart_breakdown = false
						hili_query_timer(2000)
						err_count = 0
					end
				elseif string.sub(mytmp,33,36) == "0021" or string.sub(mytmp,33,34) == "0E" then
					if not uart_working then
						sendtocomplete()
						uart_working = true
						uart_breakdown = false
						hili_query_timer(15000)
						err_count = 0
					end
				elseif string.sub(mytmp,35,36) == "51" or string.sub(mytmp,35,36) == "71" or string.sub(mytmp,35,36) == "41" then
					err_count = err_count + 1
					if err_count == 1 then
						devicefault(mytmp)
						uart_breakdown = true
					end
				end

				if algorithm.uart_wtime ~= 0 then
					if string.sub(mytmp,33,36) == "03F1" then
						algorithm.add_fluid(algorithm.uart_wtime)
						algorithm.uart_wtime = 0
					end
				end
				mytmp = ""
				break
			end
			
			if string.len(mytmp) > 94 then
				print("$hili_uart data over flow")
				mytmp = ""
			end
		end
	end
end

--[[
	1.函数名:mcu_uart
	2.函数功能:处理单片机所回传的数据
	3.返回值:无
]]
function mcu_uart()
	local data = ""
	while true do
		data = uart.read(2,"*l",0)
		if not data or string.len(data) == 0 then 
			break
		end
		mytemp = mytemp..common.binstohexs(data)
		--print("$uart2",mytemp)
		--脉冲1返回值:BB0102010A0A00D3,脉冲2返回值:BB0202010A0A00D4
		--           BB0102010A0A00D3             BB0202010A0A00D4
		if string.sub(mytemp,1,4) == "BB01" or string.sub(mytemp,1,4) == "BB02" then
			if (string.len(mytemp) == 16) and (algorithm.getcc_dog(mytemp) == "D3") then
				--为了防止投币导致模拟红色按钮执行,做下面处理
				if pincfg.g_gpio_ischeck then
					if algorithm.gpio_delay_time > 0 then
						sys.timer_start(algorithm.uart_write_str,algorithm.gpio_delay_time,2,"AA0202010A0A00C3")
					else
						algorithm.uart_write_str(2,"AA0202010A0A00C3")
					end
				end
				mytemp = ""
				break
			elseif (string.len(mytemp) == 16) and (algorithm.getcc_dog(mytemp) == "D4") then
				--模拟红色按钮成功,设置pincfg.g_gpio_ischeck true
				pincfg.g_gpio_ischeck = true
				algorithm.gpio_delay_time = 0
				mytemp = ""
				break
			end
		--单片机定时器倒计时单位:秒
		elseif string.sub(mytemp,1,4) == "BB03" then
			if (string.len(mytemp) == 16) and (string.sub(mytemp,15,16) == algorithm.getcc_dog(mytemp)) then
				--print("BB03*************",mytemp)
				--BB030100000000BF代表烘干机工作结束,
				--**********此代码为打印倒计时,运算量较大,发布切记一定要注释**********
				--print(algorithm.get_count_down(algorithm.hextosec(mytemp)))
				--此处为兼容老单片机，不要注释
				if mytemp == "BB030100000000BF" then
					old_mcu = true
					print("$singlechip work complete")
					sendtocomplete()
					pincfg.gpio_working = true
				end
				mytemp = ""
				break
			end
		--单片机定时器启动,并做逻辑处理
		elseif string.sub(mytemp,1,4) == "AA03" then
			if (string.len(mytemp) == 16) and (string.sub(mytemp,15,16) == algorithm.getcc_dog(mytemp)) then
				--print("AA03*************",mytemp)
				local temp = string.sub(mytemp,13,14)
				--如果指令13,14位为00烘干机,01洗衣液,02单片机关机有数据回传,03单片机关机无数据回传
				if temp == "00" then
					print("$singlechip start work")
					sendtostart(0)
					old_mcu = false
					pincfg.gpio_working = false
				elseif temp == "01" then
					print("$start add laundry detergent")              
				elseif temp == "02" then
					print("$shutdown singlechip success")
					sendtocomplete()
					pincfg.gpio_working = true
				end
				mytemp = ""
				break
			end
		--单片机定时器清零所发指令
		elseif string.sub(mytemp,1,4) == "BA03" then
			if (string.len(mytemp) == 16) and (string.sub(mytemp,15,16) == algorithm.getcc_dog(mytemp)) then
				--print("$singlechip timer clear zero")
				local temp = string.sub(mytemp,13,14)
				if temp == "00" and not old_mcu then
					print("$singlechip work complete")
					sendtocomplete()
					pincfg.gpio_working = true
				elseif temp == "01" then
					print("$add laundry detergent complete")
				end
				mytemp = ""
				break
			end
		else
			--print("$rubbish data",mytemp)
			--忽略 AA0100000000AB,AA0200000000AC
			--发送一次脉冲返回一次AA0100000000AB
			--发送模拟红色按钮返回AA0200000000AC
			mytemp = ""
		end
		
		if string.len(mytemp) > 16 then
			print("$mcu_uart data over flow")
			mytemp = ""
		end
	end
end
