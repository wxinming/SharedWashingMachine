module(...,package.seeall)
require"pincfg"
require"pins"
require"myaliyun"
require"mylbs"
require"myuart"
require"algorithm"
require"myhttp"

--配置模块永不休眠
pm.wake("run")

g_config_data,style = "",""

local function myinit()
	myuart.setup_uart(2,myuart.mcu_uart)

	--激活单片机,启动只需发一次,回复AA000000
	if rtos.poweron_reason() == 0 then
		algorithm.uart_write_str(2,"AA000000000000AA")
	end

	--避免重复利用IO，只读一次config.txt文件，将数据保存在g_config_data全局变量中
	g_config_data = algorithm.read_file("/config.txt")
	style = algorithm.get_style(g_config_data)

	local callback
	if string.sub(style,1,4) == "uart" then
		callback = myuart.midea_uartc
	elseif string.sub(style,1,8) == "pul_uart" then
		callback = myuart.midea_pulsator_uartc
		myuart.set_pulsator_uart_param()
	elseif style == "hili_uart" then
		callback = myuart.hili_uart
		myuart.hili_query_timer(15000)
	else
		style = "gpio"--此处为了兼容老版本,不可删除
		pins.reg(pincfg.PIN10,pincfg.PIN11_GPIO,pincfg.PIN12)
	end
	
	if callback then
		myuart.setup_uart(1,callback)
		if string.sub(style,-1,-1) == "c" then
			pins.reg(pincfg.PIN10,pincfg.PIN11_UART)
			pincfg.get_coin_param(style)
		end
		if rtos.poweron_reason() == 0 then
			myuart.send_shutdown(style)
		end
	end
end

myinit()

--此处必须延时,否则会导致模块无法连接服务器
sys.timer_start(myaliyun.initaliyunmqtt,5000)
