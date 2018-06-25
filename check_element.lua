Database = { }
Finder = { }
Communication = { }
Calibration = { }
LogFile = { }
Main = { }

function Ask_Information()
	local data = { server = "localhost", user = "root", password = "", database = "master2pc", communication = "true", calibration = "true" }
	io.write("MySQL Server ("..data.server.."): ")
	io.flush()
	local temp = io.read()
	if temp ~= "" then data.server = temp end
	io.write("MySQL User ("..data.user.."): ")
	io.flush()
	local temp = io.read()
	if temp ~= "" then  data.user = temp end
	io.write("MySQL Password ("..data.password.."): ")
	io.flush()
	local temp = io.read()
	if temp ~= "" then  data.password = temp end
	io.write("MySQL Database ("..data.database.."): ")
	io.flush()
	local temp = io.read()
	if temp ~= "" then  data.database = temp end
	io.write("Check Calibration ("..data.calibration.."): ")
	io.flush()
	local temp = io.read()
	if temp ~= "" then  data.calibration = temp end
	io.write("Check communication ("..data.communication.."): ")
	io.flush()
	local temp = io.read()
	if temp ~= "" then  data.communication = temp end
	return data
end

local inputData = Ask_Information()
local openSlave = { } 
local openAFA = { }

function Main:Init()
	LogFile:Init() 
	local elements = Finder:Load()
	if inputData.communication == "true" then Communication:Init(elements) end
	if inputData.calibration == "true" then Calibration:Init(elements) end
	LogFile:Close()
	self:CheckForError()
end

function Main:CheckForError()
	os.execute("clear")
	for _, con in pairs(openSlave) do
		print("Concentrator "..con.." is OPEN - Program failed while closing")
	end
	for _, afa in pairs(openAFA) do
		print("AFALINK "..afa.." is OPEN - Program failed while closing")
	end
end

function Main:tableLength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function Main:spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function Main:OpenConcentrator(line, concentrator)
	for i = 1, 5 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_115200_ -+ "..concentrator..":1")
		local result = handle:read("*a")
		if not string.find(result, "OK") then
			handle:close()
			return true 
		end
		handle:close()
	end
	return false
end

function Main:CloseConcentrator(line, concentrator)
	for i = 1, 10 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -+ "..concentrator..":0")
		local result = handle:read("*a")
		if not string.find(result, "OK") then 
			handle:close()
			return true 
		end
		handle:close()
	end
	return false
end

function Main:OpenAfalink(line, afa)
	for i = 1, 5 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -$ o:"..afa)
		local result = handle:read("*a")
		if not string.find(result, "No anwser") or not string.find(result, "error")  then
			handle:close()
			return true 
		end
		handle:close()
	end
	return false
end

function Main:CloseAfalink(line, afa)
	for i = 1, 5 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -$ c:"..afa)
		local result = handle:read("*a")
		if not string.find(result, "No anwser") or not string.find(result, "error")  then
			handle:close()
			return true 
		end
		handle:close()
	end
	return false
end

function Main:Split(s)
    result = {};
    for i in string.gmatch(s, "%S+") do
        table.insert(result, i);
    end
    return result;
end

function Main:CommunicationPrint(line, concentrator, element, elementNumber)
	os.execute("clear")
	print("-- TEST COMMUNICATION PROGRESS --")
	print("Line: "..line)
	print("Concentrator: "..concentrator)
	if element then print(element..": "..elementNumber) end
end

function Main:CalibrationPrint(line, concentrator, elementNumber, maxNumber)
	os.execute("clear")
	print("-- GET CALIBRATION PROGRESS --")
	print("Line: "..line)
	print("Concentrator: "..concentrator)
	print("Sensor: "..elementNumber)
end

----------------------------------------------------------------------------------

function LogFile:Init()
	local date = os.date("%Y%m%d_").."log"
	os.execute("sudo rm -r "..date)
	os.execute("sudo mkdir "..date)
	self.element = io.open(date.."/elements_detected.txt", "a")
	self.communication = io.open(date.."/communication.txt", "a")
	self.calibration = io.open(date.."/calibration.txt", "a")
end

function LogFile:Close()
	io.close(self.element)
	io.close(self.communication)
end

function LogFile:Write(txt, file)
	if file == 1 then
		self.element:write(txt, "\n")
	elseif file == 2 then
		self.communication:write(txt, "\n")
	elseif file == 3 then
		self.calibration:write(txt, "\n")
	end
end

function LogFile:BackLine(file)
	if file == 1 then
		self.element:write("\n")
	elseif file == 2 then
		self.communication:write("\n")
	elseif file == 3 then
		self.calibration:write("\n")
	end
