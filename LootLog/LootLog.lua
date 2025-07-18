-- LootLog Ace3 Full Rewrite: Оригинальный функционал, но на Ace3 и self.db.profile
local ADDON_NAME, _ = ...

-- Простая функция для выполнения с задержкой (аналог C_Timer.After)
local function RunAfter(delay, func)
    local f = CreateFrame("Frame")
    local elapsed = 0
    f:SetScript("OnUpdate", function(self, e)
        elapsed = elapsed + e
        if elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            func()
            f = nil
        end
    end)
end

-- Проверка библиотек
if not LibStub then
    print("LootLog: ОШИБКА - LibStub не найден!")
    return
end

local LootLog = LibStub("AceAddon-3.0"):NewAddon("LootLog", "AceConsole-3.0", "AceEvent-3.0")
if not LootLog then
    print("LootLog: ОШИБКА - Не удалось создать аддон!")
    return
end

_G["LootLog"] = LootLog

local defaults = {
    profile = {
        loot_index = 0,
        filter_index = 0,
        looted_items = {},
        filter_list = {}, -- Структура: {item_id = {who = true}} для скрытия предметов по получателю
        min_quality = 0,
        source = 0,
        invertsorting = true,
        equippable = false,
        open_on_loot = false,
        sort_mode = "date",
        GENERAL = {
            WHO_FILTER = "all"
        }
    }
}

local item_cache = ItemCache and ItemCache.new() or nil
local loot_frame, settings_frame

-- Миграция структуры лога (map -> массив)
local function migrate_looted_items(S)
    if not S then return end
    if S.looted_items and not S.looted_items[1] then
        local new_list = {}
        for item_id, info in pairs(S.looted_items) do
            if type(info) == "table" and info.amount then
                table.insert(new_list, {
                    item_id = tonumber(item_id),
                    amount = info.amount,
                    source = info.source,
                    who = info.who,
                    date = info.date or date("*t"),
                    zone = info.zone
                })
            end
        end
        S.looted_items = new_list
    end
end

-- Миграция filter_list в новую структуру
local function migrate_filter_list(S)
    if not S then return end
    if S.filter_list then
        local new_filter_list = {}
        for item_id, value in pairs(S.filter_list) do
            if type(value) == "table" and value.who then
                -- Уже новая структура: {item_id = {who = true}}
                new_filter_list[item_id] = value
            elseif type(value) == "boolean" and value then
                -- Старая структура: {item_id = true} - конвертируем в новую
                local playerName = UnitName("player")
                new_filter_list[item_id] = {[playerName] = true}
            elseif type(value) == "table" then
                -- Старая сложная структура - конвертируем в новую
                local playerName = UnitName("player")
                new_filter_list[item_id] = {[playerName] = true}
            end
        end
        S.filter_list = new_filter_list
    end
end

function LootLog:OnInitialize()
    -- Проверка AceDB
    if not LibStub("AceDB-3.0") then
        print("LootLog: ОШИБКА - AceDB-3.0 не найден!")
        return
    end
    
    self.db = LibStub("AceDB-3.0"):New("LootLogDB", defaults, true)
    
    -- Защита от ошибок при миграции
    local success, err = pcall(function()
        migrate_looted_items(self.db.profile)
        migrate_filter_list(self.db.profile)
    end)
    if not success then
        print("LootLog: Ошибка при миграции данных:", err)
    end
    
    -- Регистрация команд
    self:RegisterChatCommand("lootlog", "SlashHandler")
    self:RegisterChatCommand("ll", "SlashHandler")
end

function LootLog:OnEnable()
    self:CreateFrames()
    self:RegisterEvent("CHAT_MSG_LOOT", "OnLooted")
    self:RegisterEvent("CHAT_MSG_RAID", "OnGargul")
end

function LootLog:SlashHandler()
    if loot_frame then
        loot_frame:Show()
    else
        self:CreateFrames()
        loot_frame:Show()
    end
end

