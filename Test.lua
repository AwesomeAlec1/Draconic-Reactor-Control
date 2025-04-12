--Requirements

local process = require("process")
local component = require("component")
local term = require("term")
local unicode = require("unicode")
local shell = require("shell")
local gpu = component.gpu
local screen = component.screen

--Update
print("Check for update? (y/n)")
local updateVariable = tostring(io.read())
if updateVariable == "y" then
	local installPath = shell.resolve(process.info().path)
	os.execute("wget -f \"https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicInstaller.lua\" " .. installPath)
	os.sleep(1)
	os.execute("cls")
	os.execute(\"installPath\")
end

local function locateAndInstall(link, fileName)
    os.execute("cls")

    print("Please specify a file directory for ", fileName)
    print("Default: /home/")
  
    local dcPath = tostring(io.read())

    if dcPath == "" then
        dcPath = "/home/"
    end

    os.execute("wget -f " .. link .. " " .. dcPath..fileName)
    print("Successfully Installed to " .. dcPath..fileName)
    os.exit()
end

local function legacy()
    while true do
        os.execute("cls")

        print("Draconic Control Legacy Releases")
        print("")
        print("1")
        print("DraCon [CLI]")
        print("")
        print("2")
        print("Draconic Control 8.0")
        print("")
        print("3")
        print("Draconic Control 9.5b")
        print("")
        print("4")
        print("Draconic Control 11.1")

        local legacySelect = tonumber(io.read())

        if legacySelect == 1 then
            local link = ""
            local fileName = "dcli"
            locateAndInstall(link, fileName)
            return
        elseif legacySelect == 2 then
            local link = ""
            local fileName = "dc8"
            locateAndInstall(link, fileName)
            return
        elseif legacySelect == 3 then
            local link = ""
            local fileName = "dc9b"
            locateAndInstall(link, fileName)
            return
        elseif legacySelect == 4 then
            local link = ""
            local fileName = "dc11"
            locateAndInstall(link, fileName)
            return
        end
    end
end

local function canary()
    while true do
        os.execute("cls")

        print("Draconic Control Canary Releases")
        print("")
        print("1")
        print("Draconic Control 15.2xSMT")
        print("")
        print("2")
        print("Draconic Control rSMT")

        local canarySelect = tonumber(io.read())

        if canarySelect == 1 then
            local link = ""
            local fileName = "dc15t"
            locateAndInstall(link, fileName)
            return
        elseif canarySelect == 2 then
            local link = "https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicReactorControl.lua"
            local fileName = "dcrSMT"
            locateAndInstall(link, fileName)
            return
        end
    end
end

local function stable()
    while true do
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

        if stableSelect == 1 then
            local link = ""
            local fileName = "dc13"
            locateAndInstall(link, fileName)
            return
        elseif stableSelect == 2 then
            local link = ""
            local fileName = "dc14e"
            locateAndInstall(link, fileName)
            return
        elseif stableSelect == 3 then
            local link = ""
            local fileName = "dc14p"
            locateAndInstall(link, fileName)
            return
        elseif stableSelect == 4 then
            local link = ""
            local fileName = "dc15e"
            locateAndInstall(link, fileName)
            return
        end
    end
end

-- Branch Selector Screen (done)
while true do
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
    print("\n")
    print("(Or, type \"exit\" to exit the installer)")

    local pathSelect = tostring(io.read())

    if     pathSelect == "stable" then stable()
    elseif pathSelect == "canary" then canary()
    elseif pathSelect == "legacy" then legacy()
    elseif pathSelect == "exit"   then os.exit(0)
    end
end
