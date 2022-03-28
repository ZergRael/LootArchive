local addonName = "LootArchive"
local addonTitle = select(2, GetAddOnInfo(addonName))
local LA = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local AceGUI = LibStub("AceGUI-3.0")
local mainFrame, scrollFrame, rows, editMode, editItem, editFrame, editPlayer, editReason, editDate

function LA:CreateGUI()
    mainFrame = AceGUI:Create("Frame")
    mainFrame:Hide()
    mainFrame:EnableResize(false)

    mainFrame:SetCallback("OnClose", function(widget)
        -- AceGUI:Release(widget)
        -- Cancel filter on close
        self:SetFilter()
        -- TODO: maybe also cancel sort ?
    end)
    mainFrame:SetTitle(addonTitle)
    local frameName = addonName .."_MainFrame"
	_G[frameName] = mainFrame
	table.insert(UISpecialFrames, frameName) -- Allow ESC close
    -- mainFrame:SetStatusText("Status Bar")
    mainFrame:SetLayout("Flow")

    -- SEARCH HEADER
    local searchHeader = AceGUI:Create("SimpleGroup")
	searchHeader:SetFullWidth(true)
	searchHeader:SetLayout("Flow")
    mainFrame:AddChild(searchHeader)

    -- Search box
    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel(L["Search for item or player"])
    searchBox:SetFullWidth(true)
    searchBox:SetCallback("OnEnterPressed", function(widget, event, text)
        LA:FilterRows(text)
    end)
    searchHeader:AddChild(searchBox)

    -- BUTTONS
    local addButton = AceGUI:Create("Button")
	addButton:SetCallback("OnClick", function() LA:ShowCreateRowFrame() end)
	addButton:SetHeight(20)
	addButton:SetWidth(100)
	addButton:SetText(L["Add loot"])
    searchHeader:AddChild(addButton)

    local margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    searchHeader:AddChild(margin)

    -- Export button
    local exportButton = AceGUI:Create("Button")
	exportButton:SetCallback("OnClick", function() LA:ExportDatabase() end)
	exportButton:SetHeight(20)
	exportButton:SetWidth(100)
	exportButton:SetText(L["Export"])
    searchHeader:AddChild(exportButton)

    margin = AceGUI:Create("Label")
    margin:SetWidth(12)
    searchHeader:AddChild(margin)

    local info = AceGUI:Create("Label")
    info:SetText(L["Double click to modify rows (+ Ctrl to delete)"])
    searchHeader:AddChild(info)

    -- TABLE HEADER
    local tableHeader = AceGUI:Create("SimpleGroup")
    tableHeader:SetFullWidth(true)
    tableHeader:SetLayout("Flow")
    mainFrame:AddChild(tableHeader)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    -- Item header
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

    -- Player header
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

    -- Reason header
    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(180)
    btn:SetText(string.format(" %s ", L["Reason"]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() LA:SortRows("reason") end)
    tableHeader:AddChild(btn)

    margin = AceGUI:Create("Label")
    margin:SetWidth(4)
    tableHeader:AddChild(margin)

    -- Date header
    btn = AceGUI:Create("InteractiveLabel")
    btn:SetWidth(140)
    btn:SetText(string.format(" %s ", L["Date"]))
    btn:SetJustifyH("LEFT")
    btn.highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
    btn:SetCallback("OnClick", function() LA:SortRows("date") end)
    tableHeader:AddChild(btn)

    -- TABLE CONTENTS
    local scrollContainer = AceGUI:Create("SimpleGroup")
    scrollContainer:SetFullWidth(true)
    scrollContainer:SetFullHeight(true)
    scrollContainer:SetLayout("Fill")
    mainFrame:AddChild(scrollContainer)

	scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer.frame, "HybridScrollFrame")
	HybridScrollFrame_CreateButtons(scrollFrame, "HybridScrollListItemTemplate")
	scrollFrame.update = function() LA:RedrawRows() end
end

