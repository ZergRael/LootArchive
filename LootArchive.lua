local addonName = "LootArchive"
local addonTitle = select(2, GetAddOnInfo(addonName))
local LA = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local libDBIcon = LibStub("LibDBIcon-1.0")

function LA:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(addonName, {
        profile = {
            minimapButton = {
                hide = false,
            },
            maxHistory = 0,
        },
        factionrealm = {
            history = {},
        },
    })

    self:RegisterEvent("LOOT_OPENED")

	self:DrawMinimapIcon()
    self:RegisterOptionsTable()
end

function LA:LOOT_OPENED(eventName)
    self:Print("LOOT_OPENED")
end

function LA:ResetDatabase()
    self.db:ResetDB()
    self:Print(L["Database reset"])
end

function LA:DrawMinimapIcon()
	libDBIcon:Register(addonName, LibStub("LibDataBroker-1.1"):NewDataObject(addonName,
	{
		type = "data source",
		text = addonName,
        icon = "interface/icons/inv_misc_key_02",
		OnClick = function(self, button)
			if (button == "RightButton") then
                InterfaceOptionsFrame_OpenToCategory(addonName)
                InterfaceOptionsFrame_OpenToCategory(addonName)
            else
                LA:ToggleGUI()
            end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(string.format("%s |cff777777v%s|r", addonTitle, "@project-version@"))
			tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Left Click"], L["to open the main window"]))
			tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Right Click"], L["to open options"]))
			tooltip:AddLine(string.format("|cFFCFCFCF%s|r %s", L["Drag"], L["to move this button"]))
		end
    }), self.db.profile.minimapButton)
end

function LA:ToggleMinimapButton()
    self.db.profile.minimapButton.hide = not self.db.profile.minimapButton.hide
    if self.db.profile.minimapButton.hide then
        libDBIcon:Hide(addonName)
    else
        libDBIcon:Show(addonName)
    end
end

function LA:GenerateRows(sortColumn)
    -- self:Print("Rebuilding data table")
    local tbl = {}
    local selectedGuild = ""

    if not self.db.factionrealm.history[selectedGuild] then
        return tbl
    end

    for _, row in ipairs(self.db.factionrealm.history[selectedGuild]) do

        table.insert(tbl, {
            
        })
    end

    if sortColumn then
        if self.sortColumn == sortColumn then
            self.sortOrder = not self.sortOrder
        else
            self.sortColumn = sortColumn
            self.sortOrder = true
        end
    end

    table.sort(tbl, function(a, b)
        if self.sortOrder then
            return a[self.sortColumn] > b[self.sortColumn]
        else
            return b[self.sortColumn] > a[self.sortColumn]
        end
    end)

    return tbl
end

function LA:OptimizeDatabase()
    
end
