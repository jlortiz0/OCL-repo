local event=require("event")
local sides = require("sides")
local filesystem = require("filesystem")
local nterm = require("term")
local component = component or require("component")
local computer = computer or package.loaded.computer
local rdir = filesystem.concat(filesystem.concat(os.getenv("PWD"), require("process").info().path), "../home")
local events,tim = {}, {}
local run,cusor, th = true,false
local f = filesystem.open(filesystem.concat(rdir, "../etc"), "r")
local set = require("serialization").unserialize(f:read(math.huge))
f:close()
f=nil
filesystem.link(filesystem.concat(rdir, "../rom"), filesystem.concat(rdir, "rom"))
local env = {
  ["os"] = {
    ["queueEvent"]=function(...) table.insert(events, {...}) end,
    ["clock"] = computer.uptime,
    ["day"] = function() return 1 end,
    ["time"] = function() return 6000 end,
    ["shutdown"] = function() run=nil env=nil end,
    ["reboot"] = function() print("Reboot it yourself!") run=nil env=nil end,
    ["getComputerID"] = function() return set.id end,
    ["computerID"]=function() return set.id end,
    ["setComputerID"]=function(id) checkArg(1, id, "number") set.id=id end,
    ["getComputerLabel"]=function() return set.label end,
    ["computerLabel"]=function() return set.label end,
    ["setComputerLabel"]=function(l) checkArg(1, l, "string") set.label=label end,
    ["startTimer"]=function(n)
      local id
      repeat
        id=math.floor(math.random()*1000)
      until not tim[id]
      tim[id]=computer.uptime()+n
      return id
    end,
    ["cancelTimer"]=function(id) tim[id]=nil end,
  },
  ["fs"] ={
    ["list"] = function(dir)
      dir = filesystem.concat(rdir, filesystem.canonical(dir))
      if filesystem.isDirectory(dir) then
        local ls = filesystem.list(dir)
        local tab = {}
        for v in ls do
          table.insert(tab, v)
        end
        table.sort(tab)
        return tab
      end
    end,
    ["isDir"] = function(dir)
     dir = filesystem.concat(rdir, filesystem.canonical(dir))
     return filesystem.isDirectory(dir)
    end,
    ["exists"] = function(f)
      if string.find(filesystem.canonical(f), rdir) then return filesystem.exists(f) end
      return filesystem.exists(filesystem.concat(rdir, filesystem.canonical(f)))
    end,
    ["delete"] = function(dir)
      dir=filesystem.concat(rdir, filesystem.canonical(dir))
      filesystem.remove(dir)
    end,
    ["move"]=function(p1, p2)
      p1=filesystem.concat(rdir, filesystem.canonical(p1))
      p2=filesystem.concat(rdir, filesystem.canonical(p2))
      filesystem.rename(p1, p2)
    end,
    ["copy"]=function(p1, p2)
      p1=filesystem.concat(rdir, filesystem.canonical(p1))
      p2=filesystem.concat(rdir, filesystem.canonical(p2))
      filesystem.copy(p1, p2)
    end,
    ["makeDir"]=function(path)
      path=filesystem.concat(rdir, filesystem.canonical(path))
      filesystem.makeDirectory(path)
    end,
    ["getDir"] = filesystem.path,
    ["getName"] = filesystem.name,
    ["getDrive"]=function(path)
      path=filesystem.concat(rdir, filesystem.canonical(path))
      return filesystem.get(path).address
    end,
    ["getFreeSpace"]=function(path)
      path=filesystem.concat(rdir, filesystem.canonical(path))
      return filesystem.get(path).spaceTotal()-filesystem.get(path).spaceUsed()
    end,
    ["combine"] = function(a1, a2)
        return filesystem.concat(filesystem.canonical(a1), a2)
    end,
    ["open"]=function(path, mode)
     local stream, e = require("io").open(filesystem.concat(rdir, filesystem.canonical(path)), mode)
     if not stream then
      error(e)
     end
     local ret = {
       ["close"] = function() stream:close() end,
     }
     if mode=="r" then
       ret.readAll = function() return stream:read("*a") end
       ret.readLine = function() return stream:read("*l") end
    elseif mode=="w" or mode=="a" then
      ret.write = function(t) stream:write(t) end
      ret.writeLine = function(t) stream:write(t.."\n") end
      ret.flush = function() stream:flush() end
    elseif mode=="rb" then
      ret.read = function() return string.byte(stream:read(1)) end
    elseif mode=="wb" or mode=="ab" then
      ret.write = function(t) return stream:write(string.char(t)) end
    end
    return ret
  end,
  ["isReadOnly"] = function(f)
    f=filesystem.concat(rdir, filesystem.canonical(f))
    return (string.find(f, filesystem.concat(rdir, "rom"))~=nil or filesystem.get(f).isReadOnly())
  end,
  },
  ["ipairs"]=ipairs,
  ["string"] = string,
  ["table"] = table,
  ["coroutine"]=coroutine,
  ["setmetatable"] = setmetatable,
  ["getmetatable"] = getmetatable,
  ["load"]=load,
  ["pcall"]=pcall,
  ["xpcall"]=xpcall,
  ["call"] = call,
  ["pairs"]=pairs,
  ["math"] = math,
  ["term"] = {
    ["write"]=nterm.write,
    ["clear"]=nterm.clear,
    ["current"]=nterm.gpu,
    ["getCursorPos"]=nterm.getCursor,
    ["setCursorPos"]=nterm.setCursor,
    ["setCursorBlink"]=function(b) cursor=b end,
    ["clearLine"]=nterm.clearLine,
    ["getSize"]=nterm.getViewport,
    ["isColor"]=function() return false end,
    ["isColour"]=function() return false end,
    ["getBackgroundColor"]=function() return 32768 end,
    ["setBackgroundColor"]=function() end,
    ["getTextColor"]=function() return 1 end,
    ["setTextColor"]=function() end,
    ["scroll"]=function(n) for i=1, n do print() end end,
  },
  ["select"]=select,
  ["tostring"]=tostring,
  ["tonumber"]=tonumber,
  ["type"]=type,
  ["error"]=error,
  ["next"]=next,
  ["peripheral"] = {
    ["getNames"]=function()
      local ls = {"left"}
      if component.isAvailable("modem") then table.insert(ls, "top") end
      return ls
    end,
    ["isPresent"]=function(side)
      if side=="top" and component.isAvailable("modem") then return true end
      if side=="left" then return true end
      return false
    end,
   ["getType"]=function(side)
     if side=="top" and component.isAvailable("modem") then return "modem" end
     if side=="left" then return "drive" end
   end,
  },
}
env.term.setTextColour = env.term.setTextColor
env.term.getTextColour = env.term.getTextColor
env.term.setBackgroundColour = env.term.setBackgroundColor
env.term.getBackgroundColour = env.term.setBackgroundColor
if component.isAvailable("restone") then
  env.restone = {
    ["getInput"]=function(side) return (component.redstone.getInput(sides[side])>0) end,
    ["getOutput"]=function(side) return (component.redstone.getOutput(sides[side])>0) end,
    ["setOutput"]=function(side, out)
      if out then out=15 else out=0 end
      component.redstone.setOutput(sides[side], out)
    end,
   ["getAnalogInput"]=function(side) return component.redstone.getInput(sides[side]) end,
   ["getAnalogOutput"]=function(side) return component.redstone.getOutput(sides[side]) end,
   ["setAnalogOutput"]=function(side, n) component.redstone.setOutput(sides[side], n) end
  }
