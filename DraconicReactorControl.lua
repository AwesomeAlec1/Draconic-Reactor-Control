local component = require("component")
local event = require("event")
local term = require("term")
local thread = require("thread")

local gpu = component.gpu
local screen = component.screen

-- Initial checks
if not component.draconic_reactor then
  error("No reactor found. Please connect the computer to a reactor, or check your reactor setup.")
end
if not component.flux_gate then
  error("No flux gates found. Please connect at least 1 input and 1 output flux gate to the computer, " +
  "or check your setup.")
end

-- Wrap and calibrate required components -----------------

  -- Wrap reactor and initialize reactor info
local reactor = component.draconic_reactor
local reactorInfo = reactor.getReactorInfo()

local fluxGates = {}
for address, _ in pairs(component.list("flux")) do
  fluxGates[#fluxGates + 1] = component.proxy(address)
end
if #fluxGates < 2 then
  error("Not enough flux gates to run reactor. " +
  "Please connect 1 flux gate to a reactor injector and at least 1 to a stabilizer.")
end

local inputFluxGates = {}
local outputFluxGates = {}

for i = 1, #fluxGates do
  fluxGates[i].setOverrideEnabled(true)
  fluxGates[i].setFlowOverride(0)
end
if reactorInfo.status == "warming_up" or reactorInfo.status == "cooling" or reactorInfo.status == "cold" then
  -- Slow, clean calibration
  reactor.chargeReactor()
  for i = 1, #fluxGates do
    local oldPower = reactorInfo.energySaturation + reactorInfo.fieldStrength + reactorInfo.temperature
    
    fluxGates[i].setFlowOverride(5000)
    print("Calibrating flux gate " .. i)
    os.sleep(0.25)
    fluxGates[i].setFlowOverride(0)
    
    reactorInfo = reactor.getReactorInfo()
    local newPower = reactorInfo.energySaturation + reactorInfo.fieldStrength + reactorInfo.temperature
    
    if newPower > oldPower then
      inputFluxGates[#inputFluxGates+1] = fluxGates[i]
    else
      outputFluxGates[#outputFluxGates+1] = fluxGates[i]
    end
  end
  reactor.stopReactor()
elseif reactorInfo.status == "stopping" or reactorInfo.status == "running" then
  -- Fast, messy calibration
  local wasRunning = true
  if reactorInfo.status ~= "running" then
    local wasRunning = false
    reactor.activateReactor()
  end
  for i = 1, #fluxGates do
    local oldFieldValue = reactorInfo.fieldStrength
    local oldSatValue = reactorInfo.energySaturation
    
    fluxGates[i].setFlowOverride(500000)
    print("Calibrating flux gate " .. i)
    os.sleep(0.05)
    fluxGates[i].setFlowOverride(0)
    
    reactorInfo = reactor.getReactorInfo()
    local newFieldValue = reactorInfo.fieldStrength
    local newSatValue = reactorInfo.energySaturation
    
    if newFieldValue > oldFieldValue and newSatValue > oldSatValue then
      inputFluxGates[#inputFluxGates+1] = fluxGates[i]
    elseif newSatValue < oldSatValue and newFieldValue < oldFieldValue then
      outputFluxGates[#outputFluxGates+1] = fluxGates[i]
    end
  end
  if not wasRunning then reactor.stopReactor() end
else
  error("Calibration error. Reactor is either in an invalid setup or has gone critical.")
end

-----------------------------------------------------------

-- Declare / initialize variables -------------------------

  -- Constants
local MIN_TEMP = 2000
local MAX_FIELD = 1.0
local MIN_FUEL = 0.0
  -- Target values
local targetTemp = 8000
local targetField = 0.30
local targetFuel = 0.90
  -- Constraints
local maxTargetTemp = 8000
local minTargetField = 0.005
local maxFuel = 0.99
  -- Misc.
local isChaosMode = false
local buttons = {}
local highestTemp = 0
local lowestField = 1
local lowestFuel = 10368
local highestOutput = 0
local programStatus = "OKAY"

-----------------------------------------------------------

-- Helper Functions ---------------------------------------

local function setTargetTemp(newTemp)
  if newTemp > maxTargetTemp then
    newTemp = maxTargetTemp
  elseif newTemp < MIN_TEMP then
    newTemp = MIN_TEMP
  end
  targetTemp = newTemp
  return targetTemp
end

local function setTargetField(newField)
  if newField > MAX_FIELD then
    newField = MAX_FIELD
  elseif newField < minTargetField then
    newField = minTargetField
  end
  targetField = newField
  return targetField
end

local function setTargetFuel(newFuel)
  if newFuel > maxFuel then
    newFuel = maxFuel
  elseif newFuel < MIN_FUEL then
    newFuel = MIN_FUEL
  end
  targetFuel = newFuel
  return targetFuel
end

local function setReactorOutput(newOutput)
  if #outputFluxGates == 1 then
    outputFluxGates[1].setFlowOverride(newOutput)
  else
    for i = 1, #outputFluxGates do
      outputFluxGates[i].setFlowOverride(newOutput / #outputFluxGates)
    end
  end
end

local function getReactorOutput()
  if #outputFluxGates == 1 then
    return outputFluxGates[1].getFlow()
  else
    local outputSum = 0
    for i = 1, #outputFluxGates do
      outputSum = outputFluxGates[i].getFlow()
    end
    return outputSum
  end
end

local function setReactorInput(newInput)
  if #inputFluxGates == 1 then
    inputFluxGates[1].setFlowOverride(newInput)
  else
    for i = 1, #inputFluxGates do
      inputFluxGates[i].setFlowOverride(newInput / #inputFluxGates)
    end
  end
end

local function getReactorInput()
  if #inputFluxGates == 1 then
    return inputFluxGates[1].getFlow()
  else
    local inputSum = 0
    for i = 1, #inputFluxGates do
      inputSum = inputSum + inputFluxGates[i].getFlow()
    end
    return inputSum
  end
end

-----------------------------------------------------------

-- Main Functions -----------------------------------------
local eventLoop = true

  -- Handles reactor and flux gate operation
local function runReactor()

  while eventLoop do

    reactorInfo = reactor.getReactorInfo()

    -- Reactor equation variables
    local targetTemp50  = math.min((targetTemp / 10000) * 50, 99)
    local convLVL       = (reactorInfo.fuelConversion / reactorInfo.maxFuelConversion * 1.3) - 0.3
 
    -- Calculate the temperature rise resistance for the reactor at the desired temperature.
    local targetTempResist = ((targetTemp50^4) / (100 - targetTemp50))
 
    -- Calculate the temperature rise exponential needed to reach the desired temperature
    local targetTempExpo = -(targetTempResist*convLVL) - 1000*convLVL + targetTempResist
 
    -- Calculate the saturation level needed to produce the required tempRiseExpo
    local term1 = 1334.1-(3*targetTempExpo)
    local term2 = (1200690-(2700*targetTempExpo))^2
    local term3 = ((-1350*targetTempExpo)+(((-4*term1^3+term2)^(1/2))/2)+600345)^(1/3)
    local targetNegCSat = -(term1/(3*term3))-(term3/3)
 
    -- Saturation received from above equation needs to be reformatted to a more useful form
    local targetCoreSat = 1 - (targetNegCSat/99)
    local targetSat = targetCoreSat * reactorInfo.maxEnergySaturation
 
    -- Calculate the difference between where saturation is and where it needs to be
    local saturationError = reactorInfo.energySaturation - targetSat
    local requiredOutput = math.min(saturationError, reactorInfo.maxEnergySaturation / 40) --+ reactorInfo.generationRate

    -- Calculate field input
    local fieldNegPercent = 1 - targetField
    local fieldStrengthError = (reactorInfo.maxFieldStrength * targetField) - reactorInfo.fieldStrength
    local requiredInput = math.min(fieldStrengthError + (reactorInfo.maxFieldStrength * reactorInfo.fieldDrainRate) / (reactorInfo.maxFieldStrength - reactorInfo.fieldStrength) - reactorInfo.fieldDrainRate + 1,
                            reactorInfo.maxFieldStrength - reactorInfo.fieldStrength)

    if reactorInfo.status == "warming_up" then

      if reactorInfo.fuelConversion / reactorInfo.maxFuelConversion > targetFuel then
        reactor.stopReactor()
      else
        if reactorInfo.temperature >= 2000 then
          reactor.activateReactor()
        else
          setReactorOutput(0)
          setReactorInput(5000000)
        end
      end

    elseif reactorInfo.status == "running" then

      if reactorInfo.fuelConversion / reactorInfo.maxFuelConversion > targetFuel then
        reactor.stopReactor()
      end

      setReactorOutput(requiredOutput)
      setReactorInput(requiredInput)

    elseif reactorInfo.status == "stopping" then

      setReactorOutput(0)
      setReactorInput(requiredInput)

    end
    
    --print("runReactor okay")
    os.sleep(0.05)
  end
  print("runReactorThread exited")
end

  -- Draw buttons and UI elements based on parameter changes
local function drawUI()
  local adjButtonWidth = 19
  local tempAdjustXOffset = 68
  local tempAdjustYOffset = 2
  local fieldAdjustXOffset = tempAdjustXOffset + adjButtonWidth + 2
  local fieldAdjustYOffset = 2

  buttons = {
    start = {
      x = 2,
      y = 30,
      width = 18,
      height = 1,
      text = "Start",
      action = function() 
        if reactorInfo.status == "cooling" or reactorInfo.status == "cold" then
          reactor.chargeReactor()
        elseif reactorInfo.status == "stopping" then
          maxTargetTemp = 8000
          setTargetTemp(targetTemp or 8000)

          minTargetField = 0.01
          setTargetField(targetField or 0.15)

          reactor.activateReactor()
        end
      end,
      condition = function() 
        return reactorInfo.status == "cold"
          or reactorInfo.status == "stopping"
          or reactorInfo.status == "cooling"
      end
    },
    shutdown = {
      x = 2,
      y = 30,
      width = 18,
      height = 1,
      text = "Shutdown",
      action = function()
        reactor.stopReactor()
      end,
      condition = function() 
        return reactorInfo.status == "running"
          or reactorInfo.status == "warming_up"
      end
    },
    chaosMode = {
      x = 2,
      y = 32,
      width = 18,
      height = 1,
      text = " Chaos Mode",
      action = function()
        if isChaosMode then
          maxTargetTemp = 19900
          setTargetTemp(maxTargetTemp)

          minTargetField = 0.75
          setTargetField(targetField)
        else
          maxTargetTemp = 8000
          setTargetTemp(targetTemp)

          minTargetField = 0.005
          setTargetField(targetField)
        end
        isChaosMode = not isChaosMode
      end,
      condition = function()
        return reactorInfo.status == "running"
      end
    },
    analytics = {
      x = 42,
      y = 30,
      width = 18,
      height = 1,
      text = "Reset Analytics",
      action = function()
        highestTemp = 0
        lowestField = 200
        highestOutput = 0
        programStatus = "OKAY"
      end,
    },
    exitProgram = {
      x = 22,
      y = 30,
      width = 18,
      height = 1,
      text = "Force Exit",
      action = function()
        reactor.stopReactor()
        gpu.setResolution(gpu.maxResolution())
        eventLoop = false
      end,
    },
    tempUpMax = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset,
      width = adjButtonWidth,
      height = 1,
      text = "MAX",
      action = function() setTargetTemp(maxTargetTemp) end
    },
    temp_up_thousand = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+2,
      width = adjButtonWidth,
      height = 1,
      text = "+1000",
      action = function() setTargetTemp(targetTemp+1000) end
    },
    temp_up_hundred = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+4,
      width = adjButtonWidth,
      height = 1,
      text = "+100",
      action = function() setTargetTemp(targetTemp+100) end
    },
    temp_up_ten = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+6,
      width = adjButtonWidth,
      height = 1,
      text = "+10",
      action = function() setTargetTemp(targetTemp+10) end
    },
    temp_up_one = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+8,
      width = adjButtonWidth,
      height = 1,
      text = "+1",
      action = function() setTargetTemp(targetTemp+1) end
    },
    temp_down_thousand = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+18,
      width = adjButtonWidth,
      height = 1,
      text = "-1000",
      action = function() setTargetTemp(targetTemp-1000) end
    },
    temp_down_max = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+20,
      width = adjButtonWidth,
      height = 1,
      text = "Minimum",
      action = function() setTargetTemp(MIN_TEMP) end
    },
    temp_down_hundred = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+16,
      width = adjButtonWidth,
      height = 1,
      text = "-100",
      action = function() setTargetTemp(targetTemp-100) end
    },
    temp_down_ten = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+14,
      width = adjButtonWidth,
      height = 1,
      text = "-10",
      action = function() setTargetTemp(targetTemp-10) end
    },
    temp_down_one = {
      x = tempAdjustXOffset,
      y = tempAdjustYOffset+12,
      width = adjButtonWidth,
      height = 1,
      text = "-1",
      action = function() setTargetTemp(targetTemp-1) end
    },
    field_up_ten = {
      x = fieldAdjustXOffset,
      y = fieldAdjustYOffset+3,
      width = adjButtonWidth,
      height = 1,
      text = "+10",
      action = function() setTargetField(targetField+0.1) end
    },
    field_up_one = {
      x = fieldAdjustXOffset,
      y = fieldAdjustYOffset+5,
      width = adjButtonWidth,
      height = 1,
      text = "+1",
      action = function() setTargetField(targetField+0.01) end
    },
    field_up_tenth = {
      x = fieldAdjustXOffset,
      y = fieldAdjustYOffset+7,
      width = adjButtonWidth,
      height = 1,
      text = "+0.1",
      action = function() setTargetField(targetField+0.001) end
    },
    field_down_ten = {
      x = fieldAdjustXOffset,
      y = fieldAdjustYOffset+17,
      width = adjButtonWidth,
      height = 1,
      text = "-10",
      action = function() setTargetField(targetField-0.1) end
    },
    field_down_one = {
      x = fieldAdjustXOffset,
      y = fieldAdjustYOffset+15,
      width = adjButtonWidth,
      height = 1,
      text = "-1",
      action = function() setTargetField(targetField-0.01) end
    },
    field_down_tenth = {
      x = fieldAdjustXOffset,
      y = fieldAdjustYOffset+13,
      width = adjButtonWidth,
      height = 1,
      text = "-0.1",
      action = function() setTargetField(targetField-0.001) end
    }
  }
  
  while eventLoop do
    -- Draw screen
    if term.isAvailable() then

      -- Draw Values

      local secondsToExpire = (reactorInfo.maxFuelConversion - reactorInfo.fuelConversion) / math.max(reactorInfo.fuelConversionRate*0.00002, 0.00001)

      local left_margin = 2
      local spacing = 1
      local values = {
        "",
        "                    Reactor Stats",
        "┌─────────────────────────┬─────────────────────────┐",
        string.format("│ Field Strength:         │                  %5.1f%% │", ((reactorInfo.fieldStrength / reactorInfo.maxFieldStrength) * 100), ((reactorInfo.fieldStrength / reactorInfo.maxFieldStrength) * 100000000)),
        string.format("│ Target:                 │                  %5.1f%% │", targetField * 100),
        "├─────────────────────────┼─────────────────────────┤",
        string.format("│ Fuel Remaining:         │                  %5.1f%% │", ((1 - reactorInfo.fuelConversion / reactorInfo.maxFuelConversion) * 100)),
        string.format("│ Fuel Use Rate:          │         %10.1f nb/t │",      reactorInfo.fuelConversionRate, ((reactorInfo.fuelConversionRate / 50000) / 144)),
        string.format("│ Time Until Refuel:      │   %5dd, %2dh, %2dm, %2ds │", secondsToExpire/86400, secondsToExpire/3600 % 24, secondsToExpire/60 % 60, secondsToExpire % 60),
        "├─────────────────────────┼─────────────────────────┤",
        string.format("│ Target Temperature:     │   %7.1f°c (%7.1f°f) │", targetTemp, ((targetTemp * 1.8) + 32)),
        string.format("│ Current Temperature:    │   %7.1f°c (%7.1f°f) │", reactorInfo.temperature, ((reactorInfo.temperature * 1.8) + 32)),
        "├─────────────────────────┼─────────────────────────┤",
        string.format("│ Energy Input:           │   %12.1f RF/t     │", getReactorInput()),
        string.format("│ Energy Output:          │   %12.1f RF/t     │", getReactorOutput()),
        string.format("│ Energy Profit:          │   %12.1f RF/t     │", (getReactorOutput() - getReactorInput())),
        string.format("│ Energy Efficiency:      │   %12.1f %%       │", ((getReactorOutput() / getReactorInput()) * 100)),
        "└─────────────────────────┴─────────────────────────┘",
        "",
        "                  Debug Information",
        "┌─────────────────────────┬─────────────────────────┐",
        string.format("│ Max Field Drop:         │                  %6.2f │", lowestField),
        string.format("│ Lowest Recorded Fuel:   │                %8.2f │", lowestFuel),
        string.format("│ Max Temp Spike:         │                %8.2f │", highestTemp),
        string.format("│ Status:                 │             %11s │", reactorInfo.status),
        "└─────────────────────────┴─────────────────────────┘",
      }

      term.clear()
        
      for i, v in ipairs(values) do
        term.setCursor(left_margin, i * spacing)
        term.write(v)
      end

      -- Draw button values

      term.setCursor(tempAdjustXOffset, fieldAdjustYOffset+10)
      term.write("Reactor Temperature")
      term.setCursor(fieldAdjustXOffset+1, fieldAdjustYOffset+10)
      term.write("Field Strength")

      -- Draw Buttons

      gpu.setForeground(0x000000)

      for bname, button in pairs(buttons) do
        if button.depressed then
          button.depressed = button.depressed - 1
        end
        if button.depressed == 0 then
          button.depressed = nil
        end
      
        if button.condition == nil or button.condition() then
          local center_color = 0xAAAAAA
          local highlight_color = 0xCCCCCC
          local lowlight_color = 0x808080
          if button.depressed then
            center_color = 0x999999
            highlight_color = 0x707070
            lowlight_color = 0xBBBBBB
          end
          gpu.setBackground(center_color)
          gpu.fill(button.x, button.y, button.width, button.height, " ")
          if button.width > 1 and button.height > 1 then
            gpu.setBackground(lowlight_color)
            gpu.fill(button.x+1, button.y+button.height-1, button.width-1, 1, " ")
            gpu.fill(button.x+button.width-1, button.y, 1, button.height, " ")
            gpu.setBackground(highlight_color)
            gpu.fill(button.x, button.y, 1, button.height, " ")
            gpu.fill(button.x, button.y, button.width, 1, " ")
          end
          gpu.setBackground(center_color)
          term.setCursor(button.x + math.floor(button.width / 2 - #button.text / 2), button.y + math.floor(button.height / 2))
          term.write(button.text)
        end
      end

      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
    end
    
    --print("drawUI okay")
    os.sleep(0.1)
  end
  print("drawUIThread exited")
end

-- Handle inputs and change parameters based on inputs received
local function parseInput()
  while eventLoop do
    -- Wait for next tick, or manual shutdown

    local event, id, op1, op2 = event.pull(0.05)
    if event == "interrupted" then
      eventLoop = false
      thread.current():join()

    elseif event == "touch" then
    
      -- Handle Button Presses

      local x = op1
      local y = op2

      for bname, button in pairs(buttons) do
        if (button.condition == nil or button.condition()) and x >= button.x and x <= button.x + button.width and y >= button.y and y <= button.y + button.height then
          button.action()
          button.depressed = 3
        end
      end
    end
    
    --print("parseInput okay")
  end
  print("parseInputThread exited")
end

---------------------------------------------------------------------

local runReactorThread = thread.create(runReactor)
local drawUIThread = thread.create(drawUI)
local parseInputThread = thread.create(parseInput)
thread.waitForAny({runReactorThread, drawUIThread, parseInputThread})
--drawUI()
eventLoop = false
reactor.stopReactor()
term.clear()
term.setCursor(1,1)
local maxX, maxY = gpu.maxResolution()
gpu.setResolution(maxX,maxY)
print("exited")
