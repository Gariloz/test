-- Settings.lua - Окно настроек LootLog
-- Отдельный модуль для управления настройками аддона

local settings_frame
local item_cache = ItemCache and ItemCache.new() or nil

-- Делаем settings_frame глобальной для доступа из LootLog.lua
_G.settings_frame = settings_frame

-- Создание окна настроек
function LootLog:CreateSettingsFrame()
    -- Проверяем, что LootLog существует
    if not LootLog or not LootLog.db then
        print("LootLog: Ошибка - аддон не инициализирован")
        return
    end
    
    if settings_frame then 
        settings_frame:Show() 
        return 
    end
    
    local S = self.db.profile
    settings_frame = CreateFrame("Frame", "LootLogSettingsFrame", UIParent)
    _G.settings_frame = settings_frame
    settings_frame:SetSize(300, 500)
    settings_frame:SetPoint("CENTER", 150, 0)
    settings_frame:SetMovable(true)
    settings_frame:EnableMouse(true)
    settings_frame:RegisterForDrag("LeftButton")
    settings_frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    settings_frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    settings_frame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
        edgeSize = 12, 
        insets = {left=2,right=2,top=2,bottom=2}
    })
    settings_frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
    settings_frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Заголовок
    local title = settings_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(LootLog_Locale and (LootLog_Locale.title or "Журнал Добычи") or "Loot Log")

    -- Кнопка закрытия
    local close_btn = CreateFrame("Button", nil, settings_frame, "UIPanelCloseButton")
    close_btn:SetPoint("TOPRIGHT", -5, -5)
    close_btn:SetScript("OnClick", function() settings_frame:Hide() end)

    local y = -40
    
    -- Функция добавления label
    local function AddLabel(text)
        local label = settings_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", 20, y)
        label:SetText(text)
        y = y - 24
        return label
    end
    
    -- Функция добавления dropdown
    local function AddDropdown(text, value_key, values)
        AddLabel(text)
        local dd = CreateFrame("Frame", "LootLogDropDown_"..value_key, settings_frame, "UIDropDownMenuTemplate")
        dd:SetPoint("TOPLEFT", 20, y)
        UIDropDownMenu_SetWidth(dd, 180)
        UIDropDownMenu_Initialize(dd, function(self, level)
            for i, v in ipairs(values) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = v
                info.func = function()
                    if value_key == "who_filter" then
                        local key = (i == 1 and "all" or i == 2 and "mine" or "others")
                        LootLog:set_who_filter(key)
                        UIDropDownMenu_SetText(dd, v)
                    else
                        S[value_key] = i - 1
                        UIDropDownMenu_SetText(dd, v)
                        LootLog:UpdateList()
                    end
                end
                if value_key == "who_filter" then
                    local current = LootLog:get_who_filter()
                    info.checked = current == ((i == 1 and "all") or (i == 2 and "mine") or "others")
                else
                    info.checked = (S[value_key] == i - 1)
                end
                UIDropDownMenu_AddButton(info)
            end
        end)
        if value_key == "who_filter" then
            local current = LootLog:get_who_filter()
            local idx = (current == "all" and 1) or (current == "mine" and 2) or 3
            UIDropDownMenu_SetText(dd, values[idx])
        else
            UIDropDownMenu_SetText(dd, values[(S[value_key] or 0) + 1])
        end
        y = y - 38
        return dd
    end
    
    -- Функция добавления чекбокса
    local function AddCheck(text, value_key)
        local cb = CreateFrame("CheckButton", nil, settings_frame, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y)
        cb:SetChecked(S[value_key])
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        cb.text:SetText(text)
        cb:SetScript("OnClick", function(self)
            S[value_key] = self:GetChecked() and true or false
            LootLog:UpdateList()
        end)
        y = y - 28
        return cb
    end

    -- Фильтр по качеству
    AddDropdown(LootLog_Locale and (LootLog_Locale.min_quality or "Мин. качество"), "min_quality", 
                LootLog_Locale and LootLog_Locale.qualities or {"Хлам", "Обычное", "Необычное", "Редкое", "Эпическое", "Легендарное"})
    
    -- Фильтр по источнику
    AddDropdown(LootLog_Locale and (LootLog_Locale.source or "Источник"), "source", 
                LootLog_Locale and LootLog_Locale.sources or {"Все", "Лут", "Gargul"})
    
    -- Фильтр по получателю (синхронизация с AceDB)
    AddDropdown(LootLog_Locale and (LootLog_Locale.who_filter or "Показывать добычу"), "who_filter", 
                LootLog_Locale and LootLog_Locale.who_filter_modes or {"Всех", "Мою", "Чужую"})

    -- Сортировка
    local sortDrop = CreateFrame("Frame", "LootLogSortDropDown", settings_frame, "UIDropDownMenuTemplate")
    sortDrop:SetPoint("TOPLEFT", 20, y)
    UIDropDownMenu_SetWidth(sortDrop, 180)
    UIDropDownMenu_Initialize(sortDrop, function(self, level)
        local sort_modes = {"date", "amount", "name"}
        for i, mode in ipairs(sort_modes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = (mode=="date" and "По дате" or mode=="amount" and "По количеству" or "По имени")
            info.func = function()
                LootLog:set_sort_mode(mode)
                UIDropDownMenu_SetText(sortDrop, info.text)
            end
            info.checked = (S.sort_mode or "date") == mode
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetText(sortDrop, "Сортировка: "..((S.sort_mode or "date")=="date" and "По дате") or ((S.sort_mode or "date")=="amount" and "По количеству") or "По имени")
    y = y - 38

    -- Чекбоксы
    AddCheck("Новые сверху", "invertsorting")
    AddCheck("Только экипировка", "equippable")
    AddCheck("Открывать при добыче", "open_on_loot")

    -- Поле для добавления предметов по ID (перемещено на место удаленного чекбокса)
    AddLabel("Добавить предмет по ID:")
    local itemIDBox = CreateFrame("EditBox", nil, settings_frame, "InputBoxTemplate")
    itemIDBox:SetSize(100, 20)
    itemIDBox:SetPoint("TOPLEFT", 20, y)
    itemIDBox:SetAutoFocus(false)
    itemIDBox:SetNumeric(true)
    itemIDBox:SetScript("OnEnterPressed", function(self)
        local item_id = tonumber(self:GetText())
        if item_id then
            -- Добавляем в фильтр-лист для текущего игрока
            local playerName = UnitName("player")
            if not S.filter_list[item_id] then
                S.filter_list[item_id] = {}
            end
            S.filter_list[item_id][playerName] = true
            RefreshFilterList()
            LootLog:UpdateList()
        end
        self:SetText("")
        self:ClearFocus()
    end)
    itemIDBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)

    -- Кнопка очистки фильтр-листа
    local clearFilterBtn = CreateFrame("Button", nil, settings_frame, "UIPanelButtonTemplate")
    clearFilterBtn:SetSize(80, 22)
    clearFilterBtn:SetPoint("TOPLEFT", itemIDBox, "TOPRIGHT", 10, 0)
    clearFilterBtn:SetText("Очистить")
    clearFilterBtn:SetScript("OnClick", function()
        wipe(S.filter_list)
        RefreshFilterList()
        LootLog:UpdateList()
    end)
    y = y - 38

    -- Фильтр-лист
    y = y - 10
    AddLabel("Фильтр-лист (скрытые предметы)")
    local filterListFrame = CreateFrame("Frame", nil, settings_frame)
    filterListFrame:SetPoint("TOPLEFT", 20, y)
    filterListFrame:SetSize(240, 220)
    filterListFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background", 
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
        edgeSize = 8, 
        insets = {left=2,right=2,top=2,bottom=2}
    })
    filterListFrame:SetBackdropColor(0.08, 0.08, 0.08, 0.8)
    filterListFrame:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    y = y - 230

    -- Функция обновления фильтр-листа (объявляем до использования)
    local function RefreshFilterList()
        local items = {}
        local who_filter = LootLog:get_who_filter()
        local playerName = UnitName("player")
        
        for itemID, hidden_who in pairs(S.filter_list or {}) do
            if type(hidden_who) == "table" then
                -- Новая структура: {item_id = {who = true}}
                for who, is_hidden in pairs(hidden_who) do
                    if is_hidden then
                        -- Проверяем фильтр по получателю
                        local should_show = false
                        if who_filter == "all" then
                            should_show = true
                        elseif who_filter == "mine" and who == playerName then
                            should_show = true
                        elseif who_filter == "others" and who ~= playerName then
                            should_show = true
                        end
                        
                        if should_show then
                            -- Находим количество для этого игрока
                            local amount = 0
                            local full_entry = nil
                            for _, entry in ipairs(S.looted_items or {}) do
                                if entry.item_id == tonumber(itemID) and entry.who == who then
                                    amount = entry.amount or 0
                                    full_entry = entry
                                    break
                                end
                            end
                            
                            if amount > 0 then
                                local item = item_cache and item_cache:get(itemID)
                                if item then
                                    local display_item = {
                                        id = item.id,
                                        item_id = item.id,
                                        name = item.name,
                                        link = item.link,
                                        quality = item.quality,
                                        amount = amount,
                                        display_name = (item.link or item.name) .. " x" .. amount .. " " .. ((who == playerName) and "("..(LootLog_Locale and (LootLog_Locale.me or "Вы") or "Вы")..")" or who),
                                        entry_info = full_entry -- Передаем полную информацию о записи
                                    }
                                    table.insert(items, display_item)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        -- Сортируем по имени
        table.sort(items, function(a, b) 
            return (a.name or "") < (b.name or "") 
        end)
        
        if filterListFrame.field then
            filterListFrame.field:SetItems(items)
        end
    end

    -- Создаем ItemFrame для фильтр-листа
    filterListFrame.field = CreateItemFrame and CreateItemFrame("LootLogFilterFrame", filterListFrame, 8, 220, function(btn, item)
        local item_id = item and (item.item_id or item.id)
        local entry_info = item and item.entry_info
        
        if btn == "LeftButton" then
            -- Левый клик: вставляем ссылку в чат или показываем информацию о добыче
            if IsShiftKeyDown() then
                -- Shift + левый клик: вставляем ссылку в чат
                local item_obj = item_cache and item_cache:get(item_id)
                if item_obj and item_obj.link then
                    if ChatFrameEditBox and ChatFrameEditBox:IsVisible() then
                        ChatFrameEditBox:Insert(item_obj.link)
                    else
                        ChatEdit_InsertLink(item_obj.link)
                    end
                end
            else
                -- Обычный левый клик: показываем информацию о времени и месте добычи
                local info_text = LootLog:FormatLootInfo(item_id, entry_info)
                print(info_text)
            end
        elseif btn == "RightButton" then
            -- Правый клик: удаляем из фильтр-листа
            if item_id and entry_info and entry_info.who then
                if S.filter_list[item_id] then
                    S.filter_list[item_id][entry_info.who] = nil
                    -- Если больше нет скрытых получателей, удаляем запись
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
                end
                RefreshFilterList()
                LootLog:UpdateList()
            end
        end
    end)
    
    if filterListFrame.field then
        filterListFrame.field:SetPoint("TOPLEFT", 5, -5)
        filterListFrame.field:SetPoint("RIGHT", -5, 0)
        filterListFrame.field:SetHeight(8 * 22)
    end

    -- Добавляем функцию Refresh в settings_frame
    settings_frame.Refresh = RefreshFilterList

    -- Инициализируем фильтр-лист
    RefreshFilterList()
end

-- Регистрируем функцию в глобальном объекте LootLog (если он существует)
if _G.LootLog then
    _G.LootLog.CreateSettingsFrame = LootLog.CreateSettingsFrame
end 