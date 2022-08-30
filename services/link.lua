-- Link service

local function onPurchase(params, kristify)
  kristify.popup(params.link, 10)
  return true
end

local function getStock(params)
  return " ∞ "
end