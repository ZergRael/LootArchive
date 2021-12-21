local addonName = "LootArchive"
local addonTitle = select(2, GetAddOnInfo(addonName))
local addonVersion = GetAddOnMetadata(addonName, "Version")
local LA = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceComm-3.0", "AceSerializer-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addonName, true)
local libDBIcon = LibStub("LibDBIcon-1.0")

local syncThresholdSeconds = 100

-- Addon init
function LA:OnInitialize()
    -- Addon savedvariables database
    self.db = LibStub("AceDB-3.0"):New(addonName, {
        profile = {
            minimapButton = {
                hide = false,
            },
            announceTo = "RAID_WARNING",
            callLootStr = L["Roll for %s"],
            awardStr = L["%s awarded to %s"],
            maxHistory = 300,
        },
        factionrealm = {
            history = {},
            timestamp = {},
        },
    })

    -- Addon session variables
    self.currentGuild = nil
    self.currentGuildRank = nil
    self.trackedItem = nil
    self.gui = {
        sortColumn = "date",
        sortOrder = true,
        filter = nil,
    }
    self.requestSyncBucket = {}
    self.requestSyncTimer = nil

    -- This is not usable at this point in login
    -- we need to wait for PLAYER_GUILD_UPDATE to fetch guild info
    -- this call is still useful in case of /reload
    self:FetchCurrentGuild()

    -- Events register
    -- self:RegisterEvent("LOOT_OPENED")
    -- self:RegisterEvent("CHAT_MSG_LOOT")
    -- self:RegisterEvent("OPEN_MASTER_LOOT_LIST")
    self:RegisterEvent("PLAYER_GUILD_UPDATE")

    -- Hooks
    self:Hook("GiveMasterLoot", true)

    -- Comms
    self:RegisterComm(addonName.."_REQ", "ReceiveRequestSyncDB")
    self:RegisterComm(addonName.."_BULK", "ReceiveSyncDB")
    self:RegisterComm(addonName.."_LIVE", "ReceiveLiveSync")

    -- GUI and options init
	self:DrawMinimapIcon()
    self:RegisterOptionsTable()
end

-- EVENT HANDLERS
-- This could be used to trigger something in raids
-- probably useless but I like this event
function LA:LOOT_OPENED(eventName)
    -- self:Print("DEBUG:LOOT_OPENED")
end

-- Required to get player current guild after login
function LA:PLAYER_GUILD_UPDATE(eventName, unitTarget)
    -- self:Print("PLAYER_GUILD_UPDATE", unitTarget)
    if unitTarget == "player" then
        self:FetchCurrentGuild()
    end
end

-- This is spammy
function LA:CHAT_MSG_LOOT(eventName)
    -- self:Print("DEBUG:CHAT_MSG_LOOT")
end

-- Probably not needed
function LA:OPEN_MASTER_LOOT_LIST(eventName)
    -- self:Print("DEBUG:OPEN_MASTER_LOOT_LIST")
end

-- Hook on ML distribution to ease recording
function LA:GiveMasterLoot(slotId, candidateId, ...)
    local candidate = tostring(GetMasterLootCandidate(candidateId))
    local itemLink = tostring(GetLootSlotLink(slotId))
    self:Print("DEBUG:GiveMasterLoot", itemLink, candidate)

    self:GetItemMixin(itemLink, function(itemMixin)
        if not self:Award(itemMixin, candidate) then
            self:Print(L["Cannot store award in database right now, please reload and try again"])
        end
    end)
end

-- Async function to retrieve itemMixin from item id or link
function LA:GetItemMixin(itemIdOrLink, callbackFn)
    if not itemIdOrLink or not callbackFn then
        return
    end

    -- Get real ID
    local id = GetItemInfoInstant(itemIdOrLink)
    if not id then
        -- self:Print("This does not seem to be a known valid item : ", itemIdOrLink)
        return
    end

    if tostring(id) == tostring(itemIdOrLink) then
        -- self:Print("This seems to be an item id : ", itemIdOrLink)
        local itemMixin = Item:CreateFromItemID(itemIdOrLink)
        itemMixin:ContinueOnItemLoad(function()
            callbackFn(itemMixin)
        end)
    else
        -- self:Print("This seems to be an item link : ", itemIdOrLink)
        local itemMixin = Item:CreateFromItemLink(itemIdOrLink)
        itemMixin:ContinueOnItemLoad(function()
            callbackFn(itemMixin)
        end)
    end
