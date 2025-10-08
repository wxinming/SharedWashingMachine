--[[
ģ�����ƣ���������
ģ�鹦�ܣ�������ʼ������д�Լ��ָ���������
ģ������޸�ʱ�䣺2017.02.23
]]

module(...,package.seeall)

package.path = "/?.lua;".."/?.luae;"..package.path

--Ĭ�ϲ������ô洢��configname�ļ���
--ʵʱ�������ô洢��paraname�ļ���
--para��ʵʱ������
--config��Ĭ�ϲ�����
local paraname,paranamebak,para,libdftconfig,configname,econfigname = "/para.lua","/para_bak.lua",{}

--[[
��������print
����  ����ӡ�ӿڣ����ļ��е����д�ӡ�������nvmǰ׺
����  ����
����ֵ����
]]
local function print(...)
	_G.print("nvm",...)
end

--[[
��������restore
����  �������ָ��������ã���configname�ļ������ݸ��Ƶ�paraname�ļ���
����  ����
����ֵ����
]]
function restore()
	os.remove(paraname)
	os.remove(paranamebak)
	local fpara,fconfig = io.open(paraname,"wb"),io.open(configname,"rb")
	if not fconfig then fconfig = io.open(econfigname,"rb") end
	fpara:write(fconfig:read("*a"))
	fpara:close()
	fconfig:close()
	upd(true)
end

--[[
��������serialize
����  �����ݲ�ͬ���������ͣ����ղ�ͬ�ĸ�ʽ��д��ʽ��������ݵ��ļ���
����  ��
		pout���ļ����
		o������
����ֵ����
]]
local function serialize(pout,o)
	if type(o) == "number" then
		--number���ͣ�ֱ��дԭʼ����
		pout:write(o)	
	elseif type(o) == "string" then
		--string���ͣ�ԭʼ�������Ҹ�����˫����д��
		pout:write(string.format("%q", o))
	elseif type(o) == "boolean" then
		--boolean���ͣ�ת��Ϊstringд��
		pout:write(tostring(o))
	elseif type(o) == "table" then
		--table���ͣ��ӻ��У������ţ������ţ�˫����д��
		pout:write("{\n")
		for k,v in pairs(o) do
			if type(k) == "number" then
				pout:write(" [" .. k .. "] = ")
			elseif type(k) == "string" then
				pout:write(" [\"" .. k .."\"] = ")
			else
				error("cannot serialize table key " .. type(o))
			end
			serialize(pout,v)
			pout:write(",\n")
		end
		pout:write("}\n")
	else
		error("cannot serialize a " .. type(o))
	end
end

--[[
��������upd
����  ������ʵʱ������
����  ��
		overide���Ƿ���Ĭ�ϲ���ǿ�Ƹ���ʵʱ����
����ֵ����
]]
function upd(overide)
	for k,v in pairs(libdftconfig) do
		if k ~= "_M" and k ~= "_NAME" and k ~= "_PACKAGE" then
			if overide or para[k] == nil then
				para[k] = v
			end			
		end
	end
end

--[[
��������load
����  ����ʼ������
����  ����
����ֵ����
]]
local function load()
	local f,fBak,fExist,fBakExist
	f = io.open(paraname,"rb")
	fBak = io.open(paranamebak,"rb")
	
	if f then
		fExist = f:read("*a")~=""
		f:close()
	end
	if fBak then
		fBakExist = fBak:read("*a")~=""
		fBak:close()
	end
	
	print("load fExist fBakExist",fExist,fBakExist)
	
	local fResult,fBakResult
	if fExist then
		fResult,para = pcall(require,string.match(paraname,"/(.+)%.lua"))
	end
	
	print("load fResult",fResult)
	
	if fResult then
		os.remove(paranamebak)
		upd()
		return
	end
	
	if fBakExist then
		fBakResult,para = pcall(require,string.match(paranamebak,"/(.+)%.lua"))
	end
	
	print("load fBakResult",fBakResult)
	
	if fBakResult then
		os.remove(paraname)
		upd()
		return
	else
		para = {}
		restore()
	end
end

--[[
��������save
����  ����������ļ�
����  ��
		s���Ƿ��������棬true���棬false����nil������
����ֵ����
]]
local function save(s)
	if not s then return end
	local f = {}
	f.write = function(self, s) table.insert(self, s) end

	f:write("module(...)\n")

	for k,v in pairs(para) do
		if k ~= "_M" and k ~= "_NAME" and k ~= "_PACKAGE" then
			f:write(k .. " = ")
			serialize(f,v)
			f:write("\n")
		end
	end

	local fparabak = io.open(paranamebak, 'wb')
	fparabak:write(table.concat(f))
	fparabak:close()
	
	os.remove(paraname)
	os.rename(paranamebak,paraname)
end

--[[
��������set
����  ������ĳ��������ֵ
����  ��
		k��������
		v����Ҫ���õ���ֵ
		r������ԭ��ֻ�д�������Ч����������v����ֵ�;�ֵ�����˸ı䣬�Ż��׳�PARA_CHANGED_IND��Ϣ
		s���Ƿ���Ҫд�뵽�ļ�ϵͳ�У�false��д�룬����Ķ�д��
����ֵ��true
]]
function set(k,v,r,s)
	local bchg = true
	if type(v) ~= "table" then
		bchg = (para[k] ~= v)
	end
	print("set",bchg,k,v,r,s)
	if bchg then		
		para[k] = v
		save(s or s==nil)
		if r then sys.dispatch("PARA_CHANGED_IND",k,v,r) end
	end
	return true
end

--[[
��������sett
����  ������table���͵Ĳ����е�ĳһ���ֵ
����  ��
		k��table������
		kk��table�����еļ�ֵ
		v����Ҫ���õ���ֵ
		r������ԭ��ֻ�д�������Ч����������v����ֵ�;�ֵ�����˸ı䣬�Ż��׳�TPARA_CHANGED_IND��Ϣ
		s���Ƿ���Ҫд�뵽�ļ�ϵͳ�У�false��д�룬����Ķ�д��
����ֵ��true
]]
function sett(k,kk,v,r,s)
	if para[k][kk] ~= v then
		para[k][kk] = v
		save(s or s==nil)
		if r then sys.dispatch("TPARA_CHANGED_IND",k,kk,v,r) end
	end
	return true
end

--[[
��������flush
����  ���Ѳ������ڴ�д���ļ���
����  ����
����ֵ����
]]
function flush()
	save(true)
end

--[[
��������get
����  ����ȡ����ֵ
����  ��
		k��������
����ֵ������ֵ
]]
function get(k)
	if type(para[k]) == "table" then
		local tmp = {}
		for kk,v in pairs(para[k]) do
			tmp[kk] = v
		end
		return tmp
	else
		return para[k]
	end
end

--[[
��������gett
����  ����ȡtable���͵Ĳ����е�ĳһ���ֵ
����  ��
		k��table������
		kk��table�����еļ�ֵ
����ֵ������ֵ
]]
function gett(k,kk)
	return para[k][kk]
end

--[[
��������init
����  ����ʼ�������洢ģ��
����  ��
		dftcfgfile��Ĭ�������ļ�
����ֵ����
]]
function init(dftcfgfile)
	local f
	f,libdftconfig = pcall(require,string.match(dftcfgfile,"(.+)%.lua"))
	configname,econfigname = "/lua/"..dftcfgfile,"/lua/"..dftcfgfile.."e"
	--��ʼ�������ļ������ļ��аѲ�����ȡ���ڴ���
	load()
end