-- Парсер текста для itemID, количества и получателя
function LootLog:ParseItemFromText(text)
    local _, item_id_start = string.find(text, "|Hitem:")
    if not item_id_start then return nil, nil, nil end
    local text_after_item = string.sub(text, item_id_start + 1)
    local item_id_end = string.find(text_after_item, ":")
    if not item_id_end then return nil, nil, nil end
    local item_id_str = string.sub(text_after_item, 1, item_id_end - 1)
    local item_id = tonumber(item_id_str)
    if not item_id then return nil, nil, nil end
    local amount = 1
    local count_match = string.match(text, "x(%d+)")
    if count_match then
        amount = tonumber(count_match)
    end
    -- Определяем получателя
    local who = nil
    local playerName = UnitName("player")
    if string.find(text, "Ваша добыча") or string.find(text, "Ваша доля добычи") or string.find(text, "You receive loot") or string.find(text, "You won") then
        who = playerName
    else
        -- Поддержка спецсимволов, дефисов, пробелов
        local other = string.match(text, "([%wА-Яа-яёЁ%-_ ]+) получает добычу")
        if other then
            who = strtrim(other)
        else
            -- Если не можем определить получателя, не обрабатываем сообщение
            return nil, nil, nil
        end
    end
    return item_id, amount, who
end

-- Функция добавления лута (с учётом фильтр-листа)
function LootLog:AddLootedItem(item_id, amount, source, who)
    local S = self.db.profile
    S.looted_items = S.looted_items or {}
    S.filter_list = S.filter_list or {}
    
    -- Проверяем, что все параметры корректны
    if not item_id or not who then
        return
    end
    
    -- Ищем существующую запись для этого предмета и получателя
    local existing_entry = nil
    for _, entry in ipairs(S.looted_items) do
        if entry.item_id == item_id and entry.who == who and entry.source == source then
            existing_entry = entry
            break
        end
    end
    
    if existing_entry then
        -- Обновляем существующую запись
        local old_amount = existing_entry.amount or 0
        existing_entry.amount = old_amount + amount
        existing_entry.date = date("*t") -- Обновляем дату последнего получения
        existing_entry.zone = GetRealZoneText()
    else
        -- Создаем новую запись
        local new_entry = {
            item_id = item_id,
            amount = amount,
            source = source,
            who = who,
            date = date("*t"),
            zone = GetRealZoneText()
        }
        table.insert(S.looted_items, new_entry)
    end
    
    self:UpdateList()
end

-- Фильтрация по игнор-листу
function LootLog:ShouldIgnoreLootMessage(text)
    if not LootLog_Exclusions then return false end
    local locale = GetLocale() or "enUS"
    local keywords = LootLog_Exclusions.roll_keywords[locale] or {}
    for _, word in ipairs(keywords) do
        if string.find(string.lower(text), string.lower(word), 1, true) then
            return true
        end
    end
    -- Паттерны применяем только если в сообщении есть имя игрока (обычно для roll/результатов бросков)
    local playerName = UnitName("player")
    if playerName and string.find(text, playerName) then
        for _, pattern in ipairs(LootLog_Exclusions.roll_patterns or {}) do
            if string.match(text, pattern) then
                return true
            end
        end
    end
    return false
end

function LootLog:OnLooted(event, ...)
    local text = ...
    if self:ShouldIgnoreLootMessage(text) then return end
    local item_id, amount, who = self:ParseItemFromText(text)
    if item_id and amount and who then
        self:AddLootedItem(item_id, amount, "loot", who)
        end
    end

function LootLog:OnGargul(event, ...)
    local text = ...
    if self:ShouldIgnoreLootMessage(text) then return end
    local item_id, amount, who = self:ParseItemFromText(text)
    if item_id and amount then
        self:AddLootedItem(item_id, amount, "gargul", who)
    end
end

-- РАСШИРЕННАЯ СОРТИРОВКА
local sort_modes = {"date", "amount", "name"}
function LootLog:get_sort_mode()
    if not self or not self.db then
        return "date"
    end
    local S = self.db.profile or {}
    return S.sort_mode or "date"
end

function LootLog:set_sort_mode(mode)
    if not self or not self.db then
        return
    end
    local S = self.db.profile or {}
    S.sort_mode = mode
    if self.UpdateList then
        self:UpdateList()
    end
end

-- Добавляю фильтр по получателю (моя/чужая/всё)
local who_filter_modes = {"all", "mine", "others"}
function LootLog:get_who_filter()
    if not self or not self.db then
        return "all"
    end
    local S = self.db.profile or {}
    return (S.GENERAL and S.GENERAL.WHO_FILTER) or "all"
end

function LootLog:set_who_filter(mode)
    if not self or not self.db then
        return
    end
    local S = self.db.profile or {}
    S.GENERAL = S.GENERAL or {}
    S.GENERAL.WHO_FILTER = mode
    if self.UpdateList then
        self:UpdateList()
    end