-- Update GUI with rows contents
function LA:RedrawRows()
	local buttons = HybridScrollFrame_GetButtons(scrollFrame)
    local offset = HybridScrollFrame_GetOffset(scrollFrame)

    for buttonIndex = 1, #buttons do
		local button = buttons[buttonIndex]
        local itemIndex = buttonIndex + offset
        local row = rows[itemIndex]

        if (itemIndex <= #rows) then
            button:SetID(itemIndex)
            button:SetScript("OnDoubleClick", function()
                if IsControlKeyDown() then
                    self:ConfirmDeleteRow(row)
                else
                    self:ShowEditRowFrame(row)
                end
            end)

            self:GetItemMixin(row["id"], function(itemMixin)
                button.Icon:SetTexture(itemMixin:GetItemIcon())
                button.ItemHTML:SetText(itemMixin:GetItemLink())
                button.ItemHTML:SetScript("OnHyperlinkEnter", function()
                    GameTooltip:SetOwner(button.IconAndItem, "ANCHOR_TOP")
                    GameTooltip:SetHyperlink(itemMixin:GetItemLink())
                    GameTooltip:Show()
                end)
                button.ItemHTML:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)
                button.ItemHTML:SetScript("OnHyperlinkClick", function() self:HandleItemClick(itemMixin) end)
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

-- Apply row filters and update status text
function LA:UpdateRows()
    rows = self:GenerateRows()
    mainFrame:SetStatusText(string.format(L["%d records"], #rows))
end

-- Create GUI if necessary and draw rows
function LA:ShowGUI()
    if not mainFrame then
        self:CreateGUI()
    end

    mainFrame:Show()
    self:UpdateRows()
    self:RedrawRows()
end

function LA:IsGUIVisible()
    return mainFrame and mainFrame:IsShown()
end

function LA:HideGUI()
    mainFrame:Hide()
end

-- Show/Hide GUI based on current visibility state
function LA:ToggleGUI()
    if self:IsGUIVisible() then
        self:HideGUI()
    else
        self:ShowGUI()
    end
end

-- Apply sort on rows and update GUI
function LA:SortRows(column)
    scrollFrame:SetVerticalScroll(0)
    self:SetSort(column)
    self:UpdateRows()
    self:RedrawRows()
end

-- Apply filter on rows and update GUI
function LA:FilterRows(text)
    scrollFrame:SetVerticalScroll(0)
    self:SetFilter(text)
    self:UpdateRows()
    self:RedrawRows()
end

-- Handler for mouse clicks on item rows
function LA:HandleItemClick(itemMixin)
    if IsControlKeyDown() then
        DressUpItemLink(itemMixin:GetItemLink())
    elseif IsShiftKeyDown() then
        if ChatFrame1EditBox:IsVisible() then
            ChatFrame1EditBox:Insert(itemMixin:GetItemLink())
        end
    else
        SetItemRef(itemMixin:GetItemLink())
    end
end

-- Generate a create/update row frame
function LA:CreateEditRowFrame()
    editFrame = AceGUI:Create("Frame")
    editFrame:Hide()
    editFrame:EnableResize(false)
    editFrame:SetHeight(260)
    editFrame:SetWidth(320)

    local frameName = addonName .."_EditFrame"
	_G[frameName] = editFrame
	table.insert(UISpecialFrames, frameName) -- Allow ESC close
    editFrame:SetLayout("Flow")

    editItem = AceGUI:Create("EditBox")
    editItem:SetLabel(L["Item"])
    editItem:SetWidth(300)
    editItem:SetCallback("OnEnterPressed", function(widget, event, text)
        if (GetItemInfoInstant(text)) then
            self:EditOrSaveRow()
            return false
        else
            return true
        end
    end)
    editFrame:AddChild(editItem)

    editPlayer = AceGUI:Create("EditBox")
    editPlayer:SetLabel(L["Player"])
    editPlayer:SetWidth(300)
    editPlayer:SetCallback("OnEnterPressed", function(widget, event, text)
        if IsInRaid() or IsInGroup() then
            local name = self:GuessPlayerName(text)
            if name then
                widget:SetText(name)
            end
        end
        self:EditOrSaveRow()
    end)
    editFrame:AddChild(editPlayer)

    editReason = AceGUI:Create("EditBox")
    editReason:SetLabel(L["Reason"])
    editReason:SetWidth(300)
    editReason:SetCallback("OnEnterPressed", function() self:EditOrSaveRow() end)
    editFrame:AddChild(editReason)

    editDate = AceGUI:Create("EditBox")
    editDate:SetLabel(L["Date"])
    editDate:SetWidth(300)
    editDate:SetDisabled(true)
    editFrame:AddChild(editDate)
end

-- Setup editFrame for edit mode and display it
function LA:ShowEditRowFrame(row)
    if not editFrame then
        self:CreateEditRowFrame()
    end

    editMode = row
    editFrame:SetTitle(L["Edit loot"])
    self:GetItemMixin(row["id"], function(itemMixin)
        editItem:SetText(itemMixin:GetItemLink())
        editItem:SetDisabled(true)
        editPlayer:SetText(row["player"])
        editReason:SetText(row["reason"])
        editDate:SetText(date(L["%F %T"], row["date"]))
        editFrame:Show()
    end)
end

-- Setup editFrame for create mode and display it
function LA:ShowCreateRowFrame()
    if not editFrame then
        self:CreateEditRowFrame()
    end

    editMode = false
    editFrame:SetTitle(L["Add loot"])
    editItem:SetText("")
    editItem:SetDisabled(false)
    editPlayer:SetText("")
    editReason:SetText("")
    editDate:SetText()
    editFrame:Show()
end

-- Apply changes from editFrame
function LA:EditOrSaveRow()
    if editItem:GetText() == "" or editPlayer:GetText() == "" then
        return
    end

    self:GetItemMixin(editItem:GetText(), function(itemMixin)
        if editMode then
            self:UpdateLootAwarded(itemMixin, editPlayer:GetText(), editReason:GetText(), editMode["date"])
        else
            local row = self:StoreLootAwarded(itemMixin, editPlayer:GetText(), editReason:GetText())
            if row then
                self:ShowEditRowFrame(row)
            else
                editFrame:Hide()
            end
        end
    end)
end

-- Row delete confirmation popup frame
function LA:ConfirmDeleteRow(row)
    StaticPopupDialogs[addonName.."_DeleteConfirm"] = {
        text = L["Are you sure you want to delete this row ?"],
        button1 = YES,
        button2 = NO,
        timeout = 0,
        OnAccept = function()
            self:GetItemMixin(row["id"], function(itemMixin)
                self:DeleteLootAwarded(itemMixin, row["player"], row["reason"], row["date"])
            end)
        end,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(addonName.."_DeleteConfirm")
end
