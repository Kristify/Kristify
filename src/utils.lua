local utils = {}

function utils.endsWith(str, ending)
  return ending == "" or str:sub(- #ending) == ending
end

function utils.getProduct(products, metaname)
  for _, product in ipairs(products) do
    if product.metaname == metaname then
      return product
    end
  end

  return false
end

return utils