else
  env.redstone = {
   ["getInput"]=function() return 0 end,
   ["getOutput"]=function() return 0 end,
   ["setOutput"]=function() end,
   ["getAnalogInput"]=function() return 0 end,
   ["getAnalogOutput"]=function() return 0 end,
   ["setAnalogOutput"]=function() end,
  }
end
env.redstone.getBundledInput=function() return 0 end
env.redstone.getBundledOutput=function() return 0 end
env.redstone.setBundledOutput=function() end
env.redstone.testBundledInput=function() return false end
env.redstone.getSides = function() return {"top", "bottom", "left", "right", "front", "back"} end
env.rs = env.redstone
local function getAddrDisk()
  local ls = component.list("filesystem")
  --if #ls<3 then return false end
  for k in pairs(ls) do
    if k~=computer.tmpAddress() and k~=computer.getBootAddress() then
      return k
    end
  end
end
if getAddrDisk() then
  filesystem.mount(getAddrDisk(), filesystem.concat(rdir, "disk"))
end
local methods = {["left"]={
["isDiskPresent"]=function() return (getAddrDisk()~=nil) end,
["hasData"]=function() return (getAddrDisk()~=nil) end,
["getMountPath"]=function() if getAddrDisk() then return "/disk" end end,
["setDiskLabel"]=function(t) component.invoke(getAddrDisk(), "setLabel", t) end,
["getDiskLabel"]=function() return component.invoke(getAddrDisk(), "getLabel") end,
["getDiskID"]=getAddrDisk,
["hasAudio"]=function() return false end,
["getAudioTitle"]=function() end,
["playAudio"]=function() end,
["stopAudio"]=function() end,
["ejectDisk"]=function() end,
},["top"]={

}}
env.peripheral.getMethods = function(side)
  local l = {}
  for k in pairs(methods[side]) do
    table.insert(l, k)
  end
  return l