end

----------------------------------------------------------------------------------

function Calibration:Init(table)
	self.comLine = table
	self:ScanSensor()
end

function Calibration:ScanSensor()
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR " ..concentrator.id.." - SENSOR ]-----", 3)
			local isOpen = Main:OpenConcentrator(line.id, concentrator.id)
			if isOpen then
				openSlave[concentrator.id] = concentrator.id
				local avg = { }
				local sensors = { }
				for uid, sensor in pairs (line.concentrator[concentrator.id].sensor) do
					Main:CalibrationPrint(line.id, concentrator.id , sensor)
					local result = self:Calibration_Sensor(line.id, sensor)
					LogFile:Write("Sensor "..sensor.." : "..result, 3)
					local cm = self:Get_Calibration_From_String(result)
					if cm then
						if not avg[cm] then avg[cm] = { nbr = 0, cm = cm } end
						avg[cm] =  {
							nbr =  avg[cm].nbr + 1,
							cm = cm
						}
						sensors[sensor] = {
							id = sensor,
							cm = cm
						}
					end
				end
				local isClose= Main:CloseConcentrator(line.id, concentrator.id)
				if not isClose then
					LogFile:Write("WARNING: CONCENTRATOR "..concentrator.id.." NOT CLOSED", 3)
				else
					openSlave[concentrator.id] = nil
				end

				self:Write_Average_Calibration(avg, sensors)

			else
				LogFile:Write("Can't open concentrator", 3)
			end
			LogFile:BackLine(3)
		end
	end
	LogFile:BackLine(3)
end

function Calibration:Write_Average_Calibration(a, b)
	local avg = 0
	local nbr = Main:tableLength(a)

	local max = 0
	for _, i in pairs (a) do
		if i.nbr > max then
			max = i.nbr
			avg = i.cm
		end
	end
	avg = avg / Main:tableLength(a)
	LogFile:Write("Calibation average: "..avg, 3)

	local string = ""
	for _, sen in pairs(b) do
		if (sen.cm > (avg + 50 )) or (sen.cm < (avg - 50)) then 
			if string ~= "" then string = string..", " end
			string = string..sen.id 
		end
	end
	if string ~= "" then LogFile:Write("Sensors calibration may be wrong for sensors: "..string, 3) end
end

function Calibration:Calibration_Sensor(line, sensor)
	local calib = "No communication"
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..sensor.." -k")
		local result = handle:read("*a")
		if string.find(result, "cm") and not string.find(result, "ERROR IN CRC") then
			handle:close()
			return result:sub(1, -2)
		end
		handle:close()
	end
	return calib
end

function Calibration:Get_Calibration_From_String(str)
	local a = Main:Split(str)
	for i, b in pairs(a) do
		if b == "cm" then 
			local match = tonumber(a[i-1])
			if match then return match end
		end
	end
end

----------------------------------------------------------------------------------

function Communication:Init(table)
	self.comLine = table
	-------------------------------
	self:ScanConcentrator()
	self:ScanSensor()
	self:ScanVms()
	self:ScanVmsSortie()
	self:ScanAFA()
end

function Communication:ScanConcentrator()
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR ]-----", 2)
		local i = 1
		local concentratorError = { }
		local concentratorWarning = { }
		local concentratorBoot = { }
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			Main:CommunicationPrint(line.id, concentrator.id, nil)
			local result, version = self:Communication_Concentrator(line.id, concentrator.id)
			LogFile:Write("Concentrator "..concentrator.id.." : "..result.."% Packet Lose".." - "..version, 2)
			if result == 100 then
				concentratorError[concentrator.id] = concentrator.id
			elseif result > 0 then
				concentratorWarning[concentrator.id] = concentrator.id
			end
			if string.find(version, "v1.") then
				concentratorBoot[concentrator.id] = concentrator.id
			end
			i = i + 1
		end

		self:WriteConcentratorError(concentratorError)
		self:WriteConcentratorWarning(concentratorWarning)
		self:WriteConcentratorBoot(concentratorBoot)
		LogFile:BackLine(2)
	end
end

function Communication:WriteConcentratorError(table)
	local nbrError = Main:tableLength(table)
	LogFile:Write("Concentrator with no commnication number: "..nbrError, 2)
	local string = ""
	if nbrError > 0 then
		for _ , con in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..con
		end
	end
	if string ~= "" then
		LogFile:Write("Concentrator with no commnication address list: "..string, 2)
	end
end

