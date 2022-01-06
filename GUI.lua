local addonName = "LootArchive"
local addonTitle = select(2, GetAddOnInfo(addonName))
local LA = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = LibStub("AceGUI-3.0")
local f, scrollFrame, rows

function LA:CreateGUI()
    f = AceGUI:Create("Frame")
    f:Hide()
    f:EnableResize(false)

    f:SetCallback("OnClose", function(widget)
        -- AceGUI:Release(widget)
        -- Cancel filter on close
        self:SetFilter()
        -- TODO: maybe also cancel sort ?
    end)
    f:SetTitle(addonTitle)
    local frameName = addonName .."_MainFrame"
	_G[frameName] = f
	table.insert(UISpecialFrames, frameName) -- Allow ESC close
    -- f:SetStatusText("Status Bar")
    f:SetLayout("Flow")
    
    -- SEARCH HEADER
    local searchHeader = AceGUI:Create("SimpleGroup")
	searchHeader:SetFullWidth(true)
	searchHeader:SetLayout("Flow")
    f:AddChild(searchHeader)

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(L["Search for item or player"])
    searchBox:SetFullWidth(true)
    searchBox:SetCallback("OnEnterPressed", function(widget, event, text)
        LA:FilterRows(text)
    end)
    searchHeader:AddChild(searchBox)

    -- BUTTONS
    local exportButton = AceGUI:Create("Button")
	exportButton:SetCallback("OnClick", function() LA:ExportDatabase() end)
	exportButton:SetHeight(20)
	exportButton:SetWidth(100)
	exportButton:SetText(L["Export"])
    searchHeader:AddChild(exportButton)

    -- TABLE HEADER
    local tableHeader = AceGUI:Create("SimpleGroup")
    tableHeader:SetFullWidth(true)
    tableHeader:SetLayout("Flow")
    f:AddChild(tableHeader)

    local margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    local btn
    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(195)
    btn:SetText(string.format(" %s ", L["Item"]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() LA:SortRows("item") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(110)
    btn:SetText(string.format(" %s ", L["Player"]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() LA:SortRows("player") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(170)
    btn:SetText(string.format(" %s ", L["Reason"]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() LA:SortRows("reason") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(140)
    btn:SetText(string.format(" %s ", L["Date"]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() LA:SortRows("date") end)
    tableHeader:AddChild(btn)

    -- TABLE
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    f:AddChild(scrollContainer)

	scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer.frame, "_HybridScrollFrame")
	HybridScrollFrame_CreateButtons(scrollFrame, "_HybridScrollListItemTemplate")
	scrollFrame.update = function() LA:RedrawRows() end
end

function LA:RedrawRows()
	local buttons = HybridScrollFrame_GetButtons(scrollFrame)
    local offset = HybridScrollFrame_GetOffset(scrollFrame)

    for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
        local itemIndex = buttonIndex + offset
        local row = rows[itemIndex]

        if (itemIndex <= #rows) then
            button:SetID(itemIndex)

            self:GetItemMixin(row["id"], function(itemMixin)
                button.Icon:SetTexture(itemMixin:GetItemIcon())
                button.Item:SetText(itemMixin:GetItemLink())
                button.IconAndItem:EnableMouse(true)
                button.IconAndItem:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(button.IconAndItem, "ANCHOR_TOP")
                    GameTooltip:SetHyperlink(itemMixin:GetItemLink())
                    GameTooltip:Show()
                end)
                button.IconAndItem:SetScript("OnLeave", function() self:HideTooltip() end)
            end)
            button.PlayerName:SetText(row["player"])
            button.Reason:SetText(row["reason"])
            button.Date:SetText(date(L["%F %T"], row["date"]))

            button:SetWidth(scrollFrame.scrollChild:GetWidth())
			button:Show()
		else
			button:Hide()
		end
	end

	local buttonHeight = scrollFrame.buttonHeight
	local totalHeight = #rows * buttonHeight
	local shownHeight = #buttons * buttonHeight

	HybridScrollFrame_Update(scrollFrame, totalHeight, shownHeight)
end

function LA:UpdateRows()
    rows = self:GenerateRows()
    f:SetStatusText(string.format(L["%d records"], #rows))
end

function LA:ShowGUI()
    if not f then
        self:CreateGUI()
    end

    f:Show()
    self:UpdateRows()
    self:RedrawRows()
end

function LA:IsGUIVisible()
    return f and f:IsShown()
end

function LA:HideGUI()
    f:Hide()
end

function LA:ToggleGUI()
    if self:IsGUIVisible() then
        self:HideGUI()
    else
        self:ShowGUI()
    end
end

function LA:SortRows(column)
    scrollFrame:SetVerticalScroll(0)
    self:SetSort(column)
    self:UpdateRows()
    self:RedrawRows()
end

function LA:FilterRows(text)
    scrollFrame:SetVerticalScroll(0)
    self:SetFilter(text)
    self:UpdateRows()
    self:RedrawRows()
end

function LA:HumanDuration(miliseconds)
    local seconds = math.floor(miliseconds / 1000)
    if seconds < 60 then
        return string.format(L["%is"], seconds)
    end
    local minutes = math.floor(seconds / 60)
    if minutes < 60 then
        return string.format(L["%im %is"], minutes, (seconds - minutes * 60))
    end
    local hours = math.floor(minutes / 60)
    return string.format(L["%ih %im"], hours, (minutes - hours * 60))
end

function LA:ShowTooltip(owner, lines)
    GameTooltip:SetOwner(owner.frame, "ANCHOR_TOP")
    GameTooltip:ClearLines()
    for _, line in ipairs(lines) do
        GameTooltip:AddLine(line)
    end
    GameTooltip:Show()
end

function LA:HideTooltip()
    GameTooltip:Hide()
end