end

-- Формирование строки для отображения предмета с ником получателя
local function formatLootDisplay(item, info, playerName)
    local who_display = (info.who == playerName) and "("..(LootLog_Locale and (LootLog_Locale.me or "Вы") or "Вы")..")" or (info.who or "?")
    return (item.link or item.name) .. " x" .. (info.amount or 1) .. " " .. who_display
end

-- Основная функция обновления списка предметов
function LootLog:UpdateList()
    -- Проверяем, что аддон инициализирован
    if not self or not self.db then
        return
    end
    
    local S = self.db.profile
    if not S then
        return
    end
    
    if not loot_frame or not loot_frame.field then 
        return 
    end
    
    local items = {}
    local min_quality = S.min_quality or 0
    local source_filter = S.source or 0
    local invert_sort = S.invertsorting or true
    local equippable = S.equippable or false
    local filter_list = S.filter_list or {}
    local search = searchBox and searchBox:GetText() or ""
    local who_filter = self:get_who_filter()
    local playerName = UnitName("player")
    
    -- Основной список: только не скрытые предметы
    for _, info in ipairs(S.looted_items or {}) do
        if type(info) == "table" and info.item_id then
            -- Проверяем, скрыт ли этот предмет для данного получателя
            local is_hidden = false
            if filter_list[info.item_id] and filter_list[info.item_id][info.who] then
                is_hidden = true
            end
            
            if not is_hidden then
                local item = item_cache and item_cache:get(info.item_id)
            if item then
                if item.quality >= min_quality then
                    if source_filter == 0 or (source_filter == 1 and info.source == "loot") or (source_filter == 2 and info.source == "gargul") then
                        if not equippable or (item.link and IsEquippableItem(item.link)) then
                                if who_filter == "all" or (who_filter == "mine" and info.who == playerName) or (who_filter == "others" and info.who ~= playerName) then
                            if search == "" or (item.name and string.find(string.lower(item.name), string.lower(search), 1, true)) then
                                        -- Создаем копию item для этого элемента
                                        local display_item = {
                                            id = item.id,
                                            item_id = item.id or item.item_id or info.item_id,
                                            name = item.name,
                                            link = item.link,
                                            quality = item.quality,
                                            classID = item.classID,
                                            amount = info.amount or 1,
                                            display_name = formatLootDisplay(item, info, playerName),
                                            entry_info = info -- Сохраняем информацию о записи
                                        }
                                        
                                        table.insert(items, display_item)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Сортировка только если есть элементы
    if #items > 0 then
        local mode = self:get_sort_mode()
    if mode == "amount" then
            table.sort(items, function(a, b) 
                local amount_a = tonumber(a.amount) or 0
                local amount_b = tonumber(b.amount) or 0
                return amount_a > amount_b 
            end)
    elseif mode == "name" then
            table.sort(items, function(a, b) 
                local name_a = tostring(a.name or "")
                local name_b = tostring(b.name or "")
                return name_a < name_b 
            end)
    else -- date
        table.sort(items, function(a, b)
                -- Конвертируем даты в числа для сравнения
                local date_a = 0
                local date_b = 0
                
                -- Безопасная обработка даты для элемента A
                if a and a.entry_info and a.entry_info.date then
                    if type(a.entry_info.date) == "table" then
                        -- Если дата в формате таблицы, конвертируем в простой timestamp
                        local date_table = a.entry_info.date
                        date_a = (tonumber(date_table.year) or 0) * 100000000 + 
                                 (tonumber(date_table.month) or 0) * 1000000 + 
                                 (tonumber(date_table.day) or 0) * 10000 + 
                                 (tonumber(date_table.hour) or 0) * 100 + 
                                 (tonumber(date_table.min) or 0)
                    else
                        date_a = tonumber(a.entry_info.date) or 0
                    end
                end
                
                -- Безопасная обработка даты для элемента B
                if b and b.entry_info and b.entry_info.date then
                    if type(b.entry_info.date) == "table" then
                        -- Если дата в формате таблицы, конвертируем в простой timestamp
                        local date_table = b.entry_info.date
                        date_b = (tonumber(date_table.year) or 0) * 100000000 + 
                                 (tonumber(date_table.month) or 0) * 1000000 + 
                                 (tonumber(date_table.day) or 0) * 10000 + 
                                 (tonumber(date_table.hour) or 0) * 100 + 
                                 (tonumber(date_table.min) or 0)
                    else
                        date_b = tonumber(b.entry_info.date) or 0
                    end
                end
                
                return date_a > date_b
            end)
        end
    end
    
    loot_frame.field:SetItems(items)
    if loot_frame.count_text then
        loot_frame.count_text:SetText("Всего предметов: " .. #items)
    end
    
    -- Обновляем TSM данные
    _G.LootLogTSMData = {}
    for _, item in ipairs(items) do
        if item.item_id and item.amount then
            _G.LootLogTSMData[item.item_id] = (_G.LootLogTSMData[item.item_id] or 0) + item.amount
        end
    end
    
    -- Обновляем фильтр-лист в окне настроек, если оно открыто
    if _G.settings_frame and _G.settings_frame.Refresh then 
        _G.settings_frame.Refresh() 
    end
end

-- Настройки вынесены в отдельный файл Settings.lua

-- Модифицируем кнопку настроек
function LootLog:CreateFrames()
    local S = self.db.profile
    local width, height = 250, 400
    local num_visible = 10 -- увеличено для скролла
    local row_height = 22

    if loot_frame then loot_frame:Hide() end
    loot_frame = CreateFrame("Frame", "LootLogMainFrame", UIParent)
    loot_frame:SetSize(300, 400)
    -- Исправление: сдвигаем окно влево от центра
    loot_frame:SetPoint("CENTER", UIParent, "CENTER", -220, 0)
    loot_frame:SetMovable(true)
    loot_frame:EnableMouse(true)
    loot_frame:RegisterForDrag("LeftButton")
    loot_frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    loot_frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    loot_frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 12, insets = {left=2,right=2,top=2,bottom=2}})
    loot_frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    loot_frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Заголовок
    loot_frame.title_text = loot_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    loot_frame.title_text:SetPoint("TOPLEFT", 10, -10)
    loot_frame.title_text:SetText(LootLog_Locale and (LootLog_Locale.title or "Журнал Добычи") or "Loot Log")

    -- Кнопка закрытия
    loot_frame.close_btn = CreateFrame("Button", nil, loot_frame, "UIPanelCloseButton")
    loot_frame.close_btn:SetPoint("TOPRIGHT", -5, -5)
    loot_frame.close_btn:SetScript("OnClick", function() loot_frame:Hide() end)

    -- Счётчик
    loot_frame.count_text = loot_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    loot_frame.count_text:SetPoint("TOPLEFT", loot_frame.title_text, "BOTTOMLEFT", 0, -10)
    loot_frame.count_text:SetText("Всего предметов: 0")

    -- Кнопка очистки
    loot_frame.clear_btn = CreateFrame("Button", nil, loot_frame, "UIPanelButtonTemplate")
    loot_frame.clear_btn:SetSize(100, 22)
    loot_frame.clear_btn:SetPoint("BOTTOMLEFT", 10, 10)
    loot_frame.clear_btn:SetText(LootLog_Locale and (LootLog_Locale.clear or "Очистить") or "Clear")
    loot_frame.clear_btn:SetScript("OnClick", function() LootLog:ShowClearConfirm() end)

    -- Кнопка настроек (заглушка)
    loot_frame.settings_btn = CreateFrame("Button", nil, loot_frame, "UIPanelButtonTemplate")
    loot_frame.settings_btn:SetSize(100, 22)
    loot_frame.settings_btn:SetPoint("BOTTOMRIGHT", -10, 10)
    loot_frame.settings_btn:SetText(LootLog_Locale and (LootLog_Locale.settings or "Настройки") or "Settings")
    loot_frame.settings_btn:SetScript("OnClick", function()
        LootLog:CreateSettingsFrame()
    end)

    -- Список предметов (ItemFrame)
    if loot_frame.field then loot_frame.field:Hide() end
    loot_frame.field = CreateItemFrame and CreateItemFrame("LootLogItemFrame", loot_frame, num_visible, width-20, function(btn, item)
        local item_id = item and (item.item_id or item.id)
        local entry_info = item and item.entry_info
        self:OnClickItem(btn, item_id, entry_info)
    end)
    if loot_frame.field then
        loot_frame.field:SetPoint("TOPLEFT", 10, -50)
        loot_frame.field:SetPoint("RIGHT", -10, 0)
        loot_frame.field:SetHeight(num_visible * row_height)
    end
    self:UpdateList()

    -- Строка поиска
    searchBox = CreateFrame("EditBox", nil, loot_frame, "InputBoxTemplate")
    searchBox:SetSize(120, 20)
    searchBox:SetPoint("TOPRIGHT", -10, -10)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        LootLog:UpdateList()
    end)
    searchBox:Show()