function Communication:WriteConcentratorWarning(table)
	local nbrWarning = Main:tableLength(table)
	LogFile:Write("Concentrator with bad communication number: "..nbrWarning, 2)
	local string = ""
	if nbrWarning > 0 then
		for _ , con in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..con
		end
	end
	if string ~= "" then
		LogFile:Write("Concentrator with bad commnication address list: "..string, 2)
	end
end

function Communication:WriteConcentratorBoot(table)
	local nbrBoot = Main:tableLength(table)
	LogFile:Write("Concentrator in bootloader number: "..nbrBoot, 2)
	local string = ""
	if nbrBoot > 0 then
		for _ , con in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..con
		end
	end
	if string ~= "" then
		LogFile:Write("Concentrator in bootloader address list: "..string, 2)
	end
end

function Communication:Communication_Concentrator(line, concentrator)
	local packetLose = 0
	local Version = "Version: not available "
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_115200_ -a "..concentrator.." -X")
		local result = handle:read("*a")
		if not string.find(result, "Version") then
			packetLose = packetLose + 1
		elseif Version == "Version: not available " and string.len(result) > 13 then
			Version = result
		end
		handle:close()
	end
	return (packetLose*5), Version:sub(1, -2)
end

function Communication:ScanSensor()
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			if Main:tableLength(line.concentrator[concentrator.id].sensor) ~= 0 then
				LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR " ..concentrator.id.." - SENSOR ]-----", 2)
				local isOpen = Main:OpenConcentrator(line.id, concentrator.id)
				if isOpen then
					openSlave[concentrator.id] = concentrator.id
					local i = 1
					local sensorError = { }
					local sensorWarning = { }
					for uid, sensor in pairs (line.concentrator[concentrator.id].sensor) do
						Main:CommunicationPrint(line.id, concentrator.id, "Sensor" , sensor)
						local result, version = self:Communication_Sensor(line.id, sensor)
						LogFile:Write("Sensor "..sensor.." : "..result.."% Packet Lose".." - "..version, 2)
						i = i + 1
						if result == 100 then
							sensorError[sensor] = sensor
						elseif result > 0 then
							sensorWarning[sensor] = sensor
						end
					end
					local isClose= Main:CloseConcentrator(line.id, concentrator.id)
					if not isClose then 
						openSlave[concentrator.id] = concentrator.id
						LogFile:Write("WARNING: CONCENTRATOR "..concentrator.id.." NOT CLOSED", 2)
					else
						openSlave[concentrator.id] = nil
					end
					self:WriteSensorError(sensorError)
					self:WriteSensorWarning(sensorWarning)
				else
					LogFile:Write("Can't open concentrator", 2)
				end
				LogFile:BackLine(2)
			end
		end
	end
end

function Communication:WriteSensorError(table)
	local nbrError = Main:tableLength(table)
	LogFile:Write("Sensor with no commnication number: "..nbrError, 2)
	local string = ""
	if nbrError > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Sensor with no commnication address list: "..string, 2)
	end
end

function Communication:WriteSensorWarning(table)
	local nbrWarning = Main:tableLength(table)
	LogFile:Write("Sensor with bad communication number: "..nbrWarning, 2)
	local string = ""
	if nbrWarning > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Sensor with bad commnication address list: "..string, 2)
	end
end

function Communication:Communication_Sensor(line, sensor)
	local packetLose = 0
	local Version = "Version: not available "
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..sensor.." -v 2")
		local result = handle:read("*a")
		if not string.find(result, "V") then
			packetLose = packetLose + 1
		elseif Version == "Version: not available " and not string.find(result, "ERROR IN CRC") and not string.find(result, "ERROR") then
			Version = result
		end
		handle:close()
	end
	return (packetLose*5), Version:sub(1, -2)
end

function Communication:ScanVms()
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			if Main:tableLength(line.concentrator[concentrator.id].vms) ~= 0 then
				LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR " ..concentrator.id.." - VMS ]-----", 2)
				local isOpen = Main:OpenConcentrator(line.id, concentrator.id)
				if isOpen then
					openSlave[concentrator.id] = concentrator.id
					local i = 1
					local vmsError = { }
					local vmsWarning = { }
					for uid, vms in pairs (line.concentrator[concentrator.id].vms) do
						Main:CommunicationPrint(line.id, concentrator.id, "VMS" , vms)
						local result, version = self:Communication_Vms(line.id, vms)
						LogFile:Write("VMS "..vms.." : "..result.."% Packet Lose".." - "..version, 2)
						i = i + 1
						if result == 100 then
							vmsError[vms] = vms
						elseif result > 0 then
							vmsWarning[vms] = vms
						end
					end
					local isClose = Main:CloseConcentrator(line.id, concentrator.id)
					if not isClose then 
						openSlave[concentrator.id] = concentrator.id
						LogFile:Write("WARNING: CONCENTRATOR "..concentrator.id.." NOT CLOSED", 2)
					else
						openSlave[concentrator.id] = nil
					end
					self:WriteVmsError(vmsError)
					self:WriteVmsWarning(vmsWarning)
				else
					LogFile:Write("Can't open concentrator", 2)
				end
				LogFile:BackLine(2)
			end
		end
	end
