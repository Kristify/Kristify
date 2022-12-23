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
---@return table|false
function utils.getProduct(products, metaname)
  for _, product in ipairs(products) do
    if product.metaname == metaname then
      return product
    end
  end

  return false
end

return utils