end

-- Start tracking item from console item link
function LA:AddFromConsole(itemIdOrLink)
    -- self:Print("AddFromConsole", itemIdOrLink)
    if not itemIdOrLink then
        return
    end

    self:GetItemMixin(itemIdOrLink, function(itemMixin)
        LA:TrackItem(itemMixin)
    end)
end

-- Announce and start tracking item for later award process
function LA:TrackItem(itemMixin)
    -- self:Print("TrackItem", itemMixin:GetItemName())

    local itemLink = itemMixin:GetItemLink()

    -- Announce
    self:Announce(format(self.db.profile.callLootStr, itemLink))

    -- Store id for manual distribution
    self.trackedItem = itemMixin
end

-- Award item to player, based on args and self.trackedItem
function LA:GiveFromConsole(itemIdOrLinkOrPlayerName, exact)
    -- self:Print("GiveFromConsole", itemIdOrLinkOrPlayerName)

    local itemIdOrLink, playerName, reason
    -- Match first item
    local link = strmatch(itemIdOrLinkOrPlayerName, "(|c[^|]+|H[^|]+|h[^|]+|h|r)")
    if link then
        local id = GetItemInfoInstant(link)
        if id then
            itemIdOrLink = id
            itemIdOrLinkOrPlayerName = self:StrRemove(itemIdOrLinkOrPlayerName, link)
        end
    end
    -- if there's no item link, there may be an itemID
    -- but we need to make sure it's a just an integer
    if not itemIdOrLink then
        local mid = strmatch(itemIdOrLinkOrPlayerName, "^(%d+) ") or strmatch(itemIdOrLinkOrPlayerName, " (%d+)$") or strmatch(itemIdOrLinkOrPlayerName, " (%d+) ")
        if mid then
            local id = GetItemInfoInstant(mid)
            if id then
                itemIdOrLink = id
                itemIdOrLinkOrPlayerName = self:StrRemove(itemIdOrLinkOrPlayerName, id)
            end
        end
    end

    if not itemIdOrLink then
        if self.trackedItem then
            itemIdOrLink = self.trackedItem:GetItemID()
        else
            self:Print(L["No currently tracked item"])
            return
        end
    end

    -- At this point we're sure the next arg must be playerName
    local name = strmatch(itemIdOrLinkOrPlayerName, "^(%a+)")
    if not name then
        self:Print(L["No player found"])
        return
    end

    itemIdOrLinkOrPlayerName = self:StrRemove(itemIdOrLinkOrPlayerName, name)

    if exact then
        playerName = name
    else
        playerName = self:GuessPlayerName(name)
    end

    if not playerName then
        self:Print(L["No player found"])
        return
    end

    reason = itemIdOrLinkOrPlayerName

    -- self:Print(itemIdOrLink, playerName, reason)
    self:GetItemMixin(itemIdOrLink, function(itemMixin)
        if self:Award(itemMixin, playerName, reason) then
            if self.trackedItem and self.trackedItem:GetItemID() == itemMixin:GetItemID() then
                self.trackedItem = nil
            end
        else
            self:Print(L["Cannot store award in database right now, please reload and try again"])
        end
    end)
end

-- Announce and store valid item distribution
function LA:Award(itemMixin, playerName, reason)
    -- TODO : Should we also announce reason ?
    if self:StoreLootAwarded(itemMixin, playerName, reason) then
        self:Announce(format(self.db.profile.awardStr, itemMixin:GetItemLink(), playerName))
        return true
    end

    return false
end

