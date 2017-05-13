local event=require("event")
local filesystem = require("filesystem")
local nterm = require("term")
local component = component or require("component")
local computer = computer or package.loaded.computer
local rdir = filesystem.concat(filesystem.concat(os.getenv("PWD"), require("process").info().path), "..")
local timers = {}
filesystem.link(filesystem.concat(rdir, "/rom/"), filesystem.concat(rdir, "/home/rom"))
local env = {
  ["os"] = {
    ["queueEvent"]=computer.pushSignal,
    ["clock"] = computer.uptime,
    ["day"] = function() return 1 end,
    ["time"] = function() return 6000 end,
    ["shutdown"] = function() computer.shutdown() end,
    ["reboot"] = function() computer.shutdown(true) end,
    ["getComputerID"] = function() end,
    ["startTimer"]=function(n)
      local id
      repeat
        id = math.floor(math.random()*1000)
      until not timers[id]
      timers[id]=n+os.uptime()
      return id
    end,
  },
  ["fs"] ={
    ["list"] = function(dir)
      dir = filesystem.concat(filesystem.concat(rdir, "/home/"), filesystem.canonical(dir))
      if filesystem.isDirectory(dir) then
        local ls = filesystem.list(dir)
        local tab = {}
        for v in ls do
          table.insert(tab, v)
        end
        return tab
      end
    end,
    ["isDir"] = function(dir)
     dir = filesystem.concat(filesystem.concat(rdir, "/home/"), filesystem.canonical(dir))
     return filesystem.isDirectory(dir)
    end,
    ["exists"] = function(f)
      return filesystem.exists(filesystem.concat(rdir, "/home/", filesystem.canonical(f)))
    end,
    ["getDir"] = filesystem.path,
    ["getName"] = filesystem.name,
    ["combine"] = function(a1, a2)
      return filesystem.concat(rdir, "/home/", filesystem.canonical(a1), filesystem.canonical(a2))
    end,
    ["open"]=function(path, mode)
     print(path)
     local stream, e
     if string.find(path, rdir) then
       stream, e = require("io").open(path, mode)
     else
      stream, e = require("io").open(filesystem.concat(rdir, "/home/", filesystem.canonical(path)), mode)
     end
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
  ["term"] = {
    ["write"]=nterm.write,
    ["clear"]=nterm.clear,
    ["current"]=nterm.gpu,
    ["getCursorPos"]=nterm.getCursor,
    ["setCursorPos"]=nterm.setCursor,
    ["setCursorBlink"]=nterm.setCursorBlink,
    ["clearLine"]=nterm.clearLine,
    ["getSize"]=nterm.getViewport,
    ["isColor"]=function() return false end,
    ["isColour"]=function() return false end,
    ["getBackgroundColor"]=component.gpu.getBackground,
    ["setBackgroundColor"]=component.gpu.setBackground,
    ["getTextColor"]=component.gpu.getForeground,
    ["setTextColor"]=component.gpu.setForeground,
    ["scroll"]=function() end,
  },
  ["select"]=select,
  ["tostring"]=tostring,
  ["tonumber"]=tonumber,
  ["type"]=type,
  ["error"]=error,
}
env._ENV=env
env._G=env
local th=coroutine.create(loadfile(filesystem.concat(rdir, "bios.lua"), "t", env))
while true do
  local ed = {coroutine.resume(th,event.pull())}
  if coroutine.status(th)=="dead" then
    print(table.unpack(ed))
    break
  end
  for k,v in pairs(timers) do
   if os.uptime()<=v then
     computer.pushEvent("timer", k)
   end
  end
end