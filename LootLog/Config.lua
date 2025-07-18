-- Config.lua - Конфигурация для AceConfig
-- Упрощенная версия конфигурации

-- Получает настройки профиля
local function get_settings()
    return LootLog.db and LootLog.db.profile or {}
end

-- Геттер для настроек
local function get(info)
    local S = get_settings()
    local group = info[2]
    local key = info[#info]
    
    if group == "GENERAL" then 
        return S.GENERAL and S.GENERAL[key] 
    end
    
    return S[key]
end

-- Сеттер для настроек
local function set(info, ...)
    local S = get_settings()
    local group = info[2]
    local key = info[#info]
    
    if group == "GENERAL" then 
        S.GENERAL = S.GENERAL or {}
        S.GENERAL[key] = ...
    else
        S[key] = ...
    end
    
    -- Мгновенно применяем изменения к интерфейсу
    if LootLog.UpdateList then LootLog:UpdateList() end
end

local options = {
    type = "group",
    name = LootLog_Locale.title or "LootLog",
    childGroups = "tab",
    args = {
        GENERAL = {
            order = 1, type = "group", name = LootLog_Locale.settings or "General",
            args = {
                SOURCE = { 
                    order = 1, type = "select", 
                    name = LootLog_Locale.source, 
                    values = LootLog_Locale.sources, 
                    get = get, set = set 
                },
                MIN_QUALITY = { 
                    order = 2, type = "select", 
                    name = LootLog_Locale.min_quality, 
                    desc = LootLog_Locale.min_quality_desc, 
                    values = LootLog_Locale.qualities, 
                    get = get, set = set 
                },
                WHO_FILTER = {
                    order = 3, type = "select",
                    name = LootLog_Locale.who_filter,
                    desc = LootLog_Locale.who_filter,
                    values = function()
                        return { 
                            all = LootLog_Locale.who_filter_modes[1], 
                            mine = LootLog_Locale.who_filter_modes[2], 
                            others = LootLog_Locale.who_filter_modes[3] 
                        }
                    end,
                    get = function(info)
                        local S = get_settings()
                        return (S.GENERAL and S.GENERAL.WHO_FILTER) or "all"
                    end,
                    set = function(info, val)
                        local S = get_settings()
                        S.GENERAL = S.GENERAL or {}
                        S.GENERAL.WHO_FILTER = val
                        if LootLog.UpdateList then LootLog:UpdateList() end
                    end,
                },
                INVERT_SORTING = { 
                    order = 4, type = "toggle", 
                    name = LootLog_Locale.invertsorting, 
                    desc = LootLog_Locale.invertsorting_desc, 
                    get = get, set = set 
                },
                EQUIPPABLE = { 
                    order = 5, type = "toggle", 
                    name = LootLog_Locale.equippable, 
                    desc = LootLog_Locale.equippable_desc, 
                    get = get, set = set 
                },
                OPEN_ON_LOOT = { 
                    order = 6, type = "toggle", 
                    name = LootLog_Locale.auto_open, 
                    desc = LootLog_Locale.auto_open_desc, 
                    get = get, set = set 
                },
            }
        },
    }
}

-- Регистрируем опции
if LibStub and LibStub("AceConfig-3.0") then
    LibStub("AceConfig-3.0"):RegisterOptionsTable("LootLog", options)
    
    if LibStub("AceConfigDialog-3.0") then
        LibStub("AceConfigDialog-3.0"):AddToBlizOptions("LootLog", "LootLog")
    end
end 