end

function Communication:Communication_Vms(line, vms)
	local packetLose = 0
	local Version = "Version: not available "
	local temp = vms + 1
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..temp.." -v 3")
		local result = handle:read("*a")
		if not string.find(result, "V") then
			packetLose = packetLose + 1
		elseif Version == "Version: not available " and not string.find(result, "ERROR IN CRC") and not string.find(result, "ERROR") then
			Version = result
		end
		handle:close()
	end
	return (packetLose*5), Version:sub(1, -2)
end

function Communication:WriteVmsError(table)
	local nbrError = Main:tableLength(table)
	LogFile:Write("Vms with no commnication number: "..nbrError, 2)
	local string = ""
	if nbrError > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Vms with no commnication address list: "..string, 2)
	end
end

function Communication:WriteVmsWarning(table)
	local nbrWarning = Main:tableLength(table)
	LogFile:Write("Vms with bad communication number: "..nbrWarning, 2)
	local string = ""
	if nbrWarning > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Vms with bad commnication address list: "..string, 2)
	end
end

function Communication:ScanVmsSortie()
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			if Main:tableLength(line.concentrator[concentrator.id].vmssorties) ~= 0 then
				LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR " ..concentrator.id.." - VMS Sortie ]-----", 2)
				local isOpen = Main:OpenConcentrator(line.id, concentrator.id)
				if isOpen then
					openSlave[concentrator.id] = concentrator.id
					local i = 1
					local vmssortieError = { }
					local vmssortieWarning = { }
					for uid, vms in pairs (line.concentrator[concentrator.id].vmssorties) do
						Main:CommunicationPrint(line.id, concentrator.id, "VMS Sortie" , vms)
						local result, version = self:Communication_VmsSortie(line.id, vms)
						LogFile:Write("VMS Sortie "..vms.." : "..result.."% Packet Lose".." - "..version, 2)
						i = i + 1
						if result == 100 then
							vmssortieError[vms] = vms
						elseif result > 0 then
							vmssortieWarning[vms] = vms
						end
					end
					local isClose = Main:CloseConcentrator(line.id, concentrator.id)
					if not isClose then 
						openSlave[concentrator.id] = concentrator.id
						LogFile:Write("WARNING: CONCENTRATOR "..concentrator.id.." NOT CLOSED", 2)
					else
						openSlave[concentrator.id] = nil
					end
					self:WriteVmsSortieError(vmssortieError)
					self:vmssortieWarning(vmssortieWarning)
				else
					LogFile:Write("Can't open concentrator", 2)
				end
				LogFile:BackLine(2)
			end
		end
	end
end

function Communication:Communication_VmsSortie(line, vms)
	local packetLose = 0
	local Version = "Version: not available "
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..vms.." -v 3")
		local result = handle:read("*a")
		if not string.find(result, "V") then
			packetLose = packetLose + 1
		elseif Version == "Version: not available " and not string.find(result, "ERROR IN CRC") and not string.find(result, "ERROR") then
			Version = result
		end
		handle:close()
	end
	return (packetLose*5), Version:sub(1, -2)
end

function Communication:WriteVmsSortieError(table)
	local nbrError = Main:tableLength(table)
	LogFile:Write("Vms sortie with no commnication number: "..nbrError, 2)
	local string = ""
	if nbrError > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Vms sortie with no commnication address list: "..string, 2)
	end
end

function Communication:WriteVmsSortieWarning(table)
	local nbrWarning = Main:tableLength(table)
	LogFile:Write("Vms with bad communication number: "..nbrWarning, 2)
	local string = ""
	if nbrWarning > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Vms with bad commnication address list: "..string, 2)
	end
end

