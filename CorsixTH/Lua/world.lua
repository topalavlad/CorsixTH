--[[ Copyright (c) 2009 Peter "Corsix" Cawley

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. --]]

local TH = require"TH"
local ipairs, _G, table_remove
    = ipairs, _G, table.remove

dofile "entity"
dofile "object"
dofile "humanoid"

class "World"

function World:World(app)
  self.map = app.map
  self.wall_types = app.walls
  self.object_types = app.objects
  self.anims = app.anims
  self.pathfinder = TH.pathfinder()
  self.pathfinder:setMap(app.map.th)
  self.entities = {}
  self.objects = {}
  self.tick_rate = 3
  self.tick_timer = 0
  self.month = 1 -- January
  self.day = 1
  self.hour = 0
  
  self.wall_id_by_block_id = {}
  for _, wall_type in ipairs(self.wall_types) do
    for _, set in ipairs{"inside_tiles", "outside_tiles", "window_tiles"} do
      for name, id in pairs(wall_type[set]) do
        self.wall_id_by_block_id[id] = wall_type.id
      end
    end
  end
end

function World:getWallIdFromBlockId(block_id)
  return self.wall_id_by_block_id[block_id]
end

local month_length = {
  31, -- Jan
  28, -- Feb (29 in leap years, but TH doesn't have leap years)
  31, -- Mar
  30, -- Apr
  31, -- May
  30, -- Jun
  31, -- Jul
  31, -- Aug
  30, -- Sep
  31, -- Oct
  30, -- Nov
  31, -- Dec
}

function World:getDate()
  return self.month, self.day
end

function World:onTick()
  if self.tick_timer == 0 then
    self.tick_timer = self.tick_rate
    self.hour = self.hour + 1
    -- There doesn't need to be 24 hours in a day. Whatever value gives the
    -- best ingame speed can be used, but 24 works OK and is a good starting
    -- point. Vanilla TH appears to take ~3 seconds per day at normal speed.
    -- With ~33 ticks/sec, reduced to 11 /sec at normal speed, 3 seconds -> 33
    -- ticks, which is 1 day and 9 hours.
    if self.hour == 24 then
      self.hour = 0
      self.day = self.day + 1
      if self.day > month_length[self.month] then
        self:onEndMonth()
        self.day = 1
        self.month = self.month + 1
        if self.month > 12 then
          self:onEndYear();
          self.month = 1
        end
      end
    end
    for _, entity in ipairs(self.entities) do
      if entity.ticks then
        entity:tick()
      end
    end
    self.map:onTick()
  end
  self.tick_timer = self.tick_timer - 1
end

function World:onEndMonth()
end

function World:onEndYear()
end

function World:getPathDistance(x1, y1, x2, y2)
  return self.pathfinder:findDistance(x1, y1, x2, y2)
end

function World:getPath(x, y, dest_x, dest_y)
  return self.pathfinder:findPath(x, y, dest_x, dest_y)
end

function World:newEntity(class, animation)
  local th = TH.animation()
  th:setAnimation(self.anims, animation)
  local entity = _G[class](th)
  self.entities[#self.entities + 1] = entity
  entity.world = self
  return entity
end

function World:newObject(id, ...)
  local object_type = self.object_types[id]
  local entity
  if object_type.class then
    entity = _G[object_type.class](self, object_type, ...)
  else
    entity = Object(self, object_type, ...)
  end
  self.entities[#self.entities + 1] = entity
  return entity
end

function World:removeObjectFromTile(object, x, y)
  local index = y * self.map.width + x
  local objects = self.objects[index]
  if objects then
    for k, v in ipairs(objects) do
      if v == object then
        table_remove(objects, k)
        return true
      end
    end
  end
  return false
end

function World:addObjectToTile(object, x, y)
  local index = y * self.map.width + x
  local objects = self.objects[index]
  if objects then
    objects[#objects + 1] = object
  else
    objects = {object}
    self.objects[index] = objects
  end
  return true
end

function World:getObject(x, y, id)
  local index = y * self.map.width + x
  local objects = self.objects[index]
  if objects then
    if not id then
      return objects[1]
    else
      for _, obj in ipairs(objects) do
        if obj.object_type.id == id then
          return obj
        end
      end
    end
  end
  return -- nil
end
