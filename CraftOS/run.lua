local filesystem = require("filesystem")
local computer = computer or package.loaded.computer
local rdir = filesystem.concat(filesystem.concat(os.getenv("PWD"), require("process").info().path), "..")
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
  },
  fs ={
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
    ["isDir"] = function()
     dir = filesystem.concat(filesystem.concat(rdir, "/home/"), filesystem.canonical(dir))
     return filesystem.isDirectory(dir)
   end,
    ["open"]=function(path, mode)
     local stream = require("io").open(filesystem.catcat(rdir, "/home/", path), mode)
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
}
env._ENV=env
env._G=env
require("shell").execute(filesystem.concat(rdir, "bios.lua"), env)