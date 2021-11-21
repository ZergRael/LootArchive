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

    -- f:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    f:SetTitle(addonTitle)
    local frameName = addonName .."_MainFrame"
	_G[frameName] = f
	table.insert(UISpecialFrames, frameName) -- Allow ESC close
    f:SetStatusText("Status Bar")
    f:SetLayout("Flow")

    -- TABLE
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    f:AddChild(scrollContainer)

	scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer.frame, "_HybridScrollFrame")
	HybridScrollFrame_CreateButtons(scrollFrame, "_HybridScrollListItemTemplate")
	scrollFrame.update = function() LA:UpdateTableView() end
end

function LA:RefreshLayout()
	local buttons = HybridScrollFrame_GetButtons(scrollFrame)
    local offset = HybridScrollFrame_GetOffset(scrollFrame)

    f:SetStatusText(string.format("Status text"))

	local buttonHeight = scrollFrame.buttonHeight
	local totalHeight = #rows * buttonHeight
	local shownHeight = #buttons * buttonHeight

	HybridScrollFrame_Update(scrollFrame, totalHeight, shownHeight)
end

function LA:ShowGUI()
    if not f then
        self:CreateGUI()
    end

    rows = LA:GenerateRows()

    f:Show()
    self:RefreshLayout()
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

function LA:Sort(column)
    scrollFrame:SetVerticalScroll(0)
    rows = LA:GenerateRows(column)
    self:RefreshLayout()
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
    AceGUI.tooltip:SetOwner(owner.frame, "ANCHOR_TOP")
    AceGUI.tooltip:ClearLines()
    for i, line in ipairs(lines) do
        AceGUI.tooltip:AddLine(line)
    end
    AceGUI.tooltip:Show()
end

function LA:HideTooltip()
    AceGUI.tooltip:Hide()
end
