--- Inventory Abstraction Library
-- Inventory Peripheral API compatible library that caches the contents of chests, and allows for very fast transfers of items between AbstractInventory objects.
-- Transfers can occur from slot to slot, or by item name and nbt data.
-- This can also transfer to / from normal inventories, just pass in the peripheral name.
-- Use {optimal=false} to transfer to / from non-inventory peripherals.

-- Now you can wrap arbratrary slot ranges
-- To do so, rather than passing in the inventory name when constructing (or adding/removing inventories)
-- you simply pass in a table of the following format
-- {name: string, minSlot: integer?, maxSlot: integer?, slots: integer[]?}
-- If slots is provided that overwrites anything in minSlot and maxSlot
-- minSlot defaults to 1, and maxSlot defaults to the inventory size

-- Transfers with this inventory are parallel safe iff
-- * assumeLimits = true
-- * The limits of the abstractInventorys involved have already been cached
--  * refreshStorage() will do this
-- * The transfer is to an abstractInventory, or to an un-optimized peripheral

-- Copyright 2022 Mason Gulu
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

local expect = require("cc.expect").expect

local abstractInventory

---@class Item This is pulled directly from list(), or from getItemDetail(), so it may have more fields
---@field name string Name of this item
---@field nbt string|nil
---@field count number

---@class TransferOptions
---@field optimal boolean|nil Try to optimize item movements, true default
---@field allowBadTransfers boolean|nil Recover from item transfers not going as planned (probably caused by someone tampering with the inventory)
---@field autoDeepRefresh boolean|nil Whether to do a deep refresh upon a bad transfer (requires bad transfers to be allowed)
---@field itemMovedCallback nil|fun(): nil Function called anytime an item is moved

---@class CachedItem
---@field item Item|nil If an item is in this slot, this field will be an Item
---@field inventory string Inventory peripheral name
---@field slot number Slot in inventory this CachedItem represents
---@field globalSlot number Global slot of this CachedItem, spans across all wrapped inventories
---@field capacity number