-- Guess proper playername from current raid roster based on slug
-- may need to keep a daily cache of known playernames
function LA:GuessPlayerName(playerName)
    -- self:Print("GuessPlayerName", playerName)
    if not playerName then
        return
    end

    local playerSlug = self:ToSlug(playerName)

    local roster = {}
    if IsInRaid() then
        for i = 1, MAX_RAID_MEMBERS do
            local name = GetRaidRosterInfo(i)
            if name ~= nil then
                tinsert(roster, {name = name, slug = self:ToSlug(name), stripped = self:StripAccents(name)})
            end
        end
    elseif IsInGroup() then
        local group = GetHomePartyInfo()
        for _, name in ipairs(group) do
            if name ~= nil then
                tinsert(roster, {name = name, slug = self:ToSlug(name), stripped = self:StripAccents(name)})
            end
        end
    else
        self:Print(L["Not in group or raid, cannot match player name"])
        return
    end

    -- self:PrintTable(roster)

    -- Perfect match
    for _, unit in ipairs(roster) do
        if unit["slug"] == playerSlug then
            -- self:Print("Perfect match", unit["name"])
            return unit["name"]
        end
    end

    -- Contains
    for _, unit in ipairs(roster) do
        if strfind(unit["slug"], playerSlug) then
            -- self:Print("Match contains", unit["name"])
            return unit["name"]
        end
    end

    -- Strip accents
    for _, unit in ipairs(roster) do
        if strfind(unit["stripped"], playerSlug) then
            -- self:Print("Match stripped", unit["name"])
            return unit["name"]
        end
    end

    self:Print("Failed to match", playerName)
    return nil
end

