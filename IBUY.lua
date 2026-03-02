--[[
IBUY - Auto-buy helper for vendor windows.

Purpose:
- Automatically buy one or more configured vendor items while a merchant window is open.
- Prefer items by configured priority order.
- Offer a test mode with 2 real purchases, then log-only "would buy".

Inputs / Outputs:
- Input: Merchant item list, configured item IDs, UI toggles, slash commands.
- Output: BuyMerchantItem calls, chat log messages, UI status text.

Invariants:
- Existing addons are untouched; IBUY only runs in its own namespace and files.
- Auto-loop only runs while MerchantFrame is open.
- Auto-buy stops immediately when the merchant window closes.

How to debug:
- Use /ibuy debug on
- Open a vendor and watch chat logs with prefix [IBUY].
- Use /ibuy list to verify configured item IDs and priority.
]]

local ADDON_NAME = ...
local IBUY = {}
_G.IBUY = IBUY
local VIDEO_URL = "https://www.youtube.com/watch?v=cEU4pawG93Q"
local DEFAULT_FINISH_MESSAGE = "Wenn jemand wisschen moechte wie ich heile, hier das Video: " .. VIDEO_URL
local HEFTIG_SOUND_PATH = "Interface\\AddOns\\IBUY\\sounds\\heftig.ogg"

local DEFAULTS = {
    enabled = false,
    testMode = true,
    testModeRealBuys = 2,
    onlyShowTargets = false,
    autoRefresh = true,
    refreshSeconds = 2.0,
    scanInterval = 0.35,
    debug = false,
    persistDebugLog = false,
    debugLogMaxEntries = 2000,
    instanceFinishMessageEnabled = true,
    instanceFinishMessage = DEFAULT_FINISH_MESSAGE,
    watchOrder = { 16224 },
}

local STATE = {
    merchantOpen = false,
    loopTicker = nil,
    refreshTicker = nil,
    ui = nil,
    testBuysDone = 0,
    wouldBuyThrottle = {},
    lastBuyAt = 0,
    refreshLock = false,
    reopenKeepEnabled = false,
    filteredVendorPage = 1,
    filteredVendorUI = nil,
    lastFinishMessageAt = 0,
}

local eventFrame = CreateFrame("Frame")
local RefreshConfiguredItemsText
local ShortName

local function PersistLog(level, msg)
    if not IBUY_DB or not IBUY_DB.persistDebugLog then
        return
    end
    IBUY_DB.debugLog = IBUY_DB.debugLog or {}
    local maxEntries = tonumber(IBUY_DB.debugLogMaxEntries) or 2000
    local entry = string.format("%s [%s] %s", date("%Y-%m-%d %H:%M:%S"), tostring(level), tostring(msg))
    table.insert(IBUY_DB.debugLog, entry)
    while #IBUY_DB.debugLog > maxEntries do
        table.remove(IBUY_DB.debugLog, 1)
    end
end