---Wrap inventories and create an abstractInventory
---@param inventories table<integer,string|{name: string, minSlot: integer?, maxSlot: integer?, slots: integer[]?}> Table of inventory peripheral names to wrap
---@param assumeLimits nil|boolean Default true, assume the limit of each slot is the same, saves a TON of time
---@return AbstractInventory
function abstractInventory(inventories, assumeLimits)
  expect(1, inventories, "table")
  expect(2, assumeLimits, "nil", "boolean")
  ---@class AbstractInventory
  local api = {}
  api.assumeLimits = assumeLimits

  if api.assumeLimits == nil then
    api.assumeLimits = true
  end

  ---@type table<string,table<string,CachedItem>>
  local itemNameNBTLUT = {}
  -- [item.name][nbt][CachedItem] -> CachedItem

  ---@type table<string,table<string,CachedItem>>
  local itemSpaceLUT = {}
  -- [item.name][nbt][CachedItem] -> CachedItem

  ---@type table<string,table<integer,CachedItem>>
  local inventorySlotLUT = {}
  -- [inventory][slot] = CachedItem

  ---@type table<string,integer>
  local inventoryLimit = {}
  -- [inventory] = number

  ---@type table<string,table<integer,boolean|nil>>
  local emptySlotLUT = {}
  -- [inventory][slot] = true|nil

  ---@type table<integer,{inventory:string, slot:integer}>
  local slotNumberLUT = {}
  -- [global slot] -> {inventory:string, slot:number}

  ---@type table<string,table<integer,integer>>
  local inventorySlotNumberLUT = {}
  -- [inventory][slot] -> global slot:number

  ---@type table<string,table<string,boolean>>
  local tagLUT = {}
  -- [tag] -> string[]

  ---@type table<string,table<string,table>>
  local deepItemLUT = {}
  -- [name][nbt] -> ItemInfo

  local executeLimit = 128 -- limit of functions to run in parallel

  ---Execute a table of functions in batches
  ---@param func function[]
  local function batchExecute(func)
    local batches = math.ceil(#func / executeLimit)
    for batch = 1, batches do
      local start = ((batch - 1) * executeLimit) + 1
      local batch_end = math.min(start + executeLimit - 1, #func)
      parallel.waitForAll(table.unpack(func, start, batch_end))
    end
  end

  local function ate(table, item) -- add to end
    table[#table + 1] = item
  end

  local function shallowClone(t)
    local ct = {}
    for k, v in pairs(t) do
      ct[k] = v
    end
    return ct
  end

  local function removeSlotFromEmptySlots(inventory, slot)
    emptySlotLUT[inventory] = emptySlotLUT[inventory] or {}
    emptySlotLUT[inventory][slot] = nil
    if not next(emptySlotLUT[inventory]) then
      emptySlotLUT[inventory] = nil
    end
  end

  ---Cache a given item, ensuring that whatever was in the slot beforehand is wiped properly
  ---And the caches are managed correctly.
  ---@param item table|nil
  ---@param inventory string
  ---@param slot number
  ---@return CachedItem
  local function cacheItem(item, inventory, slot)
    expect(1, item, "table", "nil")
    expect(2, inventory, "string")
    expect(3, slot, "number")
    local nbt = (item and item.nbt) or "NONE"
    if item and item.name == "" then
      item = nil
    end
    inventorySlotLUT[inventory] = inventorySlotLUT[inventory] or {}
    if inventorySlotLUT[inventory][slot] then
      local oldCache = inventorySlotLUT[inventory][slot]
      local oldItem = oldCache.item
      if oldItem and oldItem.name then
        -- There was an item in this slot before, clean up the caches
        local oldNBT = oldItem.nbt or "NONE"
        if itemNameNBTLUT[oldItem.name] and itemNameNBTLUT[oldItem.name][oldNBT] then
          itemNameNBTLUT[oldItem.name][oldNBT][oldCache] = nil
        end
        if itemSpaceLUT[oldItem.name] and itemSpaceLUT[oldItem.name][oldNBT] then
          itemSpaceLUT[oldItem.name][oldNBT][oldCache] = nil
        end
      end
    end
    removeSlotFromEmptySlots(inventory, slot)
    if not inventorySlotLUT[inventory][slot] then
      inventorySlotLUT[inventory][slot] = {
        item = item,
        inventory = inventory,
        slot = slot,
        globalSlot = inventorySlotNumberLUT[inventory][slot]
      }
    end
    if not inventorySlotLUT[inventory][slot].capacity then
      if api.assumeLimits and inventoryLimit[inventory] then
        inventorySlotLUT[inventory][slot].capacity = inventoryLimit[inventory]
      else
        inventorySlotLUT[inventory][slot].capacity = peripheral.call(inventory, "getItemLimit", slot)
      end
      inventoryLimit[inventory] = inventorySlotLUT[inventory][slot].capacity
    end
    ---@type CachedItem
    local cachedItem = inventorySlotLUT[inventory][slot]
    cachedItem.item = item
    if item and item.name then
      itemNameNBTLUT[item.name] = itemNameNBTLUT[item.name] or {}
      itemNameNBTLUT[item.name][nbt] = itemNameNBTLUT[item.name][nbt] or {}
      itemNameNBTLUT[item.name][nbt][cachedItem] = cachedItem
      if item.tags then
        for k, v in pairs(item.tags) do
          tagLUT[k] = tagLUT[k] or {}
          tagLUT[k][item.name] = true
        end
      end
      if emptySlotLUT[inventory] then
        -- There's an item in this slot, therefor this slot is not empty
        emptySlotLUT[inventory][slot] = nil
      end
      if item.count < (item.maxCount or cachedItem.capacity) then
        -- There's space left in this slot, add it to the cache
        itemSpaceLUT[item.name] = itemSpaceLUT[item.name] or {}
        itemSpaceLUT[item.name][nbt] = itemSpaceLUT[item.name][nbt] or {}
        itemSpaceLUT[item.name][nbt][cachedItem] = cachedItem
      end
    else
      -- There is no item in this slot, this slot is empty
      emptySlotLUT[inventory] = emptySlotLUT[inventory] or {}
      emptySlotLUT[inventory][slot] = true
    end
    return cachedItem
  end

  ---Cache what's in a given slot
  ---@param inventory string
  ---@param slot number
  ---@return CachedItem
  local function cacheSlot(inventory, slot)
    return cacheItem(peripheral.call(inventory, "getItemDetail", slot), inventory, slot)
  end

  ---Refresh a CachedItem
  ---@param item CachedItem
  local function refreshItem(item)
    cacheSlot(item.inventory, item.slot)
  end

  local function refreshInventory(inventory, deep)
    local deepCacheFunctions = {}
    local inventoryName, slots, minSlot, maxSlot
    if type(inventory) == "table" then
      inventoryName = inventory.name
      slots = inventory.slots
      minSlot = inventory.minSlot or 1
      maxSlot = inventory.maxSlot or
          assert(peripheral.call(inventoryName, "size"), ("%s is not a valid inventory."):format(inventoryName))
    else
      inventoryName = inventory
      minSlot = 1
      maxSlot = assert(peripheral.call(inventoryName, "size"), ("%s is not a valid inventory."):format(inventoryName))
    end
    if not slots then
      slots = {}
      for i = minSlot, maxSlot do
        slots[#slots + 1] = i
      end
    end
    emptySlotLUT[inventoryName] = {}
    for _, i in ipairs(slots) do
      emptySlotLUT[inventoryName][i] = true
      local slotnumber = #slotNumberLUT + 1
      slotNumberLUT[slotnumber] = { inventory = inventoryName, slot = i }
      inventorySlotNumberLUT[inventoryName] = inventorySlotNumberLUT[inventoryName] or {}
      inventorySlotNumberLUT[inventoryName][i] = slotnumber
    end
    inventoryLimit[inventoryName] = peripheral.call(inventoryName, "getItemLimit", 1) -- this should make transfers from/to this inventory parallel safe.
    local listings = peripheral.call(inventoryName, "list")
    if not deep then
      for _, i in ipairs(slots) do
        if listings[i] then
          cacheItem(listings[i], inventoryName, i)
        end
      end
    else
      for _, i in ipairs(slots) do
        local listing = listings[i]
        if listing then
          deepCacheFunctions[#deepCacheFunctions + 1] = function()
            deepItemLUT[listing.name] = deepItemLUT[listing.name] or {}
            if deepItemLUT[listing.name][listing.nbt or "NONE"] then
              local item = shallowClone(deepItemLUT[listing.name][listing.nbt or "NONE"])
              item.count = listing.count
              cacheItem(item, inventoryName, i)
            else
              local item = peripheral.call(inventoryName, "getItemDetail", i)
              cacheItem(item, inventoryName, i)
              deepItemLUT[item.name][item.nbt or "NONE"] = item
            end
          end
        end
      end
    end
    return deepCacheFunctions
  end

  ---Recache the inventory contents
  ---@param deep nil|boolean call getItemDetail on every slot
  function api.refreshStorage(deep)
    if type(deep) == "nil" then
      deep = true
    end
    itemNameNBTLUT, itemSpaceLUT, inventorySlotLUT, inventoryLimit, emptySlotLUT, slotNumberLUT, inventorySlotNumberLUT,
        tagLUT, deepItemLUT = {}, {}, {}, {}, {}, {}, {}, {}, {}
    local inventoryRefreshers = {}
    local deepCacheFunctions = {}
    for _, inventory in pairs(inventories) do
      table.insert(inventoryRefreshers, function()
        for k, v in ipairs(refreshInventory(inventory, deep) or {}) do
          deepCacheFunctions[#deepCacheFunctions + 1] = v
        end
      end)
    end
    batchExecute(inventoryRefreshers)
    batchExecute(deepCacheFunctions)
  end

  ---Get an inventory slot for a given item
  ---@param name string
  ---@param nbt nil|string
  ---@return nil|CachedItem
  local function getItem(name, nbt)
    nbt = nbt or "NONE"
    if not (itemNameNBTLUT[name] and itemNameNBTLUT[name][nbt]) then
      return
    end
    ---@type CachedItem
    local cached = next(itemNameNBTLUT[name][nbt])
    return cached
  end

  ---@return string|nil inventory
  ---@return integer|nil slot
  local function getEmptySlot()
    local inv = next(emptySlotLUT)
    if not inv then
      return
    end
    local slot = next(emptySlotLUT[inv])
    if not slot then
      emptySlotLUT[inv] = nil
      return getEmptySlot()
    end
    return inv, slot
  end

  ---Get an inventory slot that has space for a given item
  ---@param name string
  ---@param nbt nil|string
  ---@return nil|CachedItem
  local function getSlotWithSpace(name, nbt)
    nbt = nbt or "NONE"
    if not (itemSpaceLUT[name] and itemSpaceLUT[name][nbt]) then
      return
    end
    ---@type CachedItem
    local cached = next(itemSpaceLUT[name][nbt])
    return cached
  end

  ---@return integer|nil slot
  ---@return string|nil inventory
  ---@return integer capacity
  local function getEmptySpace()
    local inv, freeSlot = getEmptySlot()
    local space
    if inv and freeSlot and inventorySlotLUT[inv] and inventorySlotLUT[inv][freeSlot] then
      space = inventorySlotLUT[inv][freeSlot].capacity
    else
      space = 64 -- maybe???? might be a bad assumption
    end
    return freeSlot, inv, space
  end

  ---@param name string
  ---@param nbt string|nil
  ---@return CachedItem|nil
  function api._getSlotFor(name, nbt)
    return getSlotWithSpace(name, nbt)
  end

  ---@return integer|nil slot
  ---@return string|nil inventory
  ---@return integer capacity
  function api._getEmptySpace()
    return getEmptySpace()
  end

  ---@param item table|nil
  ---@param inventory string
  ---@param slot integer
  ---@return CachedItem
  function api._updateItem(item, inventory, slot)
    return cacheItem(item, inventory, slot)
  end

  ---@return CachedItem|nil
  function api._getItem(name, nbt)
    if not (itemNameNBTLUT[name] and itemNameNBTLUT[name][nbt]) then
      return
    end
    return next(itemNameNBTLUT[name][nbt])
  end

  ---@param slot integer
  ---@return CachedItem
  local function getGlobalSlot(slot)
    local slotInfo = slotNumberLUT[slot]
    inventorySlotLUT[slotInfo.inventory] = inventorySlotLUT[slotInfo.inventory] or {}
    if not inventorySlotLUT[slotInfo.inventory][slotInfo.slot] then
      cacheSlot(slotInfo.inventory, slotInfo.slot)
    end
    return inventorySlotLUT[slotInfo.inventory][slotInfo.slot]
  end

  ---@param slot integer
  ---@return CachedItem|nil
  function api._getGlobalSlot(slot)
    return getGlobalSlot(slot)
  end

  function api._getLookupSlot(slot)
    return slotNumberLUT[slot]
  end

  local defaultOptions = {
    optimal = true,
    allowBadTransfers = false,
    autoDeepRefresh = false,
    itemMovedCallback = nil,
  }

  local function pushItemsUnoptimal(targetInventory, name, amount, toSlot, nbt, options)
    -- This is to a normal inventory
    local totalMoved = 0
    local rep = true
    while totalMoved < amount and rep do
      local item
      if type(name) == "number" then
        -- perform lookup
        item = getGlobalSlot(name)
      else
        item = getItem(name, nbt)
      end
      if not item then
        return totalMoved -- no items to move
      end
      local itemCount = item.item.count
      rep = (itemCount - totalMoved) < amount
      local expectedMove = math.min(amount - totalMoved, 64)
      local remainingItems = math.max(0, itemCount - expectedMove)
      item.item.count = remainingItems
      if item.count == 0 then
        cacheItem(nil, item.inventory, item.slot)
      else
        cacheItem(item.item, item.inventory, item.slot)
      end
      local amountMoved = peripheral.call(item.inventory, "pushItems", targetInventory, item.slot, amount - totalMoved,
        toSlot)
      totalMoved = totalMoved + amountMoved
      refreshItem(item)
      if options.itemMovedCallback then
        options.itemMovedCallback()
      end
      if amountMoved < itemCount then
        return totalMoved -- target slot full
      end
    end
    return totalMoved
  end

  local function pushItemsOptimal(targetInventory, name, amount, toSlot, nbt, options)
    if type(targetInventory) == "string" then
      -- We'll see if this is a good optimization or not
      targetInventory = abstractInventory({ targetInventory })
      targetInventory.refreshStorage()
    end
    local theoreticalAmountMoved = 0
    local actualAmountMoved = 0
    local transferCache = {}
    local totalTime = 0
    local badTransfer
    while theoreticalAmountMoved < amount do
      local t0 = os.clock()
      -- find the cachedItem item in self
      ---@type CachedItem|nil
      local cachedItem
      if type(name) == "number" then
        cachedItem = getGlobalSlot(name)
        if not (cachedItem and cachedItem.item) then
          -- this slot is empty
          break
        end
      else
        cachedItem = getItem(name, nbt)
        if not (cachedItem and cachedItem.item) then
          -- no slots with this item
          break
        end
      end
      -- check how many items there are available to move
      local itemsToMove = cachedItem.item.count
      -- ask the other inventory for a slot with space
      local destinationInfo
      if toSlot then
        destinationInfo = targetInventory._getGlobalSlot(toSlot)
        if not destinationInfo then
          local info = targetInventory._getLookupSlot(toSlot)
          destinationInfo = cacheItem(nil, info.inventory, info.slot)
        end
      else
        destinationInfo = targetInventory._getSlotFor(cachedItem.item.name, nbt)
        if not destinationInfo then
          local slot, inventory, capacity = targetInventory._getEmptySpace()
          if not (slot and inventory) then
            break
          end
          destinationInfo = targetInventory._updateItem(nil, inventory, slot)
        end
      end
      -- determine the amount of items that should get moved
      local slotCapacity = cachedItem.item.maxCount or destinationInfo.capacity
      if destinationInfo.item then
        slotCapacity = slotCapacity - destinationInfo.item.count
      end
      itemsToMove = math.min(itemsToMove, slotCapacity, amount - theoreticalAmountMoved)
      if destinationInfo.item and (destinationInfo.item.name ~= cachedItem.item.name) then
        itemsToMove = 0
      end
      if itemsToMove == 0 then
        break
      end
      -- queue a transfer of that item
      local fromInv, toInv, fromSlot, limit, slot = cachedItem.inventory, destinationInfo.inventory, cachedItem.slot,
          itemsToMove, destinationInfo.slot
      if limit ~= 0 then
        ate(transferCache, function()
          local itemsMoved = peripheral.call(fromInv, "pushItems", toInv, fromSlot, limit, slot)
          if options.itemMovedCallback then
            options.itemMovedCallback()
          end
          actualAmountMoved = actualAmountMoved + itemsMoved
          if not options.allowBadTransfers then
            assert(itemsToMove == itemsMoved, ("Expected to move %u items, moved %u"):format(itemsToMove, itemsMoved))
          elseif not itemsToMove == itemsMoved then
            badTransfer = true
          end
        end)
      end
      -- update our cache of that item to include the predicted transfer
      local updatedItem = shallowClone(cachedItem.item)
      updatedItem.count = updatedItem.count - itemsToMove
      -- update the other inventory's cache to include the predicted transfer
      if not destinationInfo.item then
        destinationInfo.item = shallowClone(cachedItem.item)
        destinationInfo.item.count = 0
      end
      destinationInfo.item.count = destinationInfo.item.count + itemsToMove

      if updatedItem.count == 0 then
        cacheItem(nil, cachedItem.inventory, cachedItem.slot)
      else
        cacheItem(updatedItem, cachedItem.inventory, cachedItem.slot)
      end

      targetInventory._updateItem(destinationInfo.item, destinationInfo.inventory, destinationInfo.slot)

      --- Timing stuff
      local dt = os.clock() - t0
      totalTime = totalTime + dt
      theoreticalAmountMoved = theoreticalAmountMoved + itemsToMove
    end
    -- execute the inventory transfers
    -- return amount of items moved
    batchExecute(transferCache)
    if badTransfer then
      -- refresh inventories
      api.refreshStorage(options.autoDeepRefresh)
      targetInventory.refreshStorage(options.autoDeepRefresh)
    end
    return actualAmountMoved
  end

  --[[
  .########..##.....##..######..##.....##
  .##.....##.##.....##.##....##.##.....##
  .##.....##.##.....##.##.......##.....##
  .########..##.....##..######..#########
  .##........##.....##.......##.##.....##
  .##........##.....##.##....##.##.....##
  .##.........#######...######..##.....##
  ]]
  ---Push items to an inventory
  ---@param targetInventory string|AbstractInventory
  ---@param name string|number
  ---@param amount nil|number
  ---@param toSlot nil|number
  ---@param nbt nil|string
  ---@param options nil|TransferOptions
  ---@return integer count
  function api.pushItems(targetInventory, name, amount, toSlot, nbt, options)
    expect(1, targetInventory, "string", "table")
    expect(2, name, "string", "number")
    expect(3, amount, "nil", "number")
    expect(4, toSlot, "nil", "number")
    expect(5, nbt, "nil", "string")
    expect(6, options, "nil", "table")
    amount = amount or 64
    options = options or defaultOptions
    for k, v in pairs(defaultOptions) do
      if options[k] == nil then
        options[k] = v
      end
    end
    if type(targetInventory) == "string" then
      local test = peripheral.wrap(targetInventory)
      if not (test and test.size) then
        options.optimal = false
      end
    end
    if type(targetInventory) == "string" and not options.optimal then
      return pushItemsUnoptimal(targetInventory, name, amount, toSlot, nbt, options)
    else
      return pushItemsOptimal(targetInventory, name, amount, toSlot, nbt, options)
    end
    error("Invalid targetInventory")
  end

  --[[
  .########..##.....##.##.......##......
  .##.....##.##.....##.##.......##......
  .##.....##.##.....##.##.......##......
  .########..##.....##.##.......##......
  .##........##.....##.##.......##......
  .##........##.....##.##.......##......
  .##.........#######..########.########
  ]]
  ---Pull items from an inventory
  ---@param fromInventory string|AbstractInventory
  ---@param fromSlot string|number
  ---@param amount nil|number
  ---@param toSlot nil|number
  ---@param nbt nil|string
  ---@param options nil|TransferOptions
  ---@return integer count
  function api.pullItems(fromInventory, fromSlot, amount, toSlot, nbt, options)
    expect(1, fromInventory, "table", "string")
    expect(2, fromSlot, "number", "string")
    expect(3, amount, "nil", "number")
    expect(4, toSlot, "nil", "number")
    expect(5, nbt, "nil", "string")
    expect(6, options, "nil", "table")
    options = options or defaultOptions
    for k, v in pairs(defaultOptions) do
      if options[k] == nil then
        options[k] = v
      end
    end
    local rep, itemsPulled = false, 0
    amount = amount or 64
    nbt = nbt or "NONE"
    if type(fromInventory) == "string" then
      local test = peripheral.wrap(fromInventory)
      if not (test and test.size) then
        options.optimal = false
      end
    end
    if options.optimal == nil then options.optimal = true end
    if type(fromInventory) == "string" and not options.optimal then
      assert(type(fromSlot) == "number", "Must pull from a slot #")
      while itemsPulled < amount do
        local freeSlot, freeInventory, space
        freeSlot, freeInventory, space = getEmptySpace()
        if not (freeSlot and freeInventory) then
          return itemsPulled
        end
        local limit = math.min(amount - itemsPulled, space)
        cacheItem({ name = "UNKNOWN", count = math.huge }, freeInventory, freeSlot)
        local moved = peripheral.call(freeInventory, "pullItems", fromInventory, fromSlot, limit, freeSlot)
        cacheSlot(freeInventory, freeSlot)
        if options.itemMovedCallback then
          options.itemMovedCallback()
        end
        itemsPulled = itemsPulled + moved
        if moved < limit then
          -- there's no more items to pull
          return itemsPulled
        end
      end
      return itemsPulled
    else
      local theoreticalAmountMoved = 0
      local actualAmountMoved = 0
      local transferCache = {}
      local badTransfer
      while theoreticalAmountMoved < amount do
        if type(fromInventory) == "string" then
          fromInventory = abstractInventory({ fromInventory })
          fromInventory.refreshStorage()
        end
        -- find the cachedItem item in fromInventory
        ---@type CachedItem|nil
        local cachedItem
        if type(fromSlot) == "number" then
          cachedItem = fromInventory._getGlobalSlot(fromSlot)
          if not (cachedItem and cachedItem.item) then
            -- this slot is empty
            break
          end
        else
          cachedItem = fromInventory._getItem(fromSlot, nbt)
          if not (cachedItem and cachedItem.item) then
            -- no slots with this item
            break
          end
        end
        -- check how many items there are available to move
        local itemsToMove = cachedItem.item.count
        -- find where the item will be put
        local destinationInfo
        if toSlot then
          destinationInfo = getGlobalSlot(toSlot)
          if not destinationInfo then
            local info = slotNumberLUT[toSlot]
            destinationInfo = cacheItem(nil, info.inventory, info.slot)
          end
        else
          destinationInfo = getSlotWithSpace(cachedItem.item.name, nbt)
          if not destinationInfo then
            local slot, inventory, capacity = getEmptySpace()
            if not (slot and inventory) then
              break
            end
            destinationInfo = cacheItem(nil, inventory, slot)
          end
        end

        local slotCapacity = cachedItem.item.maxCount or destinationInfo.capacity or 64
        if destinationInfo.item then
          slotCapacity = slotCapacity - destinationInfo.item.count
        end
        itemsToMove = math.min(itemsToMove, slotCapacity, amount - theoreticalAmountMoved)
        if destinationInfo.item and (destinationInfo.item.name ~= cachedItem.item.name) then
          itemsToMove = 0
        end
        if itemsToMove == 0 then
          break
        end

        -- queue a transfer of that item
        local toInv, fromInv, fslot, limit, tslot = destinationInfo.inventory, cachedItem.inventory, cachedItem.slot,
            itemsToMove, destinationInfo.slot
        if limit ~= 0 then
          ate(transferCache, function()
            local itemsMoved = peripheral.call(toInv, "pullItems", fromInv, fslot, limit, tslot)
            if options.itemMovedCallback then
              options.itemMovedCallback()
            end
            actualAmountMoved = actualAmountMoved + itemsMoved
            if not options.allowBadTransfers then
              assert(itemsToMove == itemsMoved, ("Expected to move %u items, moved %u"):format(itemsToMove, itemsMoved))
            elseif not itemsToMove == itemsMoved then
              badTransfer = true
            end
          end)
        end
        theoreticalAmountMoved = theoreticalAmountMoved + itemsToMove

        -- update our cache to include the predicted transfer
        if not destinationInfo.item then
          destinationInfo.item = shallowClone(cachedItem.item)
          destinationInfo.item.count = 0
        end

        destinationInfo.item.count = destinationInfo.item.count + itemsToMove
        cacheItem(destinationInfo.item, destinationInfo.inventory, destinationInfo.slot)


        -- update the other inventory's cache of that item to include the predicted transfer
        local updatedItem = shallowClone(cachedItem.item)
        updatedItem.count = updatedItem.count - itemsToMove

        if updatedItem.count == 0 then
          fromInventory._updateItem(nil, cachedItem.inventory, cachedItem.slot)
        else
          fromInventory._updateItem(updatedItem, cachedItem.inventory, cachedItem.slot)
        end

      end

      batchExecute(transferCache)
      if badTransfer then
        -- refresh inventories
        api.refreshStorage(options.autoDeepRefresh)
        fromInventory.refreshStorage(options.autoDeepRefresh)
      end
      return actualAmountMoved
    end
    error("Invalid inventory")
  end

  ---Get the amount of this item in storage
  ---@param item string
  ---@param nbt nil|string
  ---@return integer
  function api.getCount(item, nbt)
    expect(1, item, "string")
    expect(2, nbt, "nil", "string")
    nbt = nbt or "NONE"
    if not (itemNameNBTLUT[item] and itemNameNBTLUT[item][nbt]) then
      return 0
    end
    local totalCount = 0
    for k, v in pairs(itemNameNBTLUT[item][nbt]) do
      totalCount = totalCount + v.item.count
    end
    return totalCount
  end

  ---Get a list of all items in this storage
  ---@return table list CachedItem[]
  function api.listItems()
    local t = {}
    for name, nbtt in pairs(itemNameNBTLUT) do
      for nbt, cachedItem in pairs(nbtt) do
        ate(t, cachedItem)
      end
    end
    return t
  end

  ---Get a list of all item names in this storage
  ---@return table
  function api.listNames()
    local t = {}
    for k, v in pairs(itemNameNBTLUT) do
      t[#t + 1] = k
    end
    return t
  end

  ---Get a list of all item NBT hashes in this storage
  ---@param name string
  ---@return table
  function api.listNBT(name)
    local t = {}
    for k, v in pairs(itemNameNBTLUT[name] or {}) do
      t[#t + 1] = k
    end
    return t
  end

  ---Rearrange items to make the most efficient use of space
  function api.defrag()
    local f = {}
    for _, name in pairs(api.listNames()) do
      local nbt = "NONE"
      table.insert(f, function()
        local optimal = false
        while not optimal do
          local item = getSlotWithSpace(name, nbt)
          if not item then
            optimal = true
            break
          end
          local count = item.item.count
          cacheItem(nil, item.inventory, item.slot)
          while count > 0 do
            local toItem = getSlotWithSpace(name, nbt)
            if toItem then
              local toMove = math.min(count, (toItem.item.maxCount or toItem.capacity) - toItem.item.count)
              toItem.item.count = toItem.item.count + toMove
              cacheItem(toItem, toItem.inventory, toItem.slot)
              peripheral.call(item.inventory, "pushItems", toItem.inventory, item.slot, toMove, toItem.slot)
              refreshItem(item)
              refreshItem(toItem)
              count = count - toMove
            else
              optimal = true
              break
            end
          end
        end
      end)
    end
    batchExecute(f)
    api.refreshStorage(true) -- this messes with the cache in some way I currently cannot figure out.
  end

  ---Get a CachedItem by name/nbt
  ---@param name string
  ---@param nbt nil|string
  ---@return CachedItem|nil
  function api.getItem(name, nbt)
    expect(1, name, "string")
    expect(2, nbt, "nil", "string")
    return getItem(name, nbt) -- this can be nil
  end

  ---Get a CachedItem by slot
  ---@param slot integer
  ---@return CachedItem
  function api.getSlot(slot)
    expect(1, slot, "number")
    return getGlobalSlot(slot)
  end

  ---Change the max number of functions to run in parallel
  ---@param n integer
  function api.setBatchLimit(n)
    expect(1, n, "number")
    assert(n > 0, "Attempt to set negative/0 batch limit.")
    if n < 10 then
      print(string.format("Warning, setting a very low batch limit (%u), abstractInvLib will be very slow."):format(n))
    end
    if n > 250 then
      error(string.format("Attempt to set batch limit to %u, the event queue is 256 elements long. This is very likely to result in dropped events."
        , n), 2)
    end
    if n > 150 then
      print(string.format("Warning, the event queue is 256 elements long and the batch limit is %u. It is possible that you may have dropped events"
        , n))
    end
    executeLimit = n
  end

  ---Get an inventory peripheral compatible list of items in this storage
  ---@return table
  function api.list()
    local t = {}
    for itemName, nbtTable in pairs(itemNameNBTLUT) do
      for nbt, cachedItems in pairs(nbtTable) do
        for item, _ in pairs(cachedItems) do
          t[inventorySlotNumberLUT[item.inventory][item.slot]] = item.item
        end
      end
    end
    return t
  end

  ---Get a list of item name indexed counts of each item
  ---@return table
  function api.listItemAmounts()
    local t = {}
    for _, itemName in ipairs(api.listNames()) do
      t[itemName] = 0
      for _, nbt in ipairs(api.listNBT(itemName)) do
        t[itemName] = t[itemName] + api.getCount(itemName, nbt)
      end
    end
    return t
  end

  ---Get a list of items with the given tag
  ---@return string[]
  function api.getTag(tag)
    local t = {}
    for k, v in pairs(tagLUT[tag] or {}) do
      table.insert(t, k)
    end
    return t
  end

  ---Get the slot usage of this inventory
  ---@return {free: integer, used:integer, total:integer}
  function api.getUsage()
    local ret = {}
    ret.total = api.size()
    ret.used = 0
    for i, _ in pairs(api.list()) do
      ret.used = ret.used + 1
    end
    ret.free = ret.total - ret.used
    return ret
  end

  ---Get the amount of slots in this inventory
  ---@return integer
  function api.size()
    return #slotNumberLUT
  end

  ---Get item information from a slot
  ---@param slot integer
  ---@return Item
  function api.getItemDetail(slot)
    expect(1, slot, "number")
    local item = getGlobalSlot(slot)
    if item.item == nil then
      refreshItem(item)
    end
    return item.item
  end

  ---Get maximum number of items that can be in a slot
  ---@param slot integer
  ---@return integer
  function api.getItemLimit(slot)
    expect(1, slot, "number")
    local item = getGlobalSlot(slot)
    return item.limit
  end

  ---pull all items from an inventory
  ---@param inventory string|AbstractInventory
  ---@return integer moved total items moved
  function api.pullAll(inventory)
    if type(inventory) == "string" then
      inventory = abstractInventory({ inventory })
      inventory.refreshStorage()
    end
    local moved = 0
    for k, _ in pairs(inventory.list()) do
      moved = moved + api.pullItems(inventory, k)
    end
    return moved
  end

  local function getItemIndex(t, item)
    for k, v in ipairs(t) do
      if v == item then
        return k
      end
    end
  end

  ---Add an inventory to the storage object
  ---@param inventory string
  ---@return boolean success
  function api.addInventory(inventory)
    expect(1, inventory, "table")
    if getItemIndex(inventories, inventory) then
      return false
    end
    table.insert(inventories, inventory)
    api.refreshStorage(true)
    return true
  end

  ---Remove an inventory from the storage object
  ---@param inventory string
  ---@return boolean success
  function api.removeInventory(inventory)
    expect(1, inventory, "string")
    local index = getItemIndex(inventories, inventory)
    if not index then
      return false
    end
    table.remove(inventories, index)
    api.refreshStorage(true)
    return true
  end

  ---Get the number of free slots in this inventory
  ---@return integer
  function api.freeSpace()
    local count = 0
    for _, inventorySlots in pairs(emptySlotLUT) do
      for _, _ in pairs(inventorySlots) do
        count = count + 1
      end
    end
    return count
  end

  ---Get the number of items of this type you could store in this inventory
  ---@param name string
  ---@param nbt string|nil
  ---@return integer count
  function api.totalSpaceForItem(name, nbt)
    expect(1, name, "string")
    expect(2, nbt, "string", "nil")
    local count = 0
    for inventory, inventorySlots in pairs(emptySlotLUT) do
      for _, _ in pairs(inventorySlots) do
        count = count + (inventoryLimit[inventory] or 64)
      end
    end
    nbt = nbt or "NONE"
    if itemSpaceLUT[name] and itemSpaceLUT[name][nbt] then
      for _, cached in pairs(itemSpaceLUT[name][nbt]) do
        count = count + (cached.capacity - cached.item.count)
      end
    end
    return count
  end

  api.refreshStorage(true)

  return api
end

return abstractInventory
