component = require("component")
term = require("term")
unicode= require("unicode")
gpu = component.gpu
screen = component.screen

--Update
print("Check for update? (y/n)")
local updateVariable = io.read()
if updateVariable == "y"
	local fileName = process.info().path
	local installPath = shell.resolve(fileName)
	os.execute(wget -f "link" installPath)
	os.execute("wget", {"-f", "link", installPath})
else goto main
end

::main::
os.execute(cls)
print("Draconic Control Installer")
print("Please select a version:")
print("")
print("stable"
print("[Stable Branches]")
print("")
print("canary")
print("[Canary Branches]")
print("")
print("legacy")
print("[Legacy Branches]")
local pathSelect = io.read()
	if pathSelect == "stable" goto stable
	elseif pathSelect == "canary" goto canary
	elseif pathSelect == "legacy" goto legacy
	else goto main
	end

--Stable versions
::stable::
os.execute(cls)
print("Draconic Control Stable Releases")
print("")
print("1"
print("Draconic Control 13.0")
print("")
print("2")
print("Draconic Control 14.0sMAT")
print("")
print("3")
print("Draconic Control 14.0xPID")
print("")
print("4")
print("Draconic Control 15.1sMAT")
local stableSelect = io.read()
	if stableSelect == "1" Link == ""
	elseif stableSelect == "2" Link == ""
	elseif stableSelect == "3" Link == ""
	elseif stableSelect == "4" Link == ""
	else goto stable
	end

--Canary versions

print("Draconic Control 15.2xSMT")

--legacy versions

print("Draconic Control Legacy Releases")
print("")
print("DraCon [CLI]")
print("")
print("")
print("Draconic Control 8.0")
print("")
print("")
print("Draconic Control 9.5b")
print("")
print("")
print("Draconic Control 11.1")
local legacySelect = io.read()
	if legacySelect == "1" Link == ""
	elseif legacySelect == "2" Link == ""
	elseif legacySelect == "3" Link == ""
	elseif legacySelect == "4" Link == ""
	else goto stable
	end

os.execute("wget", {"-f", Link, "/home/filename"})
shell.resolve(process.info().path)

local userInput = io.read()
