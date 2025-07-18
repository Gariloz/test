-- ItemCache.lua
-- Класс для кэширования информации о предметах

local ItemCache = {}
ItemCache.__index = ItemCache

-- Создаёт новый кэш предметов
function ItemCache.new()
    local self = setmetatable({}, ItemCache)
    self.items = {}
    self.loading = {}
    self.callbacks = {}
    return self
end

-- Получает предмет по item_id, кэширует результат
function ItemCache:get(item_id)
    if not item_id then return nil end
    if self.items[item_id] then
        return self.items[item_id]
    end
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(item_id)
    if name then
        local item = {
            id = item_id,
            name = name,
            link = link,
            quality = quality,
            iLevel = iLevel,
            reqLevel = reqLevel,
            class = class,
            subclass = subclass,
            maxStack = maxStack,
            equipSlot = equipSlot,
            texture = texture,
            classID = class -- Добавляем classID для совместимости
        }
        self.items[item_id] = item
        return item
    end
    return nil
end

-- Асинхронная загрузка предмета
function ItemCache:getAsync(item_id, callback)
    if not item_id then 
        if callback then callback() end
        return 
    end
    
    -- Если уже загружен, возвращаем сразу
    if self.items[item_id] then
        if callback then callback() end
        return
    end
    
    -- Если уже загружается, добавляем callback в очередь
    if self.loading[item_id] then
        if callback then
            self.callbacks[item_id] = self.callbacks[item_id] or {}
            table.insert(self.callbacks[item_id], callback)
        end
        return
    end
    
    -- Начинаем загрузку
    self.loading[item_id] = true
    if callback then
        self.callbacks[item_id] = {callback}
    end
    
    -- Пытаемся загрузить предмет
    local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(item_id)
    if name then
        -- Предмет загружен успешно
        local item = {
            id = item_id,
            name = name,
            link = link,
            quality = quality,
            iLevel = iLevel,
            reqLevel = reqLevel,
            class = class,
            subclass = subclass,
            maxStack = maxStack,
            equipSlot = equipSlot,
            texture = texture,
            classID = class
        }
        self.items[item_id] = item
        self.loading[item_id] = nil
        
        -- Вызываем все callbacks
        if self.callbacks[item_id] then
            for _, cb in ipairs(self.callbacks[item_id]) do
                cb()
            end
            self.callbacks[item_id] = nil
        end
    else
        -- Предмет не загружен, попробуем позже
        local attempts = 0
        local max_attempts = 10
        local function tryLoad()
            attempts = attempts + 1
            local name, link, quality, iLevel, reqLevel, class, subclass, maxStack, equipSlot, texture = GetItemInfo(item_id)
            if name then
                local item = {
                    id = item_id,
                    name = name,
                    link = link,
                    quality = quality,
                    iLevel = iLevel,
                    reqLevel = reqLevel,
                    class = class,
                    subclass = subclass,
                    maxStack = maxStack,
                    equipSlot = equipSlot,
                    texture = texture,
                    classID = class
                }
                self.items[item_id] = item
                self.loading[item_id] = nil
                
                -- Вызываем все callbacks
                if self.callbacks[item_id] then
                    for _, cb in ipairs(self.callbacks[item_id]) do
                        cb()
                    end
                    self.callbacks[item_id] = nil
                end
            elseif attempts < max_attempts then
                -- Пробуем еще раз через 0.5 секунды
                C_Timer.After(0.5, tryLoad)
            else
                -- Превышено количество попыток
                self.loading[item_id] = nil
                if self.callbacks[item_id] then
                    for _, cb in ipairs(self.callbacks[item_id]) do
                        cb()
                    end
                    self.callbacks[item_id] = nil
                end
            end
        end
        C_Timer.After(0.1, tryLoad)
    end
end

-- Проверяет, загружены ли все предметы
function ItemCache:loaded()
    return not next(self.loading)
end

-- Очищает кэш
function ItemCache:clear()
    wipe(self.items)
    wipe(self.loading)
    wipe(self.callbacks)
end

-- Экспортируем класс глобально
_G["ItemCache"] = ItemCache