end

-- Обработка кликов по предмету
-- Новая логика: filter_list — {item_id = {who = true}} для скрытия предметов по получателю
local orig_OnClickItem = LootLog.OnClickItem
function LootLog:OnClickItem(mouse_key, item_id, entry_info)
    if not self or not self.db then
        return
    end
    
    local S = self.db.profile
    if not S then
        return
    end
    
    -- Используем entry_info.item_id как fallback, если item_id не передан
    if not item_id and entry_info and entry_info.item_id then
        item_id = entry_info.item_id
    end
    
    if not item_id then 
        return 
    end
    
    if mouse_key == "LeftButton" then
        -- Левый клик: вставляем ссылку в чат или показываем информацию о добыче
        if IsShiftKeyDown() then
            -- Shift + левый клик: вставляем ссылку в чат
            local item = item_cache and item_cache:get(item_id)
            if item and item.link then
                if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                    ChatFrameEditBox:Insert(item.link)
                else
                    ChatEdit_InsertLink(item.link)
                end
            end
        else
            -- Обычный левый клик: показываем информацию о времени и месте добычи
            local info_text = self:FormatLootInfo(item_id, entry_info)
            print(info_text)
        end
        return
    elseif mouse_key == "RightButton" then
        local who = nil
        
        -- Если передана информация о записи, используем её
        if entry_info and entry_info.who then
            who = entry_info.who
        else
            -- Иначе ищем информацию о предмете в логе (для обратной совместимости)
            for _, info in ipairs(S.looted_items or {}) do
                if info.item_id == item_id then
                    who = info.who
                    break
                end
            end
        end
        
        if who then
            if not S.filter_list[item_id] then
                S.filter_list[item_id] = {}
            end
            
            if S.filter_list[item_id][who] then
                -- Показываем добычу этого игрока
                S.filter_list[item_id][who] = nil
                
                -- Если больше нет скрытых получателей для этого предмета, удаляем запись
                local has_hidden = false
                for _, is_hidden in pairs(S.filter_list[item_id]) do
                    if is_hidden then
                        has_hidden = true
                        break
                    end
                end
                if not has_hidden then
                    S.filter_list[item_id] = nil
                end
                
                local item = item_cache and item_cache:get(item_id)
                if item and item.link then
                    print("Показана добыча " .. who .. ": " .. item.link)
                end
            else
                -- Скрываем добычу этого игрока
                S.filter_list[item_id][who] = true
                
                local item = item_cache and item_cache:get(item_id)
                if item and item.link then
                    print("Скрыта добыча " .. who .. ": " .. item.link)
                end
            end
            
        self:UpdateList()
            if _G.settings_frame and _G.settings_frame.Refresh then 
                _G.settings_frame.Refresh() 
            end
        else
            -- Не удалось определить получателя
        end
        return
    end
    if orig_OnClickItem then
        orig_OnClickItem(self, mouse_key, item_id)
    end
