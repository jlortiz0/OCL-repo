local computer = require("computer")
local total, free
if computer.totalMemory()>1048575 then
  total=(math.floor(computer.totalMemory()/10485.76)/100).."M"
elseif computer.totalMemory()>1023 then
  total=(math.floor(computer.totalMemory()/10.24)/100).."K"
else
  total=computer.totalMemory().."B"
end
if computer.freeMemory()>1048575 then
  free=(math.floor(computer.freeMemory()/10485.76)/100).."M"
elseif computer.freeMemory()>1023 then
  free=(math.floor(computer.freeMemory()/10.24)/100).."K"
else
  free=computer.freeMemory().."B"
end

print("Total Memory:"..total)
print("Free Memory:"..free)
print("Percent Usage:"..(math.floor(((computer.totalMemory()-computer.freeMemory())/computer.totalMemory())*10000)/100).."%")