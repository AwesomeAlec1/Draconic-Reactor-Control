component = require("component")
term = require("term")
unicode= require("unicode")
gpu = component.gpu
screen = component.screen

--Update

print("Check for update? (y/n)")
local updateVariable = io.read()
if updateVariable == "y" then
	local fileName = process.info().path
	local installPath = shell.resolve(fileName)
	os.execute("wget", {"-f", "https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicInstaller.lua", installPath})
else goto main
end

-- Branch Selector Screen (done)

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

--Stable versions (done except links)

::stable::
os.execute(cls)
print("Draconic Control Stable Releases")
print("")
print("1")
print("Draconic Control 13.0")
print("")
print("2")
print("Draconic Control 14.0e")
print("")
print("3")
print("Draconic Control 14.0p")
print("")
print("4")
print("Draconic Control 15.1e")
local stableSelect = io.read()
	if stableSelect == "1" then Link = "" fileName = "dc13"
	elseif stableSelect == "2" then Link = "" fileName = "dc14e"
	elseif stableSelect == "3" then Link = "" fileName = "dc14p"
	elseif stableSelect == "4" then Link = "" fileName = "dc15e"
	else goto stable
	end
goto selectLocation

--Canary versions (done except links)

::canary::
os.execute(cls)
print("Draconic Control Canary Releases")
print("")
print("1")
print("Draconic Control 15.2xSMT")
print("")
print("2")
print("Draconic Control rSMT")
local canarySelect = io.read()
	if canarySelect == "1" then Link = "" fileName = "dc15t"
	elseif canarySelect == "2" then Link = "https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicReactorControl.lua" fileName = "dcrSMT"
	else goto canary
	end
goto selectLocation

--legacy versions (done except links)

::legacy::
os.execute(cls)
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
	if legacySelect == "1" then Link = "" fileName = "dcli"
	elseif legacySelect == "2" then Link = "" fileName = "dc8"
	elseif legacySelect == "3" then Link = "" fileName = "dc9b"
	elseif legacySelect == "4" then Link = "" fileName = "dc11"
	else goto legacy
	end
goto selectLocation

--Actually Installing The Damn Thing (done)

::selectLocation::
os.execute(cls)
print({"Please specify a file directory for ", fileName})
print("Default: /home/")
local DCPath = io.read()
if DCPath == "" then DCPath = "/home/"
end
os.execute("wget", {"-f", Link, DCPath..fileName})