end

-- Подтверждение перед очисткой журнала
function LootLog:ShowClearConfirm()
    if not StaticPopupDialogs["LOOTLOG_CLEAR_CONFIRM"] then
        StaticPopupDialogs["LOOTLOG_CLEAR_CONFIRM"] = {
            text = LootLog_Locale and (LootLog_Locale.clear_confirm or "Очистить журнал добычи? Это действие нельзя отменить!"),
            button1 = OKAY,
            button2 = CANCEL,
            OnAccept = function()
                wipe(self.db.profile.looted_items)
                wipe(self.db.profile.filter_list)
                self:UpdateList()
                if _G.settings_frame and _G.settings_frame.Refresh then 
                    _G.settings_frame.Refresh() 
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    StaticPopup_Show("LOOTLOG_CLEAR_CONFIRM")
end

-- UI: скрытие/показ окон (уже реализовано через Show/Hide, проверяю наличие)
-- Очередь обновлений (если потребуется): можно добавить throttle, но для WoW 3.3.5a обычно не требуется, оставляю как есть.

-- TSM Integration: Hook TSM's LoadTooltip function
local function HookTSMIntegration()
    local function HookLibExtraTip()
        local hooked = false

        -- Try to find LibExtraTip library
        local libExtraTip = LibStub and LibStub("LibExtraTip-1", true)
        if libExtraTip then
            -- Hook the callback system
            if not _G.LootLogOriginalLibExtraTipCallbacks then
                _G.LootLogOriginalLibExtraTipCallbacks = {}

                -- Find TSM's callback in the library
                if libExtraTip.sortedCallbacks then
                    for i, callback in ipairs(libExtraTip.sortedCallbacks) do
                        if callback.type == "item" and callback.callback then
                            -- This might be TSM's callback
                            local originalCallback = callback.callback
                            callback.callback = function(tip, item, quantity, name, link, quality, ilvl)
                                -- Check if we should override the quantity
                                if IsShiftKeyDown() and _G.LootLogCurrentItemID and _G.LootLogTSMData then
                                    local itemID = tonumber(string.match(link or "", "item:(%d+)")) or tonumber(item)
                                    if itemID and itemID == _G.LootLogCurrentItemID then
                                        local lootLogQuantity = _G.LootLogTSMData[_G.LootLogCurrentItemID]
                                        if lootLogQuantity and lootLogQuantity > 1 then
                                            quantity = lootLogQuantity
                                        end
                                    end
                                end
                                return originalCallback(tip, item, quantity, name, link, quality, ilvl)
                            end
                            hooked = true
                        end
                    end
                end
            end
        end

        return hooked
    end

    local function HookTSMItemCounting()
        local hooked = HookLibExtraTip()

        if not hooked then
            -- Retry if LibExtraTip hook failed
            RunAfter(2.0, HookTSMItemCounting)
        end
    end

    HookTSMItemCounting()
end

-- Initialize TSM integration after addon loads
RunAfter(5.0, HookTSMIntegration)

-- Форматирование информации о времени и месте добычи
function LootLog:FormatLootInfo(item_id, entry_info)
    if not self or not self.db then
        return "Ошибка: аддон не инициализирован"
    end
    
    local S = self.db.profile
    if not S then
        return "Ошибка: профиль не найден"
    end
    
    -- Ищем информацию о предмете
    local loot_info = nil
    if entry_info then
        loot_info = entry_info
    else
        -- Ищем в логе по item_id
        for _, info in ipairs(S.looted_items or {}) do
            if info.item_id == item_id then
                loot_info = info
                break
            end
        end
    end
    
    if not loot_info then
        return "Информация о добыче не найдена"
    end
    
    -- Получаем информацию о предмете
    local item = item_cache and item_cache:get(item_id)
    local item_name = item and (item.link or item.name) or ("Предмет #" .. item_id)
    
    -- Форматируем дату
    local date_str = "Неизвестно"
    if loot_info.date then
        local date = loot_info.date
        local function pad(value, num)
            if value == nil then
                return string.rep("0", num)
            end
            local str = tostring(value)
            return string.rep("0", num - string.len(str)) .. str
        end
        
        date_str = pad(date.day, 2) .. "." .. pad(date.month, 2) .. "." .. (date.year or 1970) .. " " ..
                   pad(date.hour, 2) .. ":" .. pad(date.min, 2)
    end
    
    -- Форматируем зону
    local zone_str = loot_info.zone or "Неизвестная зона"
    
    -- Форматируем получателя
    local who_str = ""
    if loot_info.who then
        local playerName = UnitName("player")
        if loot_info.who == playerName then
            who_str = " (Получил: Вы)"
        else
            who_str = " (Получил: " .. loot_info.who .. ")"
        end
    end
    
    -- Форматируем источник
    local source_str = ""
    if loot_info.source then
        if loot_info.source == "loot" then
            source_str = " (Источник: обычная добыча"
        elseif loot_info.source == "gargul" then
            source_str = " (Источник: Gargul"
        else
            source_str = " (Источник: " .. loot_info.source
        end
        
        if loot_info.amount and loot_info.amount > 1 then
            source_str = source_str .. "; Количество: " .. loot_info.amount
        end
        
        source_str = source_str .. ")"
    end
    
    return item_name .. ": " .. zone_str .. ", " .. date_str .. who_str .. source_str
end
