local utils = {}

---Checks if `str` ends with `ending`
---This is a simple utility function so we don't have a lot of repetitive code
---@param str string
---@param ending string
---@return boolean
function utils.endsWith(str, ending)
  return ending == "" or str:sub(- #ending) == ending
end

---Checks if `products` include a certain name
---@param products table
---@param metaname string
---@return boolean
function utils.productsIncludes(products, metaname)
  for _, product in ipairs(products) do
    if product.metaname == metaname then
      return true
    end
  end

  return false
end

---Gets a product by name
---@param products table
---@param metaname string
---@return table|boolean
function utils.getProduct(products, metaname)
  for _, product in ipairs(products) do
    if product.metaname == metaname then
      return product
    end
  end

  return false
end

---Returns a set of keys for a table
---@param table table The table to inspect
---@return table keyset A table containing keys for the original table
function utils.keyset(table)
  local keyset = {}
  local n = 0

  for k, v in pairs(table) do
    n = n + 1
    keyset[n] = k
  end

  return keyset
end

---Parses commenmeta
---@param meta string The meta to parse
---@return table meta A table with metadata
---@source k.lua
function utils.parseCommonmeta(meta)
  local domainMatch = "^([%l%d-_]*)@?([%l%d-]+).kst$"
  local commonMetaMatch = "^(.+)=(.+)$"

  local tbl = { meta = {} }

  for m in meta:gmatch("[^;]+") do
    if m:match(domainMatch) then
      -- print("Matched domain")

      local p1, p2 = m:match("([%l%d-_]*)@"), m:match("@?([%l%d-]+).kst")
      tbl.name = p1
      tbl.domain = p2

    elseif m:match(commonMetaMatch) then
      -- print("Matched common meta")

      local p1, p2 = m:match(commonMetaMatch)

      tbl.meta[p1] = p2

    else
      -- print("Unmatched standard meta")

      table.insert(tbl.meta, m)
    end
    -- print(m)
  end
  -- print(textutils.serialize(tbl))
  return tbl
end

---Checks if the tabe contains the value
---@param tbl table The table to check if includes value
---@param wanted string The string to check if the table includes
function utils.tableIncludes(tbl, wanted)
  for _, value in ipairs(tbl) do
    if value == wanted then
      return true
    end
  end

  return false
end

---Checks if a value is "nullish" or basically nil.
---@param value variable The value to check
function utils.isNullish(value)
  return value == nil or value == 0 or value == ""
end

return utils