function Communication:ScanAFA()
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			if Main:tableLength(line.concentrator[concentrator.id].fc) ~= 0 then
				LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR " ..concentrator.id.." - FC ]-----", 2)
				local isOpen = Main:OpenConcentrator(line.id, concentrator.id)
				if isOpen then
					openSlave[concentrator.id] = concentrator.id
					local afaError = { }
					local afaWarning = { }
					for uid, fc in pairs (line.concentrator[concentrator.id].fc) do
						Main:CommunicationPrint(line.id, concentrator.id, "AFALINK" , fc)
						local result, version = self:Communication_AFALINK(line.id, fc)
						LogFile:Write("AFALINK "..fc.." : "..result.."% Packet Lose".." - "..version, 2)
						if result == 100 then
							afaError[fc] = fc
						elseif result > 0 then
							afaWarning[fc] = fc
						end
						self:ScanFC(line.id, fc)
					end
					local isClose = Main:CloseConcentrator(line.id, concentrator.id)
					if not isClose then
						openSlave[concentrator.id] = concentrator.id 
						LogFile:Write("WARNING: CONCENTRATOR "..concentrator.id.." NOT CLOSED", 2)
					else
						openSlave[concentrator.id] = nil
					end
					self:WriteAFAError(afaError)
					self:WriteAFAWarning(afaWarning)
				else
					LogFile:Write("Can't open concentrator", 2)
				end
				LogFile:BackLine(2)
			end
		end
	end
	LogFile:BackLine(2)
end

function Communication:Communication_AFALINK(line, afa)
	local packetLose = 0
	local Version = "Version: not available "
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..afa.." -v 4")
		local result = handle:read("*a")
		if not string.find(result, "V") then
			packetLose = packetLose + 1
		elseif Version == "Version: not available " and not string.find(result, "ERROR IN CRC") and not string.find(result, "ERROR") then
			Version = result
		end
		handle:close()
	end
	return (packetLose*5), Version:sub(1, -2)
end

function Communication:WriteAFAError(table)
	local nbrError = Main:tableLength(table)
	LogFile:Write("AFALINK with no commnication number: "..nbrError, 2)
	local string = ""
	if nbrError > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("AFALINK with no commnication address list: "..string, 2)
	end
end

function Communication:WriteAFAWarning(table)
	local nbrWarning = Main:tableLength(table)
	LogFile:Write("Vms with bad communication number: "..nbrWarning, 2)
	local string = ""
	if nbrWarning > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("Vms with bad commnication address list: "..string, 2)
	end
end

function Communication:ScanFC(line, fc)
	local isOpen = Main:OpenAfalink(line, fc)
	if isOpen then
		openAFA[fc] = fc
		local array = self:Find_FC_Sensor(line)
		local fcError = { }
		local fcWarning = { }
		for _, b in pairs(array) do
			local result, version = self:Communication_FC(line, b)
				LogFile:Write("FC Sensor "..b.." : "..result.."% Packet Lose".." - "..version, 2)
			if result == 100 then
			 	fcError[b] = b
			elseif result > 0 then
			 	fcWarning[b] = b
		 	end
		end

		if Main:tableLength(array) < 3 then 
		 	LogFile:Write("WARNING: MISSING SENSOR(S) ON FC", 2)
		 end

		self:WriteFCError(fcError)
		self:WriteFCWarning(fcWarning)

		local isClose = Main:CloseAfalink(line, fc)
		if not isClose then
			openAFA[fc] = fc
			LogFile:Write("WARNING: AFALINK "..fc.." NOT CLOSED", 2)
		else
			openAFA[fc] = nil
		end
	else
		LogFile:Write("Can't open afalink", 2)
	end
	LogFile:BackLine(2)
end

function Communication:Find_FC_Sensor(line)
	local address = { }
	for i = 0, 3 do
		for j = 0, 10 do
			if address[i] == nil then
				local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..i.." -v 2")
				local result = handle:read("*a")
				if not string.find(result, "ERROR") and not (string.find(result, "V") and string.len(result) < 8) then
					address[i] = i
				end
				handle:close()
			end
		end
	end
	return address
end

function Communication:Communication_FC(line, b)
	local packetLose = 0
	local Version = "Version: not available "
	for i = 1, 20 do
		local handle = io.popen("sudo ./setconfig -I 01-0"..line.."_57600_ -a "..b.." -v 2")
		local result = handle:read("*a")
		if not string.find(result, "V") then
			packetLose = packetLose + 1
		elseif Version == "Version: not available " and not string.find(result, "ERROR IN CRC") and not string.find(result, "ERROR") then
			Version = result
		end
		handle:close()
	end
	return (packetLose*5), Version:sub(1, -2)
end

