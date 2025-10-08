code    为代码编写目录
core    为模块底层内核目录
lib     为库目录
system	为生成的固件目录

目录结构图:
/
├─code
├─core
│  ├─air202_v0032
│  └─air720_v0012
│      └─Luat_V0012_ASR1802
├─lib
│  ├─air202_v2.3.0
│  │  ├─demo
│  │  │  ├─adc
│  │  │  ├─Air168
│  │  │  ├─Air268F
│  │  │  ├─alarm
│  │  │  ├─aLiYun
│  │  │  ├─apn
│  │  │  ├─asyncSocket
│  │  │  ├─asyncSocketCallback
│  │  │  ├─AT24Cx
│  │  │  ├─audio
│  │  │  ├─call
│  │  │  ├─console
│  │  │  ├─crypto
│  │  │  ├─default
│  │  │  ├─formatString
│  │  │  ├─fs
│  │  │  ├─gizwits
│  │  │  ├─gpio
│  │  │  │  ├─gpioSingle
│  │  │  │  ├─i2cGpioSwitch
│  │  │  │  └─uartGpioSwitch
│  │  │  ├─gps
│  │  │  ├─gpsv2
│  │  │  ├─http
│  │  │  ├─i2c
│  │  │  ├─json
│  │  │  ├─lbsLoc
│  │  │  ├─mqtt
│  │  │  ├─ntp
│  │  │  ├─nvm
│  │  │  ├─pb
│  │  │  ├─pm
│  │  │  ├─protoBuffer
│  │  │  │  ├─complex
│  │  │  │  └─simple
│  │  │  ├─pwm
│  │  │  ├─qrcode
│  │  │  ├─record
│  │  │  ├─sms
│  │  │  ├─socket
│  │  │  │  ├─longConnection
│  │  │  │  ├─longConnectionTransparent
│  │  │  │  ├─shortConnection
│  │  │  │  └─shortConnectionFlymode
│  │  │  ├─socketSsl
│  │  │  │  ├─longConnection
│  │  │  │  ├─shortConnection
│  │  │  │  └─shortConnectionFlymode
│  │  │  ├─spi
│  │  │  ├─SPIFlash
│  │  │  ├─testMqtt
│  │  │  ├─testSocket
│  │  │  ├─uart
│  │  │  ├─uartv2
│  │  │  ├─uartv3
│  │  │  ├─ui
│  │  │  └─update
│  │  │      ├─LuatIotServer
│  │  │      ├─LuatIotServerDaemon
│  │  │      └─userServer
│  │  ├─doc
│  │  │  ├─demo
│  │  │  │  └─modules
│  │  │  └─lib
│  │  │      └─modules
│  │  ├─lib
│  │  └─product
│  │      └─LuatBoard_Air202
│  │          ├─demo
│  │          ├─demo-gc9106
│  │          ├─demo-i2c
│  │          ├─demo-st7735
│  │          ├─demo-st7735l
│  │          └─mqtt-msg-demo
│  └─air720_v2.1.2
│      ├─demo
│      │  ├─adc
│      │  ├─aLiYun
│      │  ├─console
│      │  ├─crypto
│      │  ├─formatString
│      │  ├─fs
│      │  ├─gpio
│      │  │  ├─gpioSingle
│      │  │  └─uartGpioSwitch
│      │  ├─http
│      │  ├─i2c
│      │  ├─json
│      │  ├─lbsLoc
│      │  ├─mqtt
│      │  │  └─sync
│      │  │      ├─sendInterruptRecv
│      │  │      └─sendWaitRecv
│      │  ├─ntp
│      │  ├─nvm
│      │  ├─pb
│      │  ├─pm
│      │  ├─protoBuffer
│      │  │  ├─complex
│      │  │  └─simple
│      │  ├─sms
│      │  ├─socket
│      │  │  ├─async
│      │  │  │  ├─asyncSocket
│      │  │  │  └─asyncSocketCallback
│      │  │  └─sync
│      │  │      ├─sendInterruptRecv
│      │  │      └─sendWaitRecv
│      │  │          ├─longConnection
│      │  │          ├─longConnectionTransparent
│      │  │          ├─shortConnection
│      │  │          └─shortConnectionFlymode
│      │  ├─socketSsl
│      │  │  ├─longConnection
│      │  │  ├─shortConnection
│      │  │  └─shortConnectionFlymode
│      │  ├─uart
│      │  │  ├─v1
│      │  │  └─v3
│      │  └─update
│      │      ├─LuatIotServer
│      │      ├─LuatIotServerDaemon
│      │      └─userServer
│      ├─doc
│      │  ├─demo
│      │  │  └─modules
│      │  └─lib
│      │      └─modules
│      └─lib
└─system
    ├─远程升级用.bin文件
    └─量产升级用.lod文件
