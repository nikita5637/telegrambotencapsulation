#!/usr/bin/lua

-- [[ --CONFIGURE BLOCK 
DEBUG = 1
QUIET = 0
IPTABLESPATH= nil --insert your path in "". ex: "/usr/sbin/iptables" 
TORRESOLVEPATH= nil --insert your path in "". ex: "/usr/sbin/tor-resolve" 
TORUID = nil --insert uid for tor user. ex: 123
LOCALNET = "192.168.10.0/24" --local network, separate is " "(space). ex: "192.168.0.0/20 192.168.1.0/24" 
TRANSPORT = 9040 --TransPort from /etc/tor/torrc 
DNSPORT = 53 --DNSPort from /etc/tor/torrc 
--]]

-- [[  --GLOBAL VARIABLES 
GOODBYEMESSAGE = nil
TELEGRAMAPIURL = "api.telegram.org"
TELEGRAMAPIIP = nil
--]]

--Analog C "printf" function 
printf = function(s,...)
	if (QUIET ~= 1) then
		return io.write(s:format(...))
	end
end

function GetIP(url)
	local torresolve = TORRESOLVEPATH or "tor-resolve"

	local ip = nil
	local cmd = torresolve .. " " .. TELEGRAMAPIURL
	if (DEBUG == 1) then
		printf("Execute command \"%s\"\n", cmd)
	end
	local fd = io.popen(cmd, "r")
	local line = fd:read()
	fd.close()
	if (line ~= nil) then
		if (string.match(line, "(.*)")) then
			ip = string.match(line, "(.*)")
		end
	end

	if (DEBUG == 1) then
		if (ip ~= nil) then
			printf("Resolve %s: %s\n", TELEGRAMAPIURL, ip)
		else
			printf("Can't resolve %s\n", TELEGRAMAPIURL)
		end
	end
	return ip
end

function IpTablesFlush()
	printf("Flushing iptables...\n")

	local cmd = {}
	local iptables = IPTABLESPATH or "iptables"
	cmd[1] = iptables .. " -F"
	cmd[2] = iptables .. " -t nat -F"

	for i = 1, #cmd do
		if (DEBUG == 1) then
			printf("Execute command \"%s\"\n", cmd[i])
		end
		os.execute(cmd[i])
	end

	printf("Flushing iptables...done\n")
end

function IpTablesFill()
	printf("Filling ip tables...\n")

	local cmd = {}
	local iptables = IPTABLESPATH or "iptables"

-- [[ NAT table 
	cmd[#cmd + 1] = iptables .. " -t nat -A OUTPUT -m owner --uid-owner " .. TORUID .. " -j RETURN"
	cmd[#cmd + 1] = iptables .. " -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports " .. DNSPORT

	local nets =  LOCALNET .. " 127.0.0.0/9 127.128.0.0/10"
	for net in nets:gmatch("%S+") do
		cmd[#cmd + 1] = iptables .. " -t nat -A OUTPUT -d " .. net .. " -j RETURN"
	end

	cmd[#cmd + 1] = iptables .. " -t nat -A OUTPUT -d " .. TELEGRAMAPIIP .. " -p tcp --syn -j REDIRECT --to-ports " .. TRANSPORT
--]]

-- [[ FILTER table
	cmd[#cmd + 1] = iptables .. " -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT"

	local nets =  LOCALNET .. " 127.0.0.0/8"
	for net in nets:gmatch("%S+") do
		cmd[#cmd + 1] = iptables .. " -A OUTPUT -d " .. net .. " -j ACCEPT"
	end

	cmd[#cmd + 1] = iptables .. " -A OUTPUT -m owner --uid-owner " .. TORUID .. " -j ACCEPT"
--]]

	for i = 1, #cmd do
		if (DEBUG == 1) then
			printf("Execute command \"%s\"\n", cmd[i])
		end
		os.execute(cmd[i])
	end

	printf("Filling ip tables...done\n")
end

function Start()
	TELEGRAMAPIIP = GetIP(TELEGRAMAPIURL)

	if (TELEGRAMAPIIP == nil) then
		printf("ERROR: can't resolve %s", TELEGRAMAPIURL)
		return 1
	end

	IpTablesFlush()
	IpTablesFill()
	GOODBYEMESSAGE = "Successfully done! Have a nice telegram bot coding!:)"
	return 0
end

function Stop()
	IpTablesFlush()
	GOODBYEMESSAGE = "Good bye! Thanx for usable!:)"
end

function Usage()
	printf("Usage: \n")
	printf("\t%s start\n", arg[0])
	printf("\t%s stop\n", arg[0])
end

function GetTorUID()
	if (TORUID ~= nil) then
		return TORUID
	end

	local toruid
	local cmd = "cat /etc/passwd | grep tor | awk -F \':\' \'{print $3}\'"

	if (DEBUG == 1) then
		printf("Execute command \"%s\"\n", cmd)
	end

	local fd = io.popen(cmd, "r")
	local line = fd:read()
	fd.close()
	if (line ~= nil) then
		if (string.match(line, "(%d*)")) then
			toruid = string.match(line, "(%d*)")
		else
			toruid = nil
		end
	end

	return toruid
end

--Script starts here 
if (#arg ~= 1) then
	Usage()
	os.exit(1)
end

if ((arg[1] ~= "start") and (arg[1] ~= "stop")) then
	Usage()
	os.exit(1)
end

uid = os.getenv("USER")
if (uid ~= "root") then
	printf("ERROR: You must be root...\n")
	os.exit(1)
end

TORUID = GetTorUID()
if (TORUID == nil) then
	printf("ERROR: Unknown tor user id...\n")
	os.exit(1)
end

if (DEBUG == 1) then
	printf("Tor user id: %d\n", TORUID)
end

if (arg[1] == "start") then
	if (Start() ~= 0) then
		os.exit(1)
	end
elseif (arg[1] == "stop") then
	Stop()
end

if (GOODBYEMESSAGE ~= nil) then
	printf("%s\n", GOODBYEMESSAGE)
end