function Communication:WriteFCError(table)
	local nbrError = Main:tableLength(table)
	LogFile:Write("FC Sensor with no commnication number: "..nbrError, 2)
	local string = ""
	if nbrError > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("FC Sensor with no commnication address list: "..string, 2)
	end
end

function Communication:WriteFCWarning(table)
	local nbrWarning = Main:tableLength(table)
	LogFile:Write("FC Sensor with bad communication number: "..nbrWarning, 2)
	local string = ""
	if nbrWarning > 0 then
		for _ , sen in pairs(table) do
			if string ~= "" then string = string..", " end
			string = string..sen
		end
	end
	if string ~= "" then
		LogFile:Write("FC Sensor with bad commnication address list: "..string, 2)
	end
end

----------------------------------------------------------------------------------

function Finder:Load()
	local db = Database:Init()	
	self.comLine = { }
	---------------
	self:Line(db)
	self:Concentrator(db)
	self:Sensor(db)
	self:Vms(db)
	self:VmsSortie(db)
	self:FullControl(db)
	------------------
	self:Write_Global_Information()
	db:Disconnect()
	os.execute("clear")
	-------------------------------------
	return self.comLine
end

function Finder:Line(db)
	local cur = db:Query("SELECT DISTINCT master AS master from cfgconcentrators")
	row = cur:fetch ({}, "a")
	while row do
		data = tonumber(row.master)
	  	self.comLine[data] = { 
	   		id = data,
	   		concentrator = { }
		} 
	   row = cur:fetch (row, "a")
	end
	local cur = cur:close()
end

function Finder:Concentrator(db)
	for _, data in pairs(self.comLine) do
		local nbr = data.id
		local cur = db:Query("SELECT DISTINCT concentrator AS concentrator from cfgconcentrators WHERE master = "..nbr.." ORDER BY concentrator ASC")
		row = cur:fetch ({}, "a")
		while row do
			data = tonumber(row.concentrator)
			self.comLine[nbr].concentrator[data] = {
				id = data
			}
		   	row = cur:fetch (row, "a")
		end

		local cur = cur:close()
	end
end

function Finder:Sensor(db)
	for _, data in pairs(self.comLine) do
		local nbr = data.id
		for uid, concentrator in pairs (data.concentrator) do
			local con = concentrator.id
			self.comLine[nbr].concentrator[con].sensor = { }
			local cur = db:Query("SELECT DISTINCT sensor AS sensor from cfgsensors WHERE master = "..nbr.." and concentrator = "..con)
			row = cur:fetch ({}, "a")
			while row do
				data = tonumber(row.sensor)
				table.insert(self.comLine[nbr].concentrator[con].sensor, data)
			   	row = cur:fetch (row, "a")
			end

			local cur = cur:close()
		end
	end
end

function Finder:Vms(db)
	for _, data in pairs (self.comLine) do
		local nbr = data.id
		for uid, concentrator in pairs (data.concentrator) do
			local con = concentrator.id
			self.comLine[nbr].concentrator[con].vms = { }
			local cur = db:Query("SELECT DISTINCT vms AS vms from cfgvmses WHERE master = "..nbr.." and concentrator = "..con)
			row = cur:fetch ({}, "a")
			while row do
				data = tonumber(row.vms)
				table.insert(self.comLine[nbr].concentrator[con].vms, data)
			   	row = cur:fetch (row, "a")
			end

			local cur = cur:close()
		end
	end
end

function Finder:VmsSortie(db)
	for _, data in pairs (self.comLine) do
		local nbr = data.id
		for uid, concentrator in pairs (data.concentrator) do
			local con = concentrator.id
			self.comLine[nbr].concentrator[con].vmssorties = { }
			local cur = db:Query("SELECT DISTINCT VmsSortie AS vms from cfgvmssorties WHERE Master = "..nbr.." and Concentrator = "..con)
			row = cur:fetch ({}, "a")
			while row do
				data = tonumber(row.vms)
				table.insert(self.comLine[nbr].concentrator[con].vmssorties, data)
			   	row = cur:fetch (row, "a")
			end

			local cur = cur:close()
		end
	end
end

function Finder:FullControl(db)
	for _, data in pairs (self.comLine) do
		local nbr = data.id
		for uid, concentrator in pairs (data.concentrator) do
			local con = concentrator.id
			self.comLine[nbr].concentrator[con].fc = { }
			local cur = db:Query("SELECT DISTINCT fullcontrol AS fc from cfgfullcontrols WHERE master = "..nbr.." and concentrator = "..con)
			row = cur:fetch ({}, "a")
			while row do
				data = tonumber(row.fc)
				table.insert(self.comLine[nbr].concentrator[con].fc, data)
			   	row = cur:fetch (row, "a")
			end

			local cur = cur:close()
		end
	end