local function Log(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[IBUY]|r " .. tostring(msg))
    PersistLog("INFO", msg)
end

local function Debug(msg)
    if IBUY_DB and IBUY_DB.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99[IBUY]|r |cff9999ffDEBUG|r " .. tostring(msg))
        PersistLog("DEBUG", msg)
    end
end

local function PlayHeftigSound()
    local ok = PlaySoundFile(HEFTIG_SOUND_PATH, "Master")
    if not ok then
        Log("HEFTIG-Sound nicht gefunden.")
        Log("Lege eine Datei ab unter: " .. HEFTIG_SOUND_PATH)
        return false
    end
    return true
end

local function SendInstanceFinishMessage()
    if not IBUY_DB.instanceFinishMessageEnabled then
        return
    end
    local text = IBUY_DB.instanceFinishMessage or DEFAULT_FINISH_MESSAGE
    if text == "" then
        return
    end

    local now = GetTime()
    if (now - STATE.lastFinishMessageAt) < 15 then
        return
    end
    STATE.lastFinishMessageAt = now

    local channel = nil
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        channel = "INSTANCE_CHAT"
    elseif IsInRaid() then
        channel = "RAID"
    elseif IsInGroup() then
        channel = "PARTY"
    end

    if channel then
        SendChatMessage(text, channel)
        Debug("Instanz-Text gesendet in " .. channel)
    else
        Log(text)
    end
end

local function CopyDefaults(dst, src)
    for key, value in pairs(src) do
        if dst[key] == nil then
            if type(value) == "table" then
                dst[key] = {}
                CopyDefaults(dst[key], value)
            else
                dst[key] = value
            end
        elseif type(value) == "table" and type(dst[key]) == "table" then
            CopyDefaults(dst[key], value)
        end
    end
end

local function EnsureWatchIndex()
    IBUY_DB.watchItems = {}
    IBUY_DB.watchOrder = IBUY_DB.watchOrder or {}

    local clean = {}
    local seen = {}
    for _, id in ipairs(IBUY_DB.watchOrder) do
        local numeric = tonumber(id)
        if numeric and numeric > 0 and not seen[numeric] then
            seen[numeric] = true
            table.insert(clean, numeric)
            IBUY_DB.watchItems[numeric] = true
        end
    end
    IBUY_DB.watchOrder = clean
end

local function ExtractItemID(link)
    if not link then
        return nil
    end
    local itemID = string.match(link, "item:(%d+)")
    if itemID then
        return tonumber(itemID)
    end
    return nil
end

local function IsWatching(itemID)
    return itemID and IBUY_DB.watchItems[itemID] == true
end

local function BuildMerchantIndexByItemID()
    local map = {}
    local count = GetMerchantNumItems()
    for index = 1, count do
        local link = GetMerchantItemLink(index)
        local itemID = ExtractItemID(link)
        if itemID and map[itemID] == nil then
            map[itemID] = index
        end
    end
    return map
end

local function GetMerchantItemInfoSafe(index)
    -- API compatibility:
    -- - Some versions: name, texture, price, quantity, numAvailable, isUsable, extendedCost
    -- - Other versions: name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost
    local name, texture, price, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(index)
    if extendedCost == nil then
        -- Shift values for 7-return API shape.
        extendedCost = isUsable
        isUsable = isPurchasable
        isPurchasable = nil
    end
    return {
        name = name,
        texture = texture,
        price = price or 0,
        quantity = quantity or 1,
        numAvailable = numAvailable,
        isPurchasable = isPurchasable,
        isUsable = isUsable,
        extendedCost = extendedCost,
    }
end

local function TryRefreshMerchant()
    if not STATE.merchantOpen or not IBUY_DB.enabled or not IBUY_DB.autoRefresh then
        return
    end
    -- Non-intrusive refresh: keep merchant open and request UI/list refresh.
    -- This avoids constant close/open loops.
    MerchantFrame_Update()
    RefreshConfiguredItemsText()
end

local function ForceVendorReopen()
    if not STATE.merchantOpen then
        Log("Vendor ist nicht offen.")
        return
    end
    if not UnitExists("target") then
        Log("Kein Target gesetzt. Bitte Vendor anvisieren und erneut klicken.")
        return
    end
    if STATE.refreshLock then
        return
    end
    local wasEnabled = IBUY_DB.enabled and true or false
    STATE.refreshLock = true
    STATE.reopenKeepEnabled = wasEnabled
    Debug("Manueller Refresh: Vendor kurz neu ansprechen.")
    CloseMerchant()
    C_Timer.After(0.20, function()
        InteractUnit("target")
        C_Timer.After(0.40, function()
            STATE.refreshLock = false
        end)
    end)
end

local function ShouldLogWouldBuy(itemID)
    local now = GetTime()
    local last = STATE.wouldBuyThrottle[itemID] or 0
    if (now - last) >= 2.0 then
        STATE.wouldBuyThrottle[itemID] = now
        return true
    end
    return false
end

local function ApplyMerchantRowFilter()
    if not STATE.merchantOpen then
        return
    end
    local selectedTab = MerchantFrame and MerchantFrame.selectedTab or nil
    local onBuybackTab = (selectedTab == 2)
    local hide = IBUY_DB.onlyShowTargets and (not onBuybackTab)
    for row = 1, MERCHANT_ITEMS_PER_PAGE do
        local button = _G["MerchantItem" .. row]
        if button then
            if hide then
                button:Hide()
            else
                button:Show()
            end
        end
    end
    if MerchantPageText then
        if hide then MerchantPageText:Hide() else MerchantPageText:Show() end
    end
    if MerchantPrevPageButton then
        if hide then MerchantPrevPageButton:Hide() else MerchantPrevPageButton:Show() end
    end
    if MerchantNextPageButton then
        if hide then MerchantNextPageButton:Hide() else MerchantNextPageButton:Show() end
    end
end

local function BuildFilteredVendorEntries()
    local result = {}
    local indexByItem = BuildMerchantIndexByItemID()
    for _, itemID in ipairs(IBUY_DB.watchOrder) do
        local merchantIndex = indexByItem[itemID]
        if merchantIndex then
            local info = GetMerchantItemInfoSafe(merchantIndex)
            table.insert(result, {
                merchantIndex = merchantIndex,
                itemID = itemID,
                name = info.name or ("item:" .. itemID),
                price = info.price or 0,
                numAvailable = info.numAvailable,
                extendedCost = info.extendedCost,
                texture = info.texture,
            })
        end
    end
    return result
end

local function EnsureFilteredVendorUI()
    if STATE.filteredVendorUI then
        return
    end
    local frame = CreateFrame("Frame", "IBUY_FilteredVendorFrame", MerchantFrame)
    frame:SetPoint("TOPLEFT", MerchantFrame, "TOPLEFT", 28, -76)
    frame:SetSize(330, 304)
    frame:Hide()

    frame.rows = {}
    for i = 1, 10 do
        local row = CreateFrame("Button", nil, frame, "BackdropTemplate")
        row:SetSize(322, 28)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -((i - 1) * 29))
        row:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8x8",
            edgeFile = "Interface/Buttons/WHITE8x8",
            tile = false,
            edgeSize = 1,
        })
        row:SetBackdropColor(0.05, 0.05, 0.05, 0.7)
        row:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)

        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(20, 20)
        row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameText:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.nameText:SetWidth(165)
        row.nameText:SetJustifyH("LEFT")

        row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.priceText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)
        row.priceText:SetWidth(70)
        row.priceText:SetJustifyH("LEFT")

        row.buyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.buyBtn:SetSize(52, 20)
        row.buyBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.buyBtn:SetText("Kauf")

        row.buyBtn:SetScript("OnClick", function(self)
            local entry = self.entry
            if not entry then
                return
            end
            BuyMerchantItem(entry.merchantIndex, 1)
            Debug(string.format("Manueller Kauf ueber Filterliste: %s (ID %d)", entry.name, entry.itemID))
        end)

        frame.rows[i] = row
    end

    frame.pageText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.pageText:SetPoint("BOTTOM", MerchantFrame, "BOTTOM", 0, 100)
    frame.pageText:SetText("Seite 1")

    frame.prevBtn = CreateFrame("Button", nil, MerchantFrame, "UIPanelButtonTemplate")
    frame.prevBtn:SetSize(52, 20)
    frame.prevBtn:SetPoint("BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 24, 114)
    frame.prevBtn:SetText("Zurueck")
    frame.prevBtn:SetScript("OnClick", function()
        if STATE.filteredVendorPage > 1 then
            STATE.filteredVendorPage = STATE.filteredVendorPage - 1
        end
        RefreshFilteredVendorUI()
    end)

    frame.nextBtn = CreateFrame("Button", nil, MerchantFrame, "UIPanelButtonTemplate")
    frame.nextBtn:SetSize(52, 20)
    frame.nextBtn:SetPoint("BOTTOMRIGHT", MerchantFrame, "BOTTOMRIGHT", -24, 114)
    frame.nextBtn:SetText("Weiter")
    frame.nextBtn:SetScript("OnClick", function()
        STATE.filteredVendorPage = STATE.filteredVendorPage + 1
        RefreshFilteredVendorUI()
    end)

    STATE.filteredVendorUI = frame
end

local function RefreshFilteredVendorUI()
    EnsureFilteredVendorUI()
    local ui = STATE.filteredVendorUI
    if not ui then
        return
    end

    local selectedTab = MerchantFrame and MerchantFrame.selectedTab or nil
    local onBuybackTab = (selectedTab == 2)
    if not (STATE.merchantOpen and IBUY_DB.onlyShowTargets and (not onBuybackTab)) then
        ui:Hide()
        ui.prevBtn:Hide()
        ui.nextBtn:Hide()
        ui.pageText:Hide()
        return
    end

    local entries = BuildFilteredVendorEntries()
    Debug(string.format("Filterliste: %d Vendor-Zielitems gefunden (tab=%s)", #entries, tostring(selectedTab)))
    if #entries == 0 then
        -- No matching target item currently sold by this vendor: do not blank the merchant window.
        IBUY_DB.onlyShowTargets = false
        if STATE.ui and STATE.ui.onlyTargetsCheck then
            STATE.ui.onlyTargetsCheck:SetChecked(false)
        end
        Log("Kein Zielitem bei diesem Vendor sichtbar. Filter wurde deaktiviert.")
        ApplyMerchantRowFilter()
        ui:Hide()
        ui.prevBtn:Hide()
        ui.nextBtn:Hide()
        ui.pageText:Hide()
        return
    end
    local perPage = 10
    local totalPages = math.max(1, math.ceil(#entries / perPage))
    if STATE.filteredVendorPage > totalPages then
        STATE.filteredVendorPage = totalPages
    end
    if STATE.filteredVendorPage < 1 then
        STATE.filteredVendorPage = 1
    end
    local startIndex = ((STATE.filteredVendorPage - 1) * perPage) + 1

    for rowIndex = 1, 10 do
        local row = ui.rows[rowIndex]
        local entry = entries[startIndex + rowIndex - 1]
        if entry then
            row:Show()
            row.icon:SetTexture(entry.texture)
            row.nameText:SetText(ShortName(entry.name, 26))
            row.priceText:SetText(MoneyText(entry.price))
            row.buyBtn.entry = entry
            row.buyBtn:Enable()
        else
            row:Hide()
            row.buyBtn.entry = nil
        end
    end

    ui.pageText:SetText(string.format("Seite %d/%d", STATE.filteredVendorPage, totalPages))
    ui.prevBtn:SetEnabled(STATE.filteredVendorPage > 1)
    ui.nextBtn:SetEnabled(STATE.filteredVendorPage < totalPages)

    ui:Show()
    ui.prevBtn:Show()
    ui.nextBtn:Show()
    ui.pageText:Show()
end

local function MoneyText(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local bronze = copper % 100
    return string.format("%dg %ds %dc", gold, silver, bronze)
end

local function BuildTargetRows()
    local rows = {}
    EnsureWatchIndex()
    local indexByItem = STATE.merchantOpen and BuildMerchantIndexByItemID() or {}

    for priority, itemID in ipairs(IBUY_DB.watchOrder) do
        local row = {
            priority = priority,
            itemID = itemID,
            name = tostring(itemID),
            status = "NICHT BEIM VENDOR",
            price = "-",
        }

        local link = select(2, GetItemInfo(itemID))
        if link then
            row.name = link
        end

        local merchantIndex = indexByItem[itemID]
        if merchantIndex then
            local info = GetMerchantItemInfoSafe(merchantIndex)
            row.name = info.name or row.name
            row.price = MoneyText(info.price)
            if info.numAvailable == 0 then
                row.status = "AUSVERKAUFT"
            elseif info.extendedCost then
                row.status = "SPEZIALKOSTEN"
            else
                row.status = "KAUFBAR"
            end
        end

        table.insert(rows, row)
    end
    return rows
end

ShortName = function(text, maxLen)
    if not text then
        return "?"
    end
    if string.len(text) <= maxLen then
        return text
    end
    return string.sub(text, 1, maxLen - 3) .. "..."
end

local function FormatItemLabel(itemID)
    local link = select(2, GetItemInfo(itemID))
    if link then
        return string.format("%s (ID %d)", link, itemID)
    end
    return string.format("item:%d (unbekannt)", itemID)
end

RefreshConfiguredItemsText = function()
    if not STATE.ui or not STATE.ui.itemsText then
        return
    end
    if #IBUY_DB.watchOrder == 0 then
        STATE.ui.itemsText:SetText("Keine Zielitems konfiguriert.")
        return
    end
    local rows = BuildTargetRows()
    local lines = {}
    lines[#lines + 1] = "Prio | ID    | Item                    | Status        | Preis"
    lines[#lines + 1] = "-----+-------+-------------------------+---------------+-----------"
    for _, row in ipairs(rows) do
        local displayName = row.name
        if string.find(displayName, "|Hitem:") then
            displayName = GetItemInfo(row.itemID) or ("item:" .. row.itemID)
        end
        lines[#lines + 1] = string.format(
            "%4d | %5d | %-23s | %-13s | %s",
            row.priority,
            row.itemID,
            ShortName(displayName, 23),
            ShortName(row.status, 13),
            row.price
        )
    end
    if #rows == 0 then
        lines[#lines + 1] = "(Aktive Filterung: keine deiner Zielitems ist bei diesem Vendor sichtbar)"
    end
    STATE.ui.itemsText:SetText(table.concat(lines, "\n"))
end

local function RefreshStatusLabel(extra)
    if not STATE.ui or not STATE.ui.statusText then
        return
    end
    local run = IBUY_DB.enabled and "AKTIV" or "AUS"
    local mode = IBUY_DB.testMode and string.format("TEST (%d/%d)", STATE.testBuysDone, IBUY_DB.testModeRealBuys) or "LIVE"
    local suffix = extra and (" | " .. extra) or ""
    STATE.ui.statusText:SetText(string.format("Status: %s | Modus: %s%s", run, mode, suffix))
end

local function UpdateToggleButton()
    if not STATE.ui or not STATE.ui.toggleBtn then
        return
    end
    if IBUY_DB.enabled then
        STATE.ui.toggleBtn:SetText("IBUY Stop")
    else
        STATE.ui.toggleBtn:SetText("IBUY Start")
    end
    RefreshStatusLabel()
end

local function AddWatchItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false, "Ungueltige Item-ID."
    end
    EnsureWatchIndex()
    if IBUY_DB.watchItems[itemID] then
        return false, string.format("Item-ID %d ist bereits in der Liste.", itemID)
    end
    table.insert(IBUY_DB.watchOrder, itemID)
    IBUY_DB.watchItems[itemID] = true
    RefreshConfiguredItemsText()
    ApplyMerchantRowFilter()
    return true, string.format("Item-ID %d hinzugefuegt.", itemID)
end

local function RemoveWatchItem(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return false, "Ungueltige Item-ID."
    end
    EnsureWatchIndex()
    if not IBUY_DB.watchItems[itemID] then
        return false, string.format("Item-ID %d nicht gefunden.", itemID)
    end
    IBUY_DB.watchItems[itemID] = nil
    local rebuilt = {}
    for _, id in ipairs(IBUY_DB.watchOrder) do
        if id ~= itemID then
            table.insert(rebuilt, id)
        end
    end
    IBUY_DB.watchOrder = rebuilt
    RefreshConfiguredItemsText()
    ApplyMerchantRowFilter()
    return true, string.format("Item-ID %d entfernt.", itemID)
end

local function BuyCycleStep()
    if not STATE.merchantOpen or not IBUY_DB.enabled then
        return
    end

    EnsureWatchIndex()
    if #IBUY_DB.watchOrder == 0 then
        RefreshStatusLabel("Keine Zielitems")
        return
    end

    local indexByItem = BuildMerchantIndexByItemID()
    local money = GetMoney() or 0

    local foundAnyTargetAtVendor = false
    for _, itemID in ipairs(IBUY_DB.watchOrder) do
        local merchantIndex = indexByItem[itemID]
        if merchantIndex then
            foundAnyTargetAtVendor = true
            local info = GetMerchantItemInfoSafe(merchantIndex)
            if info.name then
                local canBuyThisItem = true
                if info.numAvailable == 0 then
                    if ShouldLogWouldBuy(itemID) then
                        Debug(string.format("%s ist aktuell ausverkauft.", info.name))
                    end
                    canBuyThisItem = false
                end
                if canBuyThisItem and info.extendedCost then
                    if ShouldLogWouldBuy(itemID) then
                        Debug(string.format("%s hat erweiterten Preis, wird uebersprungen.", info.name))
                    end
                    canBuyThisItem = false
                end
                if canBuyThisItem and info.price > money then
                    if ShouldLogWouldBuy(itemID) then
                        Log(string.format("Nicht genug Gold fuer %s.", info.name))
                    end
                    canBuyThisItem = false
                end

                if canBuyThisItem and IBUY_DB.testMode and STATE.testBuysDone >= IBUY_DB.testModeRealBuys then
                    if ShouldLogWouldBuy(itemID) then
                        Log(string.format("Testmodus: Wuerde kaufen -> %s (ID %d)", info.name, itemID))
                    end
                    RefreshStatusLabel("Testmodus Log-Only")
                    return
                end

                if canBuyThisItem then
                    BuyMerchantItem(merchantIndex, 1)
                    STATE.lastBuyAt = GetTime()
                    if IBUY_DB.testMode then
                        STATE.testBuysDone = STATE.testBuysDone + 1
                        Log(string.format("Testkauf %d/%d: %s (ID %d)",
                            STATE.testBuysDone, IBUY_DB.testModeRealBuys, info.name, itemID))
                    else
                        Log(string.format("Gekauft: %s (ID %d)", info.name, itemID))
                    end
                    RefreshStatusLabel()
                    RefreshConfiguredItemsText()
                    return
                end
            end
        end
    end

    if foundAnyTargetAtVendor then
        RefreshStatusLabel("Zielitems gesehen, aktuell nicht kaufbar")
    else
        RefreshStatusLabel("Zielitem nicht im aktuellen Vendor")
    end
    RefreshConfiguredItemsText()
end

local function StopLoop()
    if STATE.loopTicker then
        STATE.loopTicker:Cancel()
        STATE.loopTicker = nil
    end
    if STATE.refreshTicker then
        STATE.refreshTicker:Cancel()
        STATE.refreshTicker = nil
    end
end

local function StartLoop()
    StopLoop()
    STATE.loopTicker = C_Timer.NewTicker(IBUY_DB.scanInterval, function()
        BuyCycleStep()
    end)
    if IBUY_DB.autoRefresh then
        STATE.refreshTicker = C_Timer.NewTicker(IBUY_DB.refreshSeconds, function()
            TryRefreshMerchant()
        end)
    end
end

local function SetEnabled(newValue)
    IBUY_DB.enabled = newValue and true or false
    if IBUY_DB.enabled and STATE.merchantOpen then
        STATE.testBuysDone = 0
        STATE.wouldBuyThrottle = {}
        StartLoop()
        Log("Auto-Buy gestartet.")
    else
        StopLoop()
        Log("Auto-Buy gestoppt.")
    end
    UpdateToggleButton()
end

local function CreateMerchantUI()
    if STATE.ui then
        return
    end

    local panel = CreateFrame("Frame", "IBUY_MerchantPanel", MerchantFrame, "BackdropTemplate")
    panel:SetSize(560, 420)
    panel:SetPoint("TOPLEFT", MerchantFrame, "TOPRIGHT", 8, -28)
    panel:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    panel:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText("IBUY")

    local statusText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    statusText:SetJustifyH("LEFT")
    statusText:SetWidth(530)
    statusText:SetText("Status: AUS")

    local toggleBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    toggleBtn:SetSize(110, 22)
    toggleBtn:SetPoint("TOPLEFT", statusText, "BOTTOMLEFT", 0, -8)
    toggleBtn:SetText("IBUY Start")
    toggleBtn:SetScript("OnClick", function()
        SetEnabled(not IBUY_DB.enabled)
    end)

    local heftigBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    heftigBtn:SetSize(80, 22)
    heftigBtn:SetPoint("LEFT", toggleBtn, "RIGHT", 8, 0)
    heftigBtn:SetText("HEFTIG")
    heftigBtn:SetScript("OnClick", function()
        local ok = PlayHeftigSound()
        if ok then
            Log("HEFTIG!")
        end
    end)

    local testModeCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    testModeCheck:SetPoint("TOPLEFT", toggleBtn, "BOTTOMLEFT", -2, -8)
    local testModeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    testModeLabel:SetPoint("LEFT", testModeCheck, "RIGHT", 2, 1)
    testModeLabel:SetText("Testmodus (2 echte Kaeufe)")
    testModeCheck:SetScript("OnClick", function(self)
        IBUY_DB.testMode = self:GetChecked() and true or false
        STATE.testBuysDone = 0
        RefreshStatusLabel()
    end)

    local onlyTargetsCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    onlyTargetsCheck:SetPoint("TOPLEFT", testModeCheck, "BOTTOMLEFT", 0, -4)
    local onlyTargetsLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    onlyTargetsLabel:SetPoint("LEFT", onlyTargetsCheck, "RIGHT", 2, 1)
    onlyTargetsLabel:SetText("Vendor-Filter (BETA, aktuell nicht stabil)")
    onlyTargetsCheck:SetScript("OnClick", function(self)
        IBUY_DB.onlyShowTargets = self:GetChecked() and true or false
        if IBUY_DB.onlyShowTargets then
            Log("Hinweis: Vendor-Filter ist BETA und aktuell nicht stabil.")
        end
        STATE.filteredVendorPage = 1
        if IBUY_DB.onlyShowTargets and MerchantFrame and MerchantFrame.selectedTab == 2 then
            -- Force switch to merchant buy tab so filtered entries can be shown.
            PanelTemplates_SetTab(MerchantFrame, 1)
            MerchantFrame.selectedTab = 1
            MerchantFrame_Update()
        end
        Debug(string.format("Vendor-Filter gesetzt: onlyShowTargets=%s", tostring(IBUY_DB.onlyShowTargets)))
        ApplyMerchantRowFilter()
        RefreshFilteredVendorUI()
        RefreshConfiguredItemsText()
    end)

    local refreshCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    refreshCheck:SetPoint("TOPLEFT", onlyTargetsCheck, "BOTTOMLEFT", 0, -4)
    local refreshLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    refreshLabel:SetPoint("LEFT", refreshCheck, "RIGHT", 2, 1)
    refreshLabel:SetText("Auto-Refresh (ohne Fenster neu zu oeffnen)")
    refreshCheck:SetScript("OnClick", function(self)
        IBUY_DB.autoRefresh = self:GetChecked() and true or false
        if IBUY_DB.enabled and STATE.merchantOpen then
            StartLoop()
        end
    end)

    local refreshNowBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    refreshNowBtn:SetSize(140, 22)
    refreshNowBtn:SetPoint("LEFT", refreshCheck, "RIGHT", 180, 0)
    refreshNowBtn:SetText("Vendor neu ansprechen")
    refreshNowBtn:SetScript("OnClick", function()
        ForceVendorReopen()
    end)

    local addLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    addLabel:SetPoint("TOPLEFT", refreshCheck, "BOTTOMLEFT", 2, -8)
    addLabel:SetText("Item-ID hinzufuegen:")

    local addBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    addBox:SetSize(90, 22)
    addBox:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", -2, -6)
    addBox:SetAutoFocus(false)
    addBox:SetNumeric(true)
    addBox:SetMaxLetters(10)

    local addBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    addBtn:SetSize(55, 22)
    addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    addBtn:SetText("Add")
    addBtn:SetScript("OnClick", function()
        local value = tonumber(addBox:GetText())
        if not value then
            Log("Bitte eine gueltige Item-ID eingeben.")
            return
        end
        local ok, message = AddWatchItem(value)
        Log(message)
        if ok then
            addBox:SetText("")
        end
    end)

    local removeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    removeBtn:SetSize(60, 22)
    removeBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)
    removeBtn:SetText("Remove")
    removeBtn:SetScript("OnClick", function()
        local value = tonumber(addBox:GetText())
        if not value then
            Log("Bitte eine Item-ID in das Feld schreiben, die entfernt werden soll.")
            return
        end
        local _, message = RemoveWatchItem(value)
        Log(message)
    end)

    local tableTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tableTitle:SetPoint("TOPLEFT", addBox, "BOTTOMLEFT", 0, -12)
    tableTitle:SetText("Gefilterte Zielitem-Tabelle:")

    local itemsText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemsText:SetPoint("TOPLEFT", tableTitle, "BOTTOMLEFT", 0, -6)
    itemsText:SetWidth(530)
    itemsText:SetJustifyH("LEFT")
    itemsText:SetJustifyV("TOP")
    itemsText:SetText("")

    STATE.ui = {
        panel = panel,
        statusText = statusText,
        toggleBtn = toggleBtn,
        testModeCheck = testModeCheck,
        onlyTargetsCheck = onlyTargetsCheck,
        refreshCheck = refreshCheck,
        itemsText = itemsText,
    }
end

local function OpenMerchant()
    STATE.merchantOpen = true
    STATE.testBuysDone = 0
    STATE.wouldBuyThrottle = {}

    CreateMerchantUI()
    if STATE.ui then
        STATE.ui.panel:Show()
        STATE.ui.testModeCheck:SetChecked(IBUY_DB.testMode)
        STATE.ui.onlyTargetsCheck:SetChecked(IBUY_DB.onlyShowTargets)
        STATE.ui.refreshCheck:SetChecked(IBUY_DB.autoRefresh)
        UpdateToggleButton()
        RefreshConfiguredItemsText()
    end

    ApplyMerchantRowFilter()
    RefreshFilteredVendorUI()

    if IBUY_DB.enabled then
        StartLoop()
        Log("Merchant geoeffnet. Auto-Buy aktiv.")
    end
end

local function CloseMerchantFrameState()
    STATE.merchantOpen = false
    StopLoop()
    if STATE.ui and STATE.ui.panel then
        STATE.ui.panel:Hide()
    end
    if STATE.filteredVendorUI then
        STATE.filteredVendorUI:Hide()
        STATE.filteredVendorUI.prevBtn:Hide()
        STATE.filteredVendorUI.nextBtn:Hide()
        STATE.filteredVendorUI.pageText:Hide()
    end
    if STATE.reopenKeepEnabled then
        -- Manual refresh flow: keep enabled state and restart on MERCHANT_SHOW.
        STATE.reopenKeepEnabled = false
        Debug("Merchant geschlossen fuer Refresh, Auto-Buy bleibt aktiv.")
        return
    end
    IBUY_DB.enabled = false
    UpdateToggleButton()
    Log("Merchant geschlossen. Auto-Buy wurde gestoppt.")
end

local function PrintHelp()
    Log("Befehle:")
    Log("/ibuy start - Auto-Buy starten (nur bei offenem Vendor)")
    Log("/ibuy stop - Auto-Buy stoppen")
    Log("/ibuy add <itemID> - Item-ID zur Prioritaetsliste")
    Log("/ibuy remove <itemID> - Item-ID entfernen")
    Log("/ibuy list - Konfiguration anzeigen")
    Log("/ibuy test on|off - Testmodus umschalten")
    Log("/ibuy debug on|off - Debug-Logs umschalten")
    Log("/ibuy postvideo - Postet den Video-Text in Gruppe/Instanz")
    Log("/ibuy heftig - Spielt das EasterEgg-Soundfile ab")
    Log("/ibuy finishmsg on|off - Auto-Nachricht bei Instanzabschluss")
    Log("/ibuy logfile on|off - Persistente Debug-Datei aktivieren/deaktivieren")
    Log("/ibuy logclear - Persistente Debug-Datei leeren")
    Log("/ibuy logtail <n> - Letzte n Zeilen in den Chat ausgeben")
    Log("/ibuy logpath - Speicherort der Debug-Datei anzeigen")
    Log("/ibuy selftest - interne Logiktests ausfuehren")
end

local function ListConfig()
    Log(string.format("Aktiv: %s | Testmodus: %s", tostring(IBUY_DB.enabled), tostring(IBUY_DB.testMode)))
    Log(string.format("Auto-Refresh: %s | Nur Zielitems: %s",
        tostring(IBUY_DB.autoRefresh), tostring(IBUY_DB.onlyShowTargets)))
    Log(string.format("Debug-Datei: %s | Log-Eintraege: %d",
        tostring(IBUY_DB.persistDebugLog), #(IBUY_DB.debugLog or {})))
    Log(string.format("Instanz-Abschlussnachricht: %s", tostring(IBUY_DB.instanceFinishMessageEnabled)))
    if #IBUY_DB.watchOrder == 0 then
        Log("Keine Zielitems konfiguriert.")
        return
    end
    for index, itemID in ipairs(IBUY_DB.watchOrder) do
        Log(string.format("%d) %s", index, FormatItemLabel(itemID)))
    end
end

local function HandleSlash(msg)
    local trimmed = string.gsub(msg or "", "^%s*(.-)%s*$", "%1")
    local cmd, arg1 = string.match(trimmed, "^(%S+)%s*(.*)$")
    cmd = cmd and string.lower(cmd) or ""
    arg1 = arg1 and string.gsub(arg1, "^%s*(.-)%s*$", "%1") or ""

    if cmd == "" or cmd == "help" then
        PrintHelp()
        return
    end
    if cmd == "start" then
        if not STATE.merchantOpen then
            Log("Bitte zuerst ein Vendor-Fenster oeffnen.")
            return
        end
        SetEnabled(true)
        return
    end
    if cmd == "stop" then
        SetEnabled(false)
        return
    end
    if cmd == "add" then
        local ok, message = AddWatchItem(arg1)
        Log(message)
        return
    end
    if cmd == "remove" then
        local _, message = RemoveWatchItem(arg1)
        Log(message)
        return
    end
    if cmd == "list" then
        ListConfig()
        return
    end
    if cmd == "test" then
        if arg1 == "on" then
            IBUY_DB.testMode = true
            STATE.testBuysDone = 0
            UpdateToggleButton()
            Log("Testmodus aktiviert.")
            return
        elseif arg1 == "off" then
            IBUY_DB.testMode = false
            STATE.testBuysDone = 0
            UpdateToggleButton()
            Log("Testmodus deaktiviert.")
            return
        end
        Log("Verwendung: /ibuy test on|off")
        return
    end
    if cmd == "debug" then
        if arg1 == "on" then
            IBUY_DB.debug = true
            Log("Debug aktiviert.")
            return
        elseif arg1 == "off" then
            IBUY_DB.debug = false
            Log("Debug deaktiviert.")
            return
        end
        Log("Verwendung: /ibuy debug on|off")
        return
    end
    if cmd == "postvideo" then
        SendInstanceFinishMessage()
        return
    end
    if cmd == "heftig" then
        PlayHeftigSound()
        return
    end
    if cmd == "finishmsg" then
        if arg1 == "on" then
            IBUY_DB.instanceFinishMessageEnabled = true
            Log("Instanz-Abschlussnachricht aktiviert.")
            return
        elseif arg1 == "off" then
            IBUY_DB.instanceFinishMessageEnabled = false
            Log("Instanz-Abschlussnachricht deaktiviert.")
            return
        end
        Log("Verwendung: /ibuy finishmsg on|off")
        return
    end
    if cmd == "logfile" then
        if arg1 == "on" then
            IBUY_DB.persistDebugLog = true
            IBUY_DB.debugLog = IBUY_DB.debugLog or {}
            Log("Persistente Debug-Datei aktiviert.")
            Log("Datei: WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua (Schluessel: debugLog)")
            Log("Hinweis: Datei wird bei /reload, Logout oder Spielende geschrieben.")
            return
        elseif arg1 == "off" then
            IBUY_DB.persistDebugLog = false
            Log("Persistente Debug-Datei deaktiviert.")
            return
        end
        Log("Verwendung: /ibuy logfile on|off")
        return
    end
    if cmd == "logclear" then
        IBUY_DB.debugLog = {}
        Log("Debug-Datei geleert.")
        return
    end
    if cmd == "logtail" then
        local n = tonumber(arg1) or 20
        if n < 1 then n = 1 end
        if n > 100 then n = 100 end
        local logs = IBUY_DB.debugLog or {}
        if #logs == 0 then
            Log("Debug-Datei ist leer.")
            return
        end
        local from = math.max(1, #logs - n + 1)
        Log(string.format("Debug-Tail: %d Zeilen", #logs - from + 1))
        for i = from, #logs do
            DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[IBUY LOG]|r " .. tostring(logs[i]))
        end
        return
    end
    if cmd == "logpath" then
        Log("Datei: WTF/Account/<ACCOUNT>/SavedVariables/IBUY.lua")
        Log("Schluessel: IBUY_DB.debugLog")
        Log("Hinweis: Datei wird bei /reload, Logout oder Spielende geschrieben.")
        return
    end
    if cmd == "selftest" then
        if IBUY and IBUY.RunSelfTests then
            IBUY.RunSelfTests()
        else
            Log("Selftests sind nicht verfuegbar.")
        end
        return
    end

    PrintHelp()
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded ~= ADDON_NAME then
            return
        end
        IBUY_DB = IBUY_DB or {}
        CopyDefaults(IBUY_DB, DEFAULTS)
        EnsureWatchIndex()
        if not STATE.hookedMerchantUpdate then
            hooksecurefunc("MerchantFrame_Update", function()
                if STATE.merchantOpen then
                    ApplyMerchantRowFilter()
                    RefreshFilteredVendorUI()
                end
            end)
            STATE.hookedMerchantUpdate = true
        end
        SLASH_IBUY1 = "/ibuy"
        SlashCmdList.IBUY = HandleSlash
        Log("Geladen. /ibuy fuer Befehle.")
        return
    end

    if event == "MERCHANT_SHOW" then
        OpenMerchant()
        return
    end

    if event == "MERCHANT_UPDATE" then
        ApplyMerchantRowFilter()
        RefreshFilteredVendorUI()
        RefreshConfiguredItemsText()
        return
    end

    if event == "MERCHANT_CLOSED" then
        CloseMerchantFrameState()
        return
    end

    if event == "LFG_COMPLETION_REWARD" or event == "CHALLENGE_MODE_COMPLETED" then
        SendInstanceFinishMessage()
        return
    end
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("MERCHANT_SHOW")
eventFrame:RegisterEvent("MERCHANT_UPDATE")
eventFrame:RegisterEvent("MERCHANT_CLOSED")
eventFrame:RegisterEvent("LFG_COMPLETION_REWARD")
eventFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
eventFrame:SetScript("OnEvent", OnEvent)

-- Expose selected internals for small runtime self-tests.
IBUY._ExtractItemID = ExtractItemID
IBUY._EnsureWatchIndex = EnsureWatchIndex
IBUY._AddWatchItem = AddWatchItem
IBUY._RemoveWatchItem = RemoveWatchItem
IBUY._IsWatching = IsWatching
