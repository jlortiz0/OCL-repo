local component = require("component")
local event = require("event")
local function yn(txt)
  print(txt.." (y/n)")
  while true do
    local key = select(4, event.pull("key_down"))
    if key==21 then return true
    elseif key==49 then return false end
  end
end
local options = {[component.eeprom.address]=yn("Destroy EEPROM?")}
for k in pairs(component.list("filesys")) do
  options[k]=yn("Wipe filesystem "..k.." named "..(component.invoke(k, "getLabel") or "nil").."?")
end
for k in pairs(component.list("drive")) do
  options[k]=yn("Wipe unmanaged drive "..k.." named "..(component.invoke(k, "getLabel") or "nil").."?")
end
print("Devices that will be wiped:")
for k, v in pairs(options) do if v then print(k.." ("..component.type(k)..")") end end
if yn("Are you sure? Everything WILL be lost!") then
  local computer = require("computer")
  local fs = require("filesystem")
  for k, v in pairs(options) do
    if v then
      print("Wiping "..k)
      if component.type(k)=="eeprom" then
         component.invoke(k, "setData", "")
         component.invoke(k, "setLabel", "Blank EEPROM")
         component.invoke(k, "set", "local component=component or require(\"component\")\nlocal gpu=component.list(\"gpu\")()\nlocal screen=component.list(\"screen\")()\nif gpu and screen then\ncomponent.invoke(gpu, \"bind\", screen)\nlocal w,h=component.invoke(gpu, \"getResolution\")\ncomponent.invoke(gpu, \"setResolution\", w, h)\ncomponent.invoke(gpu, \"setBackground\", 0)\ncomponent.invoke(gpu, \"setForeground\", 0xFFFFFF)\ncomponent.invoke(gpu, \"fill\", 1, 1, w, h, \" \")\ncomponent.invoke(gpu, \"set\", 1, 1, \"This EEPROM is blank.\")\nend\ncomponent.invoke(component.list(\"computer\")(), \"beep\", 1000, 1)\nlocal computer = computer or require(\"computer\")\nwhile true do\ncomputer.pullSignal()\nend")
      elseif component.type(k)=="drive" then
        for i=1, component.invoke(k, "getCapacity") do
          component.invoke(k, "writeByte", i, 0)
        end
      elseif component.type(k)=="filesystem" then
        local function del(path)
          if component.invoke(k, "isDirectory", path) then
            for _, v in pairs(component.invoke(k, "list", path)) do
              del(fs.concat(path,tostring(v)))
            end
          end
          component.invoke(k, "remove", path)
        end
        del("")
      end
    end
  end
  if yn("Would you like to reboot?") then
    computer.shutdown(true)
  end
end