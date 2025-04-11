local component = require("component")
local term = require("term")
local unicode= require("unicode")
local gpu = component.gpu
local screen = component.screen

--Update

::main::
print("Check for update? (y/n)")
local updateVariable = io.read()
if updateVariable == "y" then
	local fileName = process.info().path
	local installPath = shell.resolve(fileName)
	os.execute("wget", {"-f", "https://raw.githubusercontent.com/AwesomeAlec1/Draconic-Reactor-Control/refs/heads/Installer/DraconicInstaller.lua", installPath})
else goto main
end
