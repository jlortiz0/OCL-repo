local event=require("event")
local sides = require("sides")
local filesystem = require("filesystem")
local nterm = require("term")
local component = component or require("component")
local computer = computer or package.loaded.computer
local bit32 = require("bit32")
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
    ["time"] = function() return 6 end,
    ["shutdown"] = function() run=nil end,
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
    ["OpenOS"]=true,
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
      if string.sub(filesystem.canonical("/"..dir), 1, 5)=="/rom/" then error("Access denied.", 2) end
      if filesystem.canonical("/"..dir)=="/disk" then error("Access denied.", 2) end
      dir=filesystem.concat(rdir, filesystem.canonical(dir))
      filesystem.remove(dir)
    end,
    ["move"]=function(p1, p2)
      if string.sub(filesystem.canonical("/"..p1), 1, 4)=="/rom" or string.sub(filesystem.canonical("/"..p2), 1, 5)=="/rom/" then error("Access denied.", 2) end
      if filesystem.canonical("/"..p1)=="/disk" then error("Access denied.", 2) end
      p1=filesystem.concat(rdir, filesystem.canonical(p1))
      p2=filesystem.concat(rdir, filesystem.canonical(p2))
      filesystem.rename(p1, p2)
    end,
    ["copy"]=function(p1, p2)
      if string.sub(filesystem.canonical("/"..p2), 1, 5)=="/rom/" then error("Access denied.", 2) end
      p1=filesystem.concat(rdir, filesystem.canonical(p1))
      p2=filesystem.concat(rdir, filesystem.canonical(p2))
      filesystem.copy(p1, p2)
    end,
    ["makeDir"]=function(path)
      if string.sub(filesystem.canonical("/"..path), 1, 5)=="/rom/" then error("Access denied", 2) end
      path=filesystem.concat(rdir, filesystem.canonical(path))
      if filesystem.exists(path) then error("Directory exists.", 2) end
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
     if not mode then error("Expected string, string", 2) end
     if filesystem.isDirectory(filesystem.concat(rdir, filesystem.canonical(path))) then error("Is a directory", 2) end
     if (mode=="w" or mode=="a" or mode =="wb" or mode=="ab") and string.sub(filesystem.canonical("/"..path), 1, 5)=="/rom/" then error("Access denied.", 2) end
     local stream, e = require("io").open(filesystem.concat(rdir, filesystem.canonical(path)), mode)
     if not stream then
      error(e, 2)
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
    ["blit"]=function(s) nterm.write(s) end,
    ["write"]=nterm.write,
    ["clear"]=nterm.clear,
    ["current"]=nterm.gpu,
    ["getCursorPos"]=nterm.getCursor,
    ["setCursorPos"]=nterm.setCursor,
    ["setCursorBlink"]=function(b) cursor=b end,
    ["clearLine"]=nterm.clearLine,
    ["getSize"]=nterm.getViewport,
    ["isColor"]=function() return (component.gpu.getDepth()>2) end,
    ["getBackgroundColor"]=function() return component.gpu.getBackground() end,
    ["setBackgroundColor"]=function(c) component.gpu.setBackground(c) end,
    ["getTextColor"]=function() return component.gpu.getForeground() end,
    ["setTextColor"]=function(c) component.gpu.setForeground(c) end,
    ["scroll"]=function(n) for i=1, n do print() end end,
  },
  ["bit"]={
    ["blshift"]=bit32.lshift,
    ["brshift"]=bit32.arshift,
    ["blogic_rshift"]=bit32.rshift,
    ["bxor"]=bit32.bxor,
    ["bor"]=bit32.bor,
    ["band"]=bit32.band,
    ["bnot"]=bit32.bnot,
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
env.term.isColour=env.term.isColor
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
env.bit32 = env.bit
env.redstone.getBundledInput=function() return 0 end
env.redstone.getBundledOutput=function() return 0 end
env.redstone.setBundledOutput=function() end
env.redstone.testBundledInput=function() return false end
env.redstone.getSides = function() return {"top", "bottom", "left", "right", "front", "back"} end
env.rs = env.redstone
local function getAddrDisk()
  local ls = component.list("filesystem")
  for k in pairs(ls) do
    if k~=computer.tmpAddress() and k~=computer.getBootAddress() then
      return k
    end
  end
end
if getAddrDisk() then
  filesystem.mount(getAddrDisk(), filesystem.concat(rdir, "disk"))
end
local channels = {}
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
["open"]=function(n) if n>-1 and n<65536 then channels[n]=true end end,
["isOpen"]=function(n) return channels[n]==true end,
["close"]=function(n) channels[n]=nil end,
["closeAll"]=function() channels={} end,
["isWireless"]=function() return true end,
["transmit"]=function(ch, rep, msg)
  if type(ch)~="number" or type(ch)~=type(rep) then error("Expected number, number, any") end
  msg = require("serialization").serialize(msg)
  local max,tmsg=component.modem.maxPacketSize()-42, {}
  for i=1, math.ceil(#msg/max) do
    table.insert(tmsg, msg:sub(1, max))
    msg = msg:sub(max+1)
  end
  for i=1, #tmsg do
    component.modem.broadcast(507, ch, rep, i, #tmsg, tmsg[i])
  end
end,
}}
if component.modem then
  component.modem.open(507)
else
  methods.top=nil
end
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
  ["request"]=function(url, post, headers, async)
    local ok, err=pcall(require("internet").request, url, post, headers)
    if not ok then if async then table.insert(events, {"http_failure", url, err}) else error(err) end return end
    local name = os.tmpname()
    local f = io.open(name, "wb")
    for chunk in err do
      f:write(chunk)
    end
    f:close()
    f=component.internet.request(url)
    local res =f.response()
    f:close()
    f=io.open(name, "r")
    err={
      ["close"]=function() f:close() event.timer(5, function() filesystem.remove(name) end, 1) end,
      ["readLine"]=function() return f:read("*l") end,
      ["readAll"]=function() return f:read("*a") end,
      ["getResponseCode"]=function() return res end,
    }
    print("get")
    if async then table.insert(events, {"http_success", url, err}) end
    return err
  end,
  ["checkURL"]=function(url)
    return pcall(function() component.internet.request(url or ""):close() end)
  end,
}
end
env._ENV=env
env._G=env
env.os.reboot= function(...) nterm.clear() th=coroutine.create(loadfile(filesystem.concat(rdir, "../bios.lua"), "t", env)) if not ... then table.insert(events, {}) coroutine.yield() end end
env.os.reboot(1)
local data, mmsg, newevent = {}, {}
while true do
  local ed = {coroutine.resume(th,table.unpack(data))}
  if coroutine.status(th)=="dead" or not run then
    f=filesystem.open(filesystem.concat(rdir, "../etc"), "w")
    f:write(require("serialization").serialize(set))
    f:close()
    f=nil
    if ed[1] then
      print("Exited sucesssfully.")
    else
      print("CraftOS crashed! Details:")
      print(table.unpack(ed,2))
    end
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
    elseif newevent[1]=="modem_message" then
      if newevent[4]==507 and channels[newevent[6]] then
        if newevent[9]==1 then
          table.insert(events, {"modem_message", "top", newevent[6], newevent[7], require("serialization").unserialize(newevent[10]), newevent[5]})
        elseif mmsg[newevent[2]] then
          mmsg[newevent[2]]=mmsg[newevent[2]]..newevent[10]
          if newevent[8]==newevent[9] then
            table.insert(events, {"modem_message", "top", newevent[6], newevent[7], require("serialization").unserialize(mmsg[newevent[2]]), newevent[5]})
            newevent[9]=require("io").open(filesystem.concat(rdir, "../rednet.log"), "w")
            newevent[9]:write(mmsg[newevent[2]])
            newevent[9]:close()
            mmsg[newevent[2]]=nil
          end
        else
          mmsg[newevent[2]]=newevent[10]
        end
      end
    end
  until data
end