--����ģ��,����������
require"aliyuniotssl"
require"https"
module(...,package.seeall)

--gVersion���̼��汾���ַ���������û�û�е��ñ��ļ���setVer�ӿ����ã���Ĭ��Ϊ_G.PROJECT.."_".._G.VERSION.."_"..sys.getcorever()
--gPath��������iot��վ�����õ��¹̼��ļ����غ���ģ���еı���·��������û�û�е��ñ��ļ���setName�ӿ����ã���Ĭ��Ϊ/luazip/update.bin
--gCb���¹̼����سɹ���Ҫִ�еĻص�����
local gVersion,gPath,gCb = _G.PROJECT.."_".._G.VERSION.."_"..sys.getcorever(),"/luazip/update.bin"

--productKey����Ʒ��ʶ
--deviceName���豸����
local productKey,deviceName

--verRpted���汾���Ƿ��Ѿ��ϱ�
local verRpted

--httpClient�������¹̼���http client
--httpUrl��get�����е�url�ֶ�
local httpClient,httpHost,httpUrl
--�����ƺ�̨�µ��¹̼�MD5ֵ
local gFileMD5,gFileSize,gFilePath

--lastStep�����һ���ϱ��������¹̼��Ľ���
local lastStep


--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������aliyuniototaǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("aliyuniotota",...)
end

--[[
��������verRptCb
����  ���ϱ��̼��汾�Ÿ��ƶ˺��յ�PUBACKʱ�Ļص�����
����  ��
		tag���˴�������
		result��true��ʾ�ϱ��ɹ���false����nil��ʾʧ��
����ֵ����
]]
local function verRptCb(tag,result)
	print("verRptCb",result)
	verRpted = result
	if not result then sys.timer_start(verRpt,20000) end
end

--[[
��������verRpt
����  ���ϱ��̼��汾�Ÿ��ƶ�
����  ����
����ֵ����
]]
function verRpt()
	print("verRpt",gVersion)
	aliyuniotssl.publish("/ota/device/inform/"..productKey.."/"..deviceName,"{\"id\":1,\"params\":{\"version\":\""..gVersion.."\"}}",1,verRptCb)
end

--[[
��������connectedCb
����  ��MQTT CONNECT�ɹ��ص�����
����  ��
		key��ProductKey
		name���豸����
����ֵ����
]]
function connectedCb(key,name)
	print("connectedCb",verRpted)
	productKey,deviceName = key,name
	--��������
	aliyuniotssl.subscribe({{topic="/ota/device/upgrade/"..key.."/"..name,qos=0}, {topic="/ota/device/upgrade/"..key.."/"..name,qos=1}})
	if not verRpted then		
		--�ϱ��̼��汾�Ÿ��ƶ�
		verRpt()
	end
end

--[[
��������upgradeStepRpt
����  ���¹̼��ļ����ؽ����ϱ�
����  ��
		step��1��100�������ؽ��ȱȣ�-2��������ʧ��
		desc��������Ϣ����Ϊ�ջ���nil
����ֵ����
]]
local function upgradeStepRpt(step,desc)
	print("upgradeStepRpt",step,desc)
	if step<=0 or step==100 then sys.timer_stop(getPercent) end
	lastStep = step
	aliyuniotssl.publish("/ota/device/progress/"..productKey.."/"..deviceName,"{\"id\":1,\"params\":{\"step\":\""..step.."\",\"desc\":\""..(desc or "").."\"}}")
end

--[[
��������downloadCb
����  ���¹̼��ļ����ؽ�����Ĵ�����
����  ��
		result�����ؽ����trueΪ�ɹ���falseΪʧ��
		filePath���¹̼��ļ����������·����ֻ��resultΪtrueʱ���˲�����������
����ֵ����
]]
local function downloadCb(result,filePath)
	print("downloadCb",gCb,result,filePath,gFileSize,io.filesize(filePath))
	sys.setrestart(true,4)
	sys.timer_stop(sys.setrestart,true,4)
	--���ʹ�õ�lod�汾���ڵ���V0020����У��MD5
	if result and tonumber(string.match(sys.getcorever(),"Luat_V(%d+)_"))>=20 then
		local calMD5 = crypto.md5(filePath,"file")
		result = (string.upper(calMD5) == string.upper(gFileMD5))
		print("downloadCb cmp md5",result,calMD5,gFileMD5)		
	end
	if gCb then
		gCb(result,filePath)
	else
		if result then sys.restart("ALIYUN_OTA") end
	end