end

function Finder:Write_Global_Information()
	self:Write_Line()
	self:Write_Concentrator()
	self:Write_Sensor()
	self:Write_VMS()
	self:Write_VMSSorties()
	self:Write_FC()
end

function Finder:Write_Line()
	LogFile:Write("---------[ LINE ]---------", 1)
	LogFile:Write("Line number: "..Main:tableLength(self.comLine),1)
	for uid, line in Main:spairs(self.comLine, function(t,a,b) return t[b].id > t[a].id end) do
		LogFile:Write("Line: "..line.id, 1)
	end
	LogFile:BackLine(1)
end

function Finder:Write_Concentrator()
	for uid, line in pairs(self.comLine) do
		LogFile:Write("-----[ LINE "..line.id.." - CONCENTRATOR ]-----", 1)
		LogFile:Write("Concentrator number: "..Main:tableLength(line.concentrator), 1)
		local string = ""
		local continuity = { }
		local startCon = 0
		local lastCon = 0
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			if string ~= "" then string = string..", " end
			string = string..concentrator.id
			if startCon == 0 then
				startCon = concentrator.id
				lastCon = concentrator.id
				continuity[lastCon] = { first = concentrator.id, last = concentrator.id }
			end
			if concentrator.id == (lastCon + 2) then
				continuity[concentrator.id] =  { first = continuity[lastCon].first, last = concentrator.id }
				continuity[lastCon] = nil
			else
				startCon = concentrator.id
				lastCon = concentrator.id
				continuity[lastCon] = { first = concentrator.id, last = concentrator.id }
			end
			lastCon = concentrator.id
		end
		LogFile:Write("Concentrator address list: "..string, 1)
		string = ""
		for uid, data in Main:spairs(continuity, function(t,a,b) return t[b].first > t[a].first end) do
			if string ~= "" then string = string..", " end
			string = string..data.first.." to "..data.last
		end
		LogFile:Write("Concentrator continuity: "..string, 1)
		LogFile:BackLine(1)
	end
end

