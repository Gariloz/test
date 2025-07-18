-- --------------------------------------------------------------------------------
-- Create a frame designed for showing items in a scrollable list.
-- Compatible with WoW 3.3.5a
-- Parameters:
--   name               Global name of the frame
--   parent             Parent frame object for placement within other frames
--   num_item_frames    Number of items that can be simultaneously shown
--   frame_width        Width of the frame in pixel (minimum: 100)
--   click_callback     Callback function for clicks on items: <func>(button, item)
-- Returns the created frame that is derived from Frame
-- --------------------------------------------------------------------------------
local function CreateItemFrame(name, parent, num_item_frames, frame_width, click_callback, opts)
    opts = opts or {}
    local item_height = opts.item_height or 20
    local font = opts.font or "GameFontNormal"
    local font_size = opts.font_size or 12
    local icon_size = opts.icon_size or 16

    local tooltipButtons = setmetatable({}, {__mode = "k"})
    local modifierWatcher = CreateFrame("Frame")
    modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifierWatcher:SetScript("OnEvent", function(_, event, key)
        if event == "MODIFIER_STATE_CHANGED" and (key == "LSHIFT" or key == "RSHIFT") then
            for btn in pairs(tooltipButtons) do
                if btn:IsMouseOver() and GameTooltip:IsOwned(btn) then
                    btn:GetScript("OnEnter")(btn)
                end
            end
        end
    end)

    local ItemFrame = CreateFrame("Frame", name, parent)
    ItemFrame.num_item_frames = num_item_frames
    ItemFrame.frame_width = math.max(100, frame_width)
    ItemFrame.item_height = item_height
    ItemFrame.click_callback = click_callback
    ItemFrame.background = {}
    ItemFrame.item_lines = {}
    ItemFrame.items = {}
    ItemFrame.scroll_pos = 1

    local function initialize()
        for i = 1, num_item_frames do
            local bg = ItemFrame:CreateTexture()
            bg:SetTexture(0.2, 0.2, 0.2, 0.5)
            ItemFrame.background[i] = bg
        end
        for i = 1, num_item_frames do
            local line = CreateFrame("Button", name .. "Item" .. i, ItemFrame)
            line:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            line:SetScript("OnClick", function(self, button, ...) 
                -- print("ItemFrame: Клик по элементу - button:", button, "item_id:", self.item_id)
                -- if self.item_data then
                --     print("ItemFrame: item_data.item_id:", self.item_data.item_id, "item_data.entry_info:", self.item_data.entry_info and "есть" or "нет")
                -- end
                if ItemFrame.click_callback then
                    ItemFrame.click_callback(button, self.item_data)
                else
                    -- print("ItemFrame: ОШИБКА - click_callback не установлен")
                end
            end)
            line.icon = line:CreateTexture(nil, "ARTWORK")
            line.icon:SetPoint("LEFT", 2, 0)
            line.icon:SetSize(icon_size, icon_size)
            line.text = line:CreateFontString(nil, "OVERLAY", font)
            line.text:SetPoint("LEFT", line.icon, "RIGHT", 4, 0)
            line.text:SetPoint("RIGHT", -5, 0)
            line.text:SetJustifyH("LEFT")
            line.text:SetWordWrap(false)
            line.text:SetFont(font, font_size)
            line:SetScript("OnEnter", function(self)
                if not self.item_id then return end
                tooltipButtons[self] = true
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                
                local count = self.item_data and self.item_data.amount or 1
                local link = "item:" .. self.item_id .. ":0:0:0"
                
                -- TSM Integration: Set current item ID for money formatting hooks
                if IsShiftKeyDown() then
                    _G.LootLogCurrentItemID = self.item_id
                    -- Set TSM data for quantity override
                    if not _G.LootLogTSMData then _G.LootLogTSMData = {} end
                    _G.LootLogTSMData[self.item_id] = count
                end
                
                -- Show tooltip with proper quantity for TSM integration
                if IsShiftKeyDown() then
                    -- Always pass the count when Shift is held, regardless of amount
                    if GameTooltip.SetItemByID then
                        GameTooltip:SetItemByID(self.item_id, count)
                    else
                        GameTooltip:SetHyperlink(link, count)
                    end
                else
                    GameTooltip:SetHyperlink(link)
                end
                
                GameTooltip:Show()
            end)
            line:SetScript("OnLeave", function(self)
                tooltipButtons[self] = nil
                _G.LootLogCurrentItemID = nil
                _G.LootLogTSMData = nil
                GameTooltip:Hide()
            end)
            line:SetHeight(item_height)
            ItemFrame.item_lines[i] = line
        end
        -- Исправление: задаём явные размеры и слой ScrollFrame
        local ScrollFrame = CreateFrame("ScrollFrame", name .. "ScrollFrame", ItemFrame, "FauxScrollFrameTemplate")
        ScrollFrame:SetPoint("TOPLEFT", ItemFrame, "TOPLEFT", 0, 0)
        ScrollFrame:SetPoint("BOTTOMRIGHT", ItemFrame, "BOTTOMRIGHT", -20, 0)
        ScrollFrame:SetFrameLevel(ItemFrame:GetFrameLevel() + 10)
        ScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, ItemFrame.item_height, function() ItemFrame:UpdateView() end)
        end)
        ItemFrame.ScrollFrame = ScrollFrame
    end

    function ItemFrame:ApplyStyle(opts)
        opts = opts or {}
        local item_height = opts.item_height or self.item_height or 20
        local font = opts.font or "GameFontNormal"
        local font_size = opts.font_size or 12
        local icon_size = opts.icon_size or 16
        for _, line in ipairs(self.item_lines or {}) do
            if line then
                line:SetHeight(item_height)
                if line.text then line.text:SetFont(font, font_size) end
                if line.icon then line.icon:SetSize(icon_size, icon_size) end
            end
        end
        self.item_height = item_height
        self:UpdateView()
    end

    -- Формирует текст для строки предмета
    local function setItemLineText(line, item)
        local count = item.amount or 1
        if item.display_name then
            line.text:SetText(item.display_name)
        else
            local who_display = item.who and (item.who == UnitName("player") and "("..(LootLog_Locale and (LootLog_Locale.me or "?") or "?")..")" or item.who) or ""
            if count > 1 then
                line.text:SetText((item.link or item.name) .. " x" .. count .. " " .. who_display)
            else
                line.text:SetText((item.link or item.name) .. " " .. who_display)
            end
        end
    end

    function ItemFrame:UpdateView()
        local items = self.items
        local num_total = #items
        local num_items = self.num_item_frames
        local item_height = self.item_height
        local frame_width = self.frame_width
        local frame_height = num_items * item_height
        self:SetWidth(frame_width)
        self:SetHeight(frame_height)
        local ScrollFrame = self.ScrollFrame
        ScrollFrame:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
        ScrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -20, 0)
        ScrollFrame:SetFrameLevel(self:GetFrameLevel() + 10)
        FauxScrollFrame_Update(ScrollFrame, num_total, num_items, item_height)
        local scroll_offset = FauxScrollFrame_GetOffset(ScrollFrame)
        for line_index = 1, num_items do
            local item_index = line_index + scroll_offset
            local line = self.item_lines[line_index]
            local background = self.background[line_index]
            if item_index <= num_total then
                local item = items[item_index]
                if not item then 
                    line:Hide()
                    line.icon:Hide()
                    background:Hide()
                else
                background:ClearAllPoints()
                background:SetPoint("TOPLEFT", 0, -(line_index - 1) * item_height)
                background:SetPoint("BOTTOMRIGHT", ScrollFrame, "TOPRIGHT", 0, -line_index * item_height)
                background:Show()
                line:SetPoint("TOPLEFT", background)
                line:SetPoint("BOTTOMRIGHT", background)
                line:Show()
                line.item_id = item.id or item.item_id
                line.item_data = item -- Сохраняем полные данные о предмете
                if item.link then
                    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(item.id or item.item_id)
                    if texture then
                        line.icon:SetTexture(texture)
                        line.icon:Show()
                    else
                        line.icon:Hide()
                    end
                    setItemLineText(line, item)
                    line:Show()
                end
                end
            else
                line:Hide()
                line.icon:Hide()
                background:Hide()
            end
        end
        FauxScrollFrame_Update(ScrollFrame, num_total, num_items, item_height)
    end

    function ItemFrame:SetItems(items)
        self.items = items
        self:UpdateView()
    end
    function ItemFrame:GetFrameSize()
        return self.frame_width, self.num_item_frames * self.item_height
    end
    function ItemFrame:GetNumItems()
        return #self.items
    end
    initialize()
    return ItemFrame
end
_G["CreateItemFrame"] = CreateItemFrame