end

local function httpInitConnectCb()
	httpConnectedCb(true)
end

local function httpConnect(init)
	httpClient=https.create(httpHost,443)
	httpClient:connect((init and httpInitConnectCb or httpConnectedCb),httpErrCb)
end

--[[
��������httpRcvCb
����  �����ջص������������ļ���
����  ��result�����ݽ��ս��(�˲���Ϊ0ʱ������ļ���������������)
				0:�ɹ�
				1:ʧ�ܣ���û�н������������������Ͽ���
				2:��ʾʵ�峬��ʵ��ʵ�壬���󣬲����ʵ������
				3:���ճ�ʱ
		statuscode��httpӦ���״̬�룬string���ͻ���nil
		head��httpӦ���ͷ�����ݣ�table���ͻ���nil
		filename: �����ļ�������·����
����ֵ����
]]
local function httpRcvCb(result,statuscode,head,filename)
	print("httpRcvCb",result,statuscode,head,filename)
	gFilePath = filename
	if result==0 then
		upgradeStepRpt(100,result)
		sys.timer_start(downloadCb,3000,true,filename)
		httpClient:destroy()
	else
		httpClient:destroy(httpConnect)
	end
end

--[[
��������getPercent
����  ����ȡ�ļ����ذٷֱ�
����  ��
����ֵ��
]]
function getPercent()
	local step = httpClient:getrcvpercent()
	if step~=0 and step~=lastStep then
		upgradeStepRpt(step)
	end
	sys.timer_start(getPercent,5000)
end

--[[
��������httpConnectedCb
����  ��SOCKET connected �ɹ��ص�����
����  ��
		init���Ƿ�Ϊ���������¹̼������еĵ�һ������
����ֵ��
]]
function httpConnectedCb(init)
	local rangeStr = "Range: bytes="..(init and 0 or io.filesize(gFilePath)).."-"
	gFilePath = httpClient:request("GET",httpUrl,{rangeStr},"",httpRcvCb,gPath)
	if init then os.remove(gFilePath) end
	sys.timer_start(getPercent,5000)
end 

--[[
��������httpErrCb
����  ��SOCKETʧ�ܻص�����
����  ��
		r��string���ͣ�ʧ��ԭ��ֵ
		CONNECT: socketһֱ����ʧ�ܣ����ٳ����Զ�����
		SEND��socket��������ʧ�ܣ����ٳ����Զ�����
����ֵ����
]]
function httpErrCb(r)
	print("httpErrCb",r)
	upgradeStepRpt(-2,r)
	downloadCb(false)
	httpClient:destroy()	
end

--[[
��������upgrade
����  ���յ��ƶ˹̼�����֪ͨ��Ϣʱ�Ļص�����
����  ��
		payload����Ϣ���أ�ԭʼ���룬�յ���payload��ʲô���ݣ�����ʲô���ݣ�û�����κα���ת����
����ֵ����
]]
function upgrade(payload)	
	local res,jsonData = pcall(json.decode,payload)
	print("upgrade",res,payload)	
	if res then
		if jsonData.data and jsonData.data.url then
			print("url",jsonData.data.url)
			local host,url = string.match(jsonData.data.url,"https://(.-)/(.+)")
			print("httpUrl",url)
			if host and url then
				httpHost = host
				httpUrl = "/"..url
				httpConnect(true)
			end
			gFileMD5 = jsonData.data.md5
			gFileSize = jsonData.data.size
		end
	end
end

--[[
��������setVer
����  �����ù̼��汾��
����  ��
		version��string���ͣ��̼��汾��
����ֵ����
]]
function setVer(version)
	local oldVer = gVersion
	gVersion = version
	if verRpted and version~=oldVer then		
		verRpted = false
		verRpt()
	end
end

--[[
��������setName
����  �������¹̼�������ļ���
����  ��
		name��string���ͣ��¹̼��ļ���
����ֵ����
]]
function setName(name)
	gPath = name
end

--[[
��������setCb
����  �������¹̼����غ�Ļص�����
����  ��
		cb��function���ͣ��¹̼����غ�Ļص�����
����ֵ����
]]
function setCb(cb)
	gCb = cb
end

sys.setrestart(false,4)
sys.timer_start(sys.setrestart,300000,true,4)