-- Send to raid/group
function LA:Announce(str)
    if self.db.profile.announceTo then
        self:Print(str)
        return
    end

    if IsInRaid() then
        if self.db.profile.announceTo == "RAID_WARNING" then
            if (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
                SendChatMessage(str, self.db.profile.announceTo)
            else
                -- self:Print("Using raid channel as you are not raid leader / assistant")
                SendChatMessage(str, "RAID")
            end
        elseif self.db.profile.announceTo == "RAID" then
            SendChatMessage(str, self.db.profile.announceTo)
        end
    elseif IsInGroup() then
        if self.db.profile.announceTo == "RAID_WARNING" then
            SendChatMessage(str, self.db.profile.announceTo)
        elseif self.db.profile.announceTo == "RAID" then
            SendChatMessage(str, "PARTY")
        end
    else
        self:Print("Not in raid/group, cannot announce", str)
    end
end

-- Store item distribution in database
function LA:StoreLootAwarded(itemMixin, playerName, reason)
    local now = time()
    local loot = {
        id = itemMixin:GetItemID(),
        item = strlower(itemMixin:GetItemName()), -- TODO: Don't store this
        player = playerName,
        reason = reason,
        date = now
    }

    if not self:CreateDatabaseIfNecessary() then
        return false
    end

    tinsert(self.db.factionrealm.history[self.currentGuild].loots, loot)
    self.db.factionrealm.history[self.currentGuild].timestamp = now
    self:LiveSync(loot, "ADD")

    if self:IsGUIVisible() then
        self:UpdateRows()
        self:RedrawRows()
    end

    return true
end

-- Store current guild name & player rank
function LA:FetchCurrentGuild()
    if not IsInGuild() then
        return
    end

    local guildName, guildRankName = GetGuildInfo("player")
    if not guildName then
        return
    end

    self.currentGuild = guildName
    self.currentGuildRank = guildRankName

    self:RequestDBSync()
end

-- Send guild broadcast database sync request
function LA:RequestDBSync()
    if not self.currentGuild then
        return
    end
    -- self:Print("DEBUG:RequestDBSync")

    local timestamp = 0
    if self.db.factionrealm.history[self.currentGuild] then
        timestamp = self.db.factionrealm.history[self.currentGuild].timestamp
    end
    local msg = {state = "REQUEST", timestamp = timestamp}
    self:SendCommMessage(addonName.."_REQ", self:Serialize(msg), "GUILD")
end

-- Receive database sync request
function LA:ReceiveRequestSyncDB(prefix, msg, channel, sender)
    -- self:Print("DEBUG:ReceiveRequestSyncDB", prefix, msg, channel, sender)

    if sender == UnitName("player") then
        return
    end

    if channel == "GUILD" then
        -- This is a post-login _REQ, just answer with our own timestamp
        if self.db.factionrealm.history[self.currentGuild] then
            self:SendCommMessage(addonName.."_REQ", self:Serialize({state = "OFFER", timestamp = self.db.factionrealm.history[self.currentGuild].timestamp}), "WHISPER", sender)
        end

        return
    end

    local success, data = self:Deserialize(msg)
    if not success then
        -- Ignore garbled data
        return
    end

    if data["state"] == "OFFER" then
        tinsert(self.requestSyncBucket, { sender = sender, timestamp = data["timestamp"] })

        -- Wait for a few seconds and process offers
        if not self.requestSyncTimer then
            self.requestSyncTimer = self:ScheduleTimer("ProcessSyncDBOffers", 10)
        end
    elseif data["state"] == "ACCEPT" then
        self:SyncDB(sender)
    end
end

-- Process bucketed sync database offers
function LA:ProcessSyncDBOffers()
    -- self:Print("DEBUG:ProcessSyncDBOffers")
    self.requestSyncTimer = nil

    local sender, mostRecentTimestamp = nil, 0
    for i,v in ipairs(self.requestSyncBucket) do
        if v["timestamp"] > mostRecentTimestamp then
            sender = v["sender"]
            mostRecentTimestamp = v["timestamp"]
        end
    end
    self.requestSyncBucket = {}

    if sender then
        -- Only send data if our timestamp is too old
        if self.db.factionrealm.history[self.currentGuild] then
            local diff = abs(self.db.factionrealm.history[self.currentGuild].timestamp - mostRecentTimestamp)
            if diff < syncThresholdSeconds then
                -- self:Print("DEBUG:ProcessSyncDBOffers: No recent offers, bail")
                return
            end
        end

        -- self:Print("DEBUG:ProcessSyncDBOffers: Accept offer from", sender)
        self:SendCommMessage(addonName.."_REQ", self:Serialize({state = "ACCEPT"}), "WHISPER", sender)
    end
end

-- Trigger database sync with other guild members
function LA:SyncDB(playerName)
    -- self:Print("DEBUG:SyncDB", playerName)
    self:SendCommMessage(addonName.."_BULK", self:Serialize(self.db.factionrealm.history[self.currentGuild]), "WHISPER", playerName, "BULK")
end

-- Receive DB contents
function LA:ReceiveSyncDB(prefix, msg, channel, sender)
    -- self:Print("DEBUG:ReceiveSyncDB", prefix, channel, sender)

    local success, data = self:Deserialize(msg)
    if not success then
        -- self:Print("DEBUG:Failed to deserialize bulk data")
        return
    end

    self.db.factionrealm.history[self.currentGuild] = data

    if self:IsGUIVisible() then
        self:UpdateRows()
        self:RedrawRows()
    end
end

-- Send live distribution addition / removal
function LA:LiveSync(loot, state)
    -- self:Print("DEBUG:LiveSync", loot, state)

    loot["state"] = state
    self:SendCommMessage(addonName.."_LIVE", self:Serialize(loot), "GUILD")
end

-- Receive live distribution addition / removal
function LA:ReceiveLiveSync(prefix, msg, channel, sender)
    -- self:Print("DEBUG:ReceiveLiveSync", prefix, msg, channel, sender)

    if sender == UnitName("player") then
        return
    end

    local success, loot = self:Deserialize(msg)
    if not success then
        -- self:Print("DEBUG:Failed to deserialize bulk data")
        return
    end

    local state = loot["state"]
    loot["state"] = nil
    
    if not self:CreateDatabaseIfNecessary() then
        self:Print(L["Cannot live sync database now, please try a manual sync later"])
        return
    end

    if state == "ADD" then
        tinsert(self.db.factionrealm.history[self.currentGuild].loots, loot)
        -- We can assume this loot timestamp is the most recent, keep it as is
        self.db.factionrealm.history[self.currentGuild].timestamp = loot["date"]
    end

    if self:IsGUIVisible() then
        self:UpdateRows()
        self:RedrawRows()
    end
end

-- Create empty database if necessary before add/remove operations
function LA:CreateDatabaseIfNecessary()
    if not self.currentGuild then
        return false
    end

    if not self.db.factionrealm.history[self.currentGuild] then
        self.db.factionrealm.history[self.currentGuild] = {}
        self.db.factionrealm.history[self.currentGuild].loots = {}
        self.db.factionrealm.history[self.currentGuild].timestamp = nil
    end

    return true
end

-- Reset entire database
function LA:ResetDatabase()
    self.db:ResetDB()
    self:Print(L["Database reset"])

    if self:IsGUIVisible() then
        self:UpdateRows()
        self:RedrawRows()
    end
end

-- Draw minimap icons and bind buttons
function LA:DrawMinimapIcon()
	libDBIcon:Register(addonName, LibStub("LibDataBroker-1.1"):NewDataObject(addonName,
	{
		type = "data source",
		text = addonName,
        icon = "interface/icons/inv_misc_ornatebox",
		OnClick = function(self, button)
			if (button == "RightButton") then
                InterfaceOptionsFrame_OpenToCategory(addonName)
                InterfaceOptionsFrame_OpenToCategory(addonName)
            else
                LA:ToggleGUI()
            end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine(string.format("%s |cff777777v%s|r", addonTitle, addonVersion))
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

-- Set sort for next GUI redraw
function LA:SetSort(sortColumn)
    if sortColumn then
        if self.gui.sortColumn == sortColumn then
            self.gui.sortOrder = not self.gui.sortOrder
        else
            self.gui.sortColumn = sortColumn
            self.gui.sortOrder = true
        end
    end
end

-- Set filter for next GUI redraw
function LA:SetFilter(text)
    self.gui.filter = text or nil
end

-- Generate filtered and sorted row for GUI
function LA:GenerateRows(sortColumn, filter)
    -- self:Print("Rebuilding data table")
    local tbl = {}

    if not self.db.factionrealm.history[self.currentGuild] then
        return tbl
    end

    local filter = nil
    if self.gui.filter then
        filter = strlower(self.gui.filter)
    end

    for _, row in ipairs(self.db.factionrealm.history[self.currentGuild].loots) do
        if not filter or strfind(row["item"], filter) or strfind(strlower(row["player"]), filter) then
            table.insert(tbl, row)
        end
    end

    table.sort(tbl, function(a, b)
        if self.gui.sortOrder then
            return a[self.gui.sortColumn] > b[self.gui.sortColumn]
        else
            return b[self.gui.sortColumn] > a[self.gui.sortColumn]
        end
    end)

    return tbl
end

-- Various database optimizations
function LA:OptimizeDatabase()
    self:CleanupDatabase()
end

-- Remove overflowing database records
function LA:CleanupDatabase()
    if self.db.profile.maxHistory == 0 then
        return
    end

    local count = #self.db.factionrealm.history[self.currentGuild].loots
    if count > self.db.profile.maxHistory then
        removemulti(self.db.factionrealm.history[self.currentGuild].loots, self.db.profile.maxHistory, count - self.db.profile.maxHistory)

        if self:IsGUIVisible() then
            self:UpdateRows()
            self:RedrawRows()
        end
    end
end

-- Export database as CSV
function LA:ExportDatabase()
    if not self.currentGuild then
        return
    end

    local str = "ID,Item,Player,Reason,Date\r\n"
    for i,v in ipairs(self.db.factionrealm.history[self.currentGuild].loots) do
        str = str..strjoin(",", v["id"], v["item"], v["player"], v["reason"], date("%F %T", v["date"])).."\r\n"
    end

    StaticPopupDialogs[addonName.."_Popup"] = {
        text = "Copy and paste this as a CSV file.",
        button1 = OKAY,
        hasEditBox = true,
        OnShow = function (self)
            self.editBox:SetText(str)
            self.editBox:HighlightText()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopup_Show(addonName.."_Popup")
end
