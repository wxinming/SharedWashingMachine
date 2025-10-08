--[[
GPIO模块，核心文件
]]
module(...,package.seeall)
require"pins"
require"algorithm"
require"sys"
require"misc"
require"myaliyun"

--myuart.lua中所引用,用于判断是否投币
g_uart_coin_switch = false

--myuart.lua中所引用,串口投币全局变量
g_uart_coin = 0

--定义投币最大金额,投币最大金额对应指令
local g_max_value,g_max_hex,g_startup_command = -1,"",""

--[[
	1.函数名:get_coin_param
	2.函数功能:获取串口投币各类参数，载入到全局变量中
	3.返回值:无
]]
function get_coin_param(style)
	if style == "pul_uartc" then
		g_startup_command = "AA1EDAC40000000000020201FFFFFFFFFF00FFFFFFFFFFFFFFFFFFFFFFFF50"
	elseif style == "uartc" then
		g_startup_command = "AA20DBFB0000000000020201FFFFFFFFFFFFFFFFFFFFFF00FFFF00FFFFFFFFFF17"
	end
	--获取最高价格g_max_value和对应的16进制值g_max_value
	g_max_value,g_max_hex = algorithm.get_max_money()
	--防止忘记设置配置文件，导致吞币现象做下面处理
	if g_max_value == -1 or g_max_hex == "" then
		--拉低12V
		pins.set(false,PIN10)
	else
		g_uart_coin_switch = true
	end
end

--[[
	1.函数名:send_uart_red_button
	2.函数功能:模拟投币红色按钮
	3.函数参数:reversed为sys.timer_stop预留参数,
	唯一标记一个定时器
	4.返回值:无
]]
local function send_uart_red_button(reserved)
	algorithm.uart_write_str(1,algorithm.uart_coin(g_uart_coin))
end

--[[
	函数功能:1.检测投币电流冲击
]]
local check_coin = true
local function set_check_coin()
	check_coin = true
end

--[[
	1.函数名:uart_pin30cb
	2.函数说明:PIN11_UART的回调函数
	3.函数功能:检测GPIO30高低电平
	4.函数参数:v true高,false低
	5.返回值:无
]]
local function uart_pin30cb(v)
	if check_coin ~= true then
		return
	end
	if not v then
		--投币金额累加
		g_uart_coin = g_uart_coin + 1
		--print("g_uart_coin",g_uart_coin)
		--发送美的串口设备开机指令g_startup_command
		
		algorithm.uart_write_str(1,g_startup_command)
		--print("g_uart_coin "..tostring(g_uart_coin).." g_max_value "..tostring(g_max_value))
		--如果投币金额大于最大值,则拉低12V直接启动设备
		if g_uart_coin >= g_max_value then
			pins.set(false,pincfg.PIN10)
			sys.timer_start(algorithm.uart_write_str,800,1,g_max_hex)
			if sys.timer_is_active(send_uart_red_button,0) then
				--print("uart g_max timer is active")
				sys.timer_stop(send_uart_red_button,0)
			end
		else
			if sys.timer_is_active(send_uart_red_button,0) then
				--print("uart timer is active")
				sys.timer_stop(send_uart_red_button,0)
			end
			sys.timer_start(send_uart_red_button,15*1000,0)
		end
	end
end

--定义gpio投币变量gpio_coin
local gpio_coin = 0

--定义全局g_gpio_ischeck标志位,为mcu_uart所使用
g_gpio_ischeck = true

--[[
	同:send_uart_red_button
]]
local function send_gpio_red_button(reversed)
	algorithm.uart_write_str(2,"AA0202010A0A00C3")
end

--[[
	1.函数名:gpio_pin30cb
	2.函数说明:PIN11_GPIO的回调函数
	3.函数功能:检测GPIO30高低电平
	4.函数参数:v true高,false低
	5.返回值:无
]]

local function gpio_pin30cb(v)
	if check_coin ~= true then
		--print("gpio_check_coin :false")
		return
	end
	
	if not v then
		gpio_coin = gpio_coin + 1
		--print("gpio_coin",gpio_coin)
			--为了防止投币导致模拟红色按钮执行,g_gpio_ischeck为false
		g_gpio_ischeck = false
			--发送一个脉冲信号
		algorithm.uart_write_str(2,"AA0102010A0400BC")
		if sys.timer_is_active(send_gpio_red_button,1) then
			sys.timer_stop(send_gpio_red_button,1)
		end
		sys.timer_start(send_gpio_red_button,15*1000,1)
	end
end

--[[
	1.函数名:upload_data
	2.函数功能:上传工作数据
	3.函数参数:
		v:是否可以使用设备,true可以使用,false不可以使用
		money:投币金额,如果为0为扫码支付,非零为投币支付
	4.返回值:无
]]
local function upload_data(v)
	if  v or gpio_coin == 0 then
		myaliyun.send_mqtt_message({id=misc.getimei(),mode="auto",working=tostring(v)})
	else
		myaliyun.send_mqtt_message({id=misc.getimei(),mode="auto",working=tostring(v),money=gpio_coin})
		gpio_coin = 0
	end
end

function set_coin_security()
	--print("touch off coin security")
	check_coin = false
	sys.timer_start(set_check_coin,500)
end
--[[
	1.函数名:pin29cb
	2.函数说明:PIN12的回调函数
	3.函数功能:检测12V高低电平
	4.函数参数:v true高,false低
	5.返回值:无
]]
gpio_working = true
local function pin29cb(v)
	--print("pin29cb",v)
	pins.set(v,PIN10)
	set_coin_security()

	gpio_working = v
	upload_data(v)
end

--配置GPIO31为输出.默认高电平
PIN10={pin=pio.P0_31,dir=pio.OUTPUT1,valid=1}
--配置GPIO29,30为中断输入处理,使用pins.set(true,PINX)为高电平,pins.set(false,PINX)为低电平
PIN11_UART={pin=pio.P0_30,dir=pio.INT,valid=1,intcb=uart_pin30cb}
PIN11_GPIO={pin=pio.P0_30,dir=pio.INT,valid=1,intcb=gpio_pin30cb}
PIN12={pin=pio.P0_29,dir=pio.INT,valid=0,intcb=pin29cb}
