local event=require("event")
local filesystem = require("filesystem")
local nterm = require("term")
local component = component or require("component")
local computer = computer or package.loaded.computer
local rdir = filesystem.concat(filesystem.concat(os.getenv("PWD"), require("process").info().path), "..")
local timers = {}
local events = {}
filesystem.link(filesystem.concat(rdir, "/rom/"), filesystem.concat(rdir, "/home/rom"))
local env = {
  ["os"] = {
    ["queueEvent"]=computer.pushSignal,
    ["clock"] = computer.uptime,
    ["day"] = function() return 1 end,
    ["time"] = function() return 6000 end,
   -- ["shutdown"] = function() computer.shutdown() end,
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
    ["cancelTimer"]=function(n)
      timers[id]=nil
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
      if string.find(f, rdir) then return filesystem.exists(f) end
      return filesystem.exists(filesystem.concat(rdir, "/home/", filesystem.canonical(f)))
    end,
    ["getDir"] = filesystem.path,
    ["getName"] = filesystem.name,
    ["combine"] = function(a1, a2)
      return filesystem.concat(rdir, "/home/", filesystem.canonical(a1), filesystem.canonical(a2))
    end,
    ["open"]=function(path, mode)
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
  ["math"] = math,
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
}
env.term.setTextColour = env.term.setTextColor
env.term.getTextColour = env.term.getTextColor
env.term.setBackgroundColour = env.term.setBackgroundColor
env.term.getBackgroundColour = env.term.setBackgroundColor
env._ENV=env
env._G=env
local th=coroutine.create(loadfile(filesystem.concat(rdir, "bios.lua"), "t", env))
local data, newevent = {}
while true do
  local ed = {coroutine.resume(th,table.unpack(data))}
  if coroutine.status(th)=="dead" then
    print(table.unpack(ed))
    break
  end
  data = nil
  repeat
    for k,v in pairs(timers) do
     if os.uptime()<=v then
       table.insert(events, {"timer", k})
       timers[k]=nil
     end
    end
    while #events>0 do
      if events[1][1]==ed[2] or not ed[2] then
        data = table.remove(events, 1)
      else
        table.remove(events, 1)
      end
    end
    if not data then
      newevent = {event.pull()}
      if newevent[1]=="clipboard" then
        table.insert(events, {"paste", newevent[3]})
      elseif newevent[1]=="key_down" then
        table.insert(events, {"key", newevent[4]})
        if newevent[3]>31 and newevent[3]<127 then
          table.insert(events, {"char", string.char(newevent[3])})
        end
      elseif newevent[1]=="interrupted" then
        data = {"terminated"}
      end
    end
  until data
end