function Finder:Write_Sensor()
	LogFile:Write("-------[ SENSORS ]--------", 1)
	local count = 0
	for uid, line in pairs(self.comLine) do
		for uid, concentrator in pairs (line.concentrator) do
			for uid, sensors in pairs (line.concentrator[concentrator.id].sensor) do
				count = count + 1
			end
		end
	end
	LogFile:Write("Sensors number: "..count, 1)
	LogFile:BackLine(1)
	
	for uid, line in pairs(self.comLine) do
		count = 0
		for uid, concentrator in pairs (line.concentrator) do
			for uid, sensors in pairs (line.concentrator[concentrator.id].sensor) do
				count = count + 1
			end
		end
		if count > 0 then
			LogFile:Write("-------[ LINE "..line.id.." - SENSORS ]--------", 1)
			LogFile:Write("Sensors number: "..count, 1)
			LogFile:BackLine(1)
		end
	end

	for uid, line in pairs(self.comLine) do
		for uid, concentrator in Main:spairs (line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			local count = Main:tableLength(line.concentrator[concentrator.id].sensor)
			if count > 0 then 
				LogFile:Write("-------[ LINE "..line.id.." - CONCENTRATOR "..concentrator.id.." - SENSORS ]--------", 1)
				LogFile:Write("Sensor number: "..count, 1)
				local string = ""
				for uid, sensors in Main:spairs (line.concentrator[concentrator.id].sensor, function(t,a,b) return t[b] > t[a] end) do 
					if string ~= "" then string = string..", " end
					string = string..sensors
				end
				LogFile:Write("Sensor address list: "..string, 1) 
				LogFile:BackLine(1)
			end
		end
	end
end

function Finder:Write_VMS()
	LogFile:Write("---------[ VMS ]----------", 1)
	local count = 0
	for uid, line in pairs(self.comLine) do
		for uid, concentrator in pairs (line.concentrator) do
			for uid, vms in pairs (line.concentrator[concentrator.id].vms) do
				count = count + 1
			end
		end
	end
	LogFile:Write("Vms number: "..count, 1)
	LogFile:BackLine(1)

	for uid, line in pairs(self.comLine) do
		count = 0
		for uid, concentrator in pairs (line.concentrator) do
			for uid, vms in pairs (line.concentrator[concentrator.id].vms) do
				count = count + 1
			end
		end
		if count > 0 then
			LogFile:Write("-------[ LINE "..line.id.." - VMS ]--------", 1)
			LogFile:Write("Line"..line.id.." - Vms number: "..count, 1) 
			LogFile:BackLine(1)
		end
	end

	for uid, line in pairs(self.comLine) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			local count = Main:tableLength(line.concentrator[concentrator.id].vms)
			if count > 0 then 
				LogFile:Write("-------[ LINE "..line.id.." - CONCENTRATOR "..concentrator.id.." - VMS ]--------", 1)
				LogFile:Write("Vms number: "..count, 1) 
				local string = ""
				for uid, vms in pairs (line.concentrator[concentrator.id].vms) do 
					if string ~= "" then string = string..", " end
					string = string..vms
				end
				LogFile:Write("Vms address list: "..string, 1) 
				LogFile:BackLine(1) 
			end
		end
	end
end

function Finder:Write_VMSSorties()
	LogFile:Write("---------[ VMS SORTIES ]----------", 1)
	local count = 0
	for uid, line in pairs(self.comLine) do
		for uid, concentrator in pairs (line.concentrator) do
			for uid, vms in pairs (line.concentrator[concentrator.id].vmssorties) do
				count = count + 1
			end
		end
	end
	LogFile:Write("Vms Sorties number: "..count, 1)
	LogFile:BackLine(1)

	for uid, line in pairs(self.comLine) do
		count = 0
		for uid, concentrator in pairs (line.concentrator) do
			for uid, vms in pairs (line.concentrator[concentrator.id].vmssorties) do
				count = count + 1
			end
		end
		if count ~= 0 then 
			LogFile:Write("-------[ LINE "..line.id.." - VMS SORTIES ]--------", 1)
			LogFile:Write("Vms Sorties number: "..count, 1) 
			LogFile:BackLine(1)
		end
	end

	for uid, line in pairs(self.comLine) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			local count = Main:tableLength(line.concentrator[concentrator.id].vmssorties)
			if count ~= 0 then 
				LogFile:Write("-------[ LINE "..line.id.." - CONCENTRATOR "..concentrator.id.." - VMS SORTIES]--------", 1)
				LogFile:Write("Vms Sorties number: "..count, 1)
				local string = ""
				for uid, vms in pairs (line.concentrator[concentrator.id].vmssorties) do 
					if string ~= "" then string = string..", " end
					string = string..vms
				end
				LogFile:Write("Vms Sorties address list: "..string, 1)
				LogFile:BackLine(1)
			end
		end
	end
end

function Finder:Write_FC()
	LogFile:Write("---------[ FC ]----------", 1)
	local count = 0
	for uid, line in pairs(self.comLine) do
		for uid, concentrator in pairs (line.concentrator) do
			for uid, fc in pairs (line.concentrator[concentrator.id].fc) do
				count = count + 1
			end
		end
	end
	LogFile:Write("FC number: "..count, 1)
	LogFile:BackLine(1)

	for uid, line in pairs(self.comLine) do
		count = 0
		for uid, concentrator in pairs (line.concentrator) do
			for uid, fc in pairs (line.concentrator[concentrator.id].fc) do
				count = count + 1
			end
		end
		if count ~= 0 then 
			LogFile:Write("-------[ LINE "..line.id.." - FC ]--------", 1)
			LogFile:Write("FC number: "..count, 1) 
			LogFile:BackLine(1)
		end
	end

	for uid, line in pairs(self.comLine) do
		for uid, concentrator in Main:spairs(line.concentrator, function(t,a,b) return t[b].id > t[a].id end) do
			local count = Main:tableLength(line.concentrator[concentrator.id].fc)
			if count ~= 0 then 
				LogFile:Write("-------[ LINE "..line.id.." - CONCENTRATOR "..concentrator.id.." - FC]--------", 1)
				LogFile:Write("FC number: "..count, 1) 
				local string = ""
				for uid, fc in pairs (line.concentrator[concentrator.id].fc) do 
					if string ~= "" then string = string..", " end
					string = string..fc
				end
				LogFile:Write("FC address list: "..string, 1)
				LogFile:BackLine(1) 
			end
		end
	end
end

----------------------------------------------------------------------------------

function Database:Init()
	self.mysql = require "luasql.mysql"
	self:Connection()
	return self
end

function Database:Connection()
	local env = assert (self.mysql.mysql())
	self.con = assert (env:connect(inputData.database, inputData.user, inputData.password, inputData.server))
end

function Database:Disconnect()

	local con = assert (self.con:close())
end

function Database:Query(sql)
	local result =  assert (self.con:execute(sql))
	return result
end	

Main:Init()