end
env.peripheral.call = function(side, method, ...)
  return methods[side][method](...)
end
if component.isAvailable("internet") and component.internet.isHttpEnabled() then
env.http={
  ["request"]=function(url, post, headers)
    local h,err=component.internet.request(url, post, headers)
    if not h then table.insert(events, {"http_failure", url, err}) return end
    repeat
      os.sleep(0.05)
    until h:finishConnect()~=false
    if not ({h:finishConnect()})[1] then
      table.insert(events, {"http_failure", url, select(2, h:finishConnect())})
      return
    else
      local name = os.tmpname()
      local f = io.open(name, "w")
      f:write(h.read(math.huge))
      f:close()
      local res = h.response()
      h:close()
      f=io.open(name, "r")
      h={
        ["close"]=function() f:close() filesystem.remove(name) end,
        ["readLine"]=function() return f:read("*l") end,
        ["readAll"]=function() return f:read("*a") end,
        ["getResponseCode"]=function() return res end,
      }
      table.insert(events, {"http_success", url, h})
      return
    end
  end,
  ["checkURL"]=function(url)
    return pcall(function() component.internet.request(url):close() end)
  end,
}
end
env._ENV=env
env._G=env
nterm.clear()
th=coroutine.create(loadfile(filesystem.concat(rdir, "../bios.lua"), "t", env))
local data, newevent = {}
while true do
  local ed = {coroutine.resume(th,table.unpack(data))}
  if coroutine.status(th)=="dead" or not run then
    f=filesystem.open(filesystem.concat(rdir, "../etc"), "w")
    f:write(require("serialization").serialize(set))
    f:close()
    f=nil
    print(table.unpack(ed))
    env=nil
    filesystem.umount(filesystem.concat(rdir, "disk"))
    break
  end
  data = nil
  repeat
    for k,v in pairs(tim) do
      if computer.uptime()>v then
        table.insert(events, {"timer", k})
        tim[k]=nil
      end
    end
    while #events>0 do
      if events[1][1]==ed[2] or not ed[2] then
        data = table.remove(events, 1)
        break
      else
        table.remove(events, 1)
      end
    end
    if cursor then
      newevent={nterm.pull(0.1)}
    else
      newevent = {event.pull(0.1)}
    end
    if newevent[1]=="clipboard" then
      table.insert(events, {"paste", newevent[3]})
    elseif newevent[1]=="key_down" then
      table.insert(events, {"key", newevent[4]})
      if newevent[3]>31 and newevent[3]<127 then
        table.insert(events, {"char", string.char(newevent[3])})
      end
    elseif newevent[1]=="screen_resized" then
      table.insert(events, {"term_resize"})
    elseif newevent[1]=="touch" then
      table.insert(events, {"mouse_click", newevent[5], newevent[3], newevent[4]})
    elseif newevent[1]=="scroll" then
      table.insert(events, {"mouse_scroll", newevent[5], newevent[3], newevent[4]})
    elseif newevent[1]=="drag" then
      table.insert(events, {"mouse_drag", newevent[5], newevent[3], newevent[4]})
    elseif newevent[1]=="drop" then
      table.insert(events, {"mouse_up", newevent[5], newevent[3], newevent[4]})
    elseif newevent[1]=="redstone_changed" then
      table.insert(events, {"redstone"})
    elseif newevent[1]=="component_added" and newevent[3]=="filesystem" and getAddrDisk()==newevent[2] then
      filesystem.umount(filesystem.concat(rdir, "disk"))
      filesystem.mount(newevent[2], filesystem.concat(rdir, "disk"))
      table.insert(events, {"disk", "left"})
    elseif newevent[1]=="component_removed" and newevent[3]=="filesystem" then
      table.insert(events, {"disk_eject", "left"})
    elseif newevent[1]=="interrupted" then
      data = {"terminate"}
    end
  until data
end