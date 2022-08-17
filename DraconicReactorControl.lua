local component = require("component")
local tty       = require("tty")

tty.clear()

-- Wrap Reactor Components -------------------------------------------------------------------------
if not component.draconic_reactor then
  print("Draconic reactor not found. Either your setup is invalid, or you have bigger problems on your hands.")
  os.exit()
end
local reactor = component.draconic_reactor

if not component.flux_gate then
  print("No flux gates connected; please connect inflow and outflow flux gates with Adapter blocks.")
  os.exit()
end
local flux_gates = {}
for address, _ in pairs(component.list("flux_gate")) do
  flux_gates[#flux_gates+1] = address
end
if #flux_gates < 2 then
  print("Not enough flux gates connected; please connect inflow and outflow flux gates with Adapter blocks.")
  os.exit()
end
local inputFlux = component.proxy(flux_gates[1])
local outputFlux = component.proxy(flux_gates[2])
inputFlux.setOverrideEnabled(true)
outputFlux.setOverrideEnabled(true)

-- Control Variables--------------------------------------------------------------------------------
local tArgs = {...}
local targetTemp = tonumber(tArgs[1]) or 8000  -- Desired temperature
local targetField = tonumber(tArgs[2]) or 0.15 -- Desired shield strength
local swapFlux = tonumber(tArgs[3]) or 1 -- Swap input and output flux gates
local reactorOutputMultiplier = tonumber(tArgs[4]) or 1 -- Reactor output multiplier (mod cfg)
local helpVar = tonumber(tArgs[5]) or 0 -- Help Command = 1

if targetTemp < 2500 then targetTemp = 2500 elseif targetTemp > 15000 then targetTemp = 15000 end
if targetField < 0.00001 then targetField = 0.00001 elseif targetField > 1 then targetField = 1 end
if swapFlux < 1 then swapFlux = 1 elseif swapFlux > 2 then swapFlux = 2 end

-- Swap Flux Gates----------------------------------------------------------------------------------

local oldAddress = inputFlux.address
if swapFlux == 2 then
     inputFlux = component.proxy(outputFlux.address)
     outputFlux = component.proxy(oldAddress)
 end

-- Control Loop

local function update()

  while true do
    tty.clear()
	 
    local reactorInfo = reactor.getReactorInfo() -- Get reactor status

	if reactorInfo.temperature < 2000 then
		reactor.chargeReactor()
	 end
	 if reactorInfo.temperature >= 2000 and reactorInfo.status ~= "stopping"  then
		reactor.activateReactor()
	end

    -- CALCULATIONS ---------------------------------------

    -- Reactor equation variables
    local targetTemp50  = math.min((targetTemp / 10000) * 50, 99)
    local coreSat       = reactorInfo.energySaturation / reactorInfo.maxEnergySaturation
    local convLVL       = (reactorInfo.fuelConversion / reactorInfo.maxFuelConversion * 1.3) - 0.3

    -- Calculate the temperature rise resistance for the reactor at the desired temperature.
    local targetTempResist = ((targetTemp50^4) / (100 - targetTemp50))
          print(string.format("Temp Resist for target temp %d (%d): %.2f", targetTemp, targetTemp50, targetTempResist))

    -- Calculate the temperature rise exponential needed to reach the desired temperature
    local targetTempExpo = -(targetTempResist*convLVL) - 1000*convLVL + targetTempResist
          print(string.format("Temp expo for convLVL %.2f: %.2f", convLVL, targetTempExpo))

    -- Calculate the saturation level needed to produce the required tempRiseExpo
    local term1 = 1334.1-(3*targetTempExpo)
    local term2 = (1200690-(2700*targetTempExpo))^2
    local term3 = ((-1350*targetTempExpo)+(((-4*term1^3+term2)^(1/2))/2)+600345)^(1/3)
    local targetNegCSat = -(term1/(3*term3))-(term3/3)
          print(string.format("NegCSat for tempExpo %.2f: %.2f", targetTempExpo, targetNegCSat))

    -- Saturation received from above equation needs to be reformatted to a more useful form
    local targetCoreSat = 1 - (targetNegCSat/99)
    local targetSat = targetCoreSat * reactorInfo.maxEnergySaturation
          print(string.format("Saturation needed for zero rise: %d (%3.2f%%)", targetSat, targetCoreSat*100))

    -- Calculate the difference between where saturation is and where it needs to be
    local saturationError = reactorInfo.energySaturation - targetSat
          print(string.format("Error between current saturation and target saturation: %d\n", saturationError))

    -- Calculate field drain
    local tempDrainFactor = 0
    if reactorInfo.temperature > 8000 then
      tempDrainFactor = 1 + ((reactorInfo.temperature-8000)^2 * 0.0000025)
    elseif reactorInfo.temperature > 2000 then
      tempDrainFactor = 1
    elseif reactorInfo.temperature > 1000 then
      tempDrainFactor = (reactorInfo.temperature-1000)/1000
    end
    print(string.format("Current temp drain factor for temp %d is %1.2f", reactorInfo.temperature, tempDrainFactor))
    
    local baseMaxRFt = (reactorInfo.maxEnergySaturation / 1000) * reactorOutputMultiplier * 1.5
    local fieldDrain = math.min(tempDrainFactor * math.max(0.01, (1-coreSat)) * (baseMaxRFt / 10.923556), 2147000000)
          print(string.format("Current field drain is %d RF/t", reactorInfo.fieldDrainRate))
    local fieldNegPercent = 1 - targetField
          print(string.format("fieldNegPercent is %d", fieldNegPercent))
    --local fieldInputRate = fieldDrain / fieldNegPercent
    local fieldStrengthError = (reactorInfo.maxFieldStrength * targetField) - reactorInfo.fieldStrength
          print(string.format("Error between current field strength and target strength: %d", fieldStrengthError))
    local requiredInput = math.min((reactorInfo.maxFieldStrength * reactorInfo.fieldDrainRate) / (reactorInfo.maxFieldStrength - reactorInfo.fieldStrength), reactorInfo.maxFieldStrength - reactorInfo.fieldStrength)
          print(string.format("Required input to counter field drain: %d RF/t\n", requiredInput))

    -------------------------------------------------------    

    if reactorInfo.status == "running" then

      if reactorInfo.fuelConversion / reactorInfo.maxFuelConversion > 0.85 then
        reactor.stopReactor()
      end

      -- Control the output gate to drain the reactor to needed saturation,
      -- min function used to prevent from draining the reactor too fast
      local outputNeeded = math.min(saturationError, (reactorInfo.maxEnergySaturation/40))-- + reactorInfo.generationRate
      outputFlux.setFlowOverride(outputNeeded)
      print(string.format("Setting output flux gate to %d RF/t", outputNeeded))

      inputFlux.setFlowOverride(math.min(fieldStrengthError + requiredInput, reactorInfo.maxFieldStrength) - reactorInfo.fieldDrainRate + 1)
      print(string.format("Setting input flux gate to %d RF/t", requiredInput))

    elseif reactorInfo.status == "warming_up" then

      outputFlux.setFlowOverride(0)
      inputFlux.setFlowOverride(5000000)
      print(string.format("Reactor Charging; flooding reactor"))

    elseif reactorInfo.status == "stopping" then

      outputFlux.setFlowOverride(0)
      inputFlux.setFlowOverride(requiredInput)
      print(string.format("Setting input flux gate to %d RF/t", inputFlux.getSignalLowFlow()))

    end

    os.sleep(0.05)
  end
end

update()