BNP = BNP or {}

function BNP:RegisterPlate(plate)
  plate = plate or this
  if not plate then return end
  if BNP.plates[plate] then return end

  BNP.plates[plate] = true
  BNP.detected = BNP.detected + 1
end
