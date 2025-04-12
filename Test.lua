--Requirements

local component = require("component")
local term = require("term")
local unicode= require("unicode")
local gpu = component.gpu
local screen = component.screen

--Initial Variables
updateVariable = "y"
fileName = "t"
DCPath = "./"
Link = "LINK"
pathSelect = "stable"

--Update

print("Check for update? (y/n)")
local updateVariable = tostring(io.read())
if updateVariable == "y" then
	local fileName = process.info().path
	local installPath = shell.resolve(fileName)
	os.execute("wget", {"-f", "https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicInstaller.lua", installPath})
else goto main
end

local function locateAndInstall() 
 os.execute("cls")
 print({"Please specify a file directory for ", fileName})
 print("Default: /home/")
 
 local DCPath = tostring(io.read())
 if DCPath == "" then
  DCPath = "/home/"
 end
 os.execute("wget", {"-f", Link, DCPath..fileName})
 print({"Successfully Installed to ", DCPath..fileName})
 os.exit()
end

local function legacy()
 os.execute("cls")
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
 local legacySelect = tonumber(io.read())
  if legacySelect == 1 then Link = "" fileName = "dcli"
  elseif legacySelect == 2 then Link = "" fileName = "dc8"
  elseif legacySelect == 3 then Link = "" fileName = "dc9b"
  elseif legacySelect == 4 then Link = "" fileName = "dc11"
  end
 locateAndInstall()
end
legacy()

local function canary()
::canary::
 os.execute("cls")
 print("Draconic Control Canary Releases")
 print("")
 print("1")
 print("Draconic Control 15.2xSMT")
 print("")
 print("2")
 print("Draconic Control rSMT")
 local canarySelect = tonumber(io.read())
  if canarySelect == 1 then Link = "" fileName = "dc15t"
  elseif canarySelect == 2 then Link = "https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicReactorControl.lua" fileName = "dcrSMT"
  end
 locateAndInstall()
end
canary()

local function stable()
 os.execute("cls")
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
 local stableSelect = tonumber(io.read())
  if stableSelect == 1 then Link = "" fileName = "dc13"
  elseif stableSelect == 2 then Link = "" fileName = "dc14e"
  elseif stableSelect == 3 then Link = "" fileName = "dc14p"
  elseif stableSelect == 4 then Link = "" fileName = "dc15e"
  end
 locateAndInstall()
end
stable()

-- Branch Selector Screen (done)

os.execute("cls")
print("Draconic Control Installer")
print("Please select a version:")
print("")
print("stable")
print("[Stable Branches]")
print("")
print("canary")
print("[Canary Branches]")
print("")
print("legacy")
print("[Legacy Branches]")
local pathSelect = tostring(io.read())
 if pathSelect == "stable" then stable()
 elseif pathSelect == "canary" then canary()
 elseif pathSelect == "legacy" then legacy()
 end
