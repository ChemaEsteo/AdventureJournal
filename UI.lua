-- UI.lua: the book window.
--
-- T3: the look is Chema's (his AdventureJournal.lua at fa20e9f), for everyone: a dark frame with a
-- gold title, an index of jornadas on the left, and a page with Textures\tiled.tga on the right
-- (day title, date line, entries in QuestFont with red place headers). Sizes, positions, colours and
-- fonts below are his. This line's engine stays underneath: the ScrollBox index with its button
-- fallback, the conversations view, the demo diary, Escape to close.
-- Controls his design does not have (decision D4, flagged for his review):
--   previous / next jornada and the page number   in the title bar, left of the close button
--   conversations toggle and its paging           on the day title row of the page (only while on)
--   time (and the mood, with showProfile)          a muted prefix on each entry
local addonName, ns = ...

local journalFrame
ns.selectedDay = 1

-- M4b: the book shows either the events of a jornada or its conversations, as two tabs on the page.
-- The conversations tab is always there; while the option is off it only says so, and no conversation
-- text is ever put on screen (what was stored stays in the file).
-- Each event paragraph has a pencil icon that opens the edit window (Edits.lua): the player can rewrite
-- the sentence and add a description. The demo diary is read-only, so it has no icons.
ns.bookView = "events"        -- "events" | "conversations"
ns.conversationPage = 1

local function CurrentView()
    if ns.bookView == "conversations" then return "conversations" end
    return "events"
end

-- The diary the book shows: the real one, unless `/diario debug demo` swapped in a generated
-- one (ns.demoDB). The demo exists only in memory and is never written to SavedVariables;
-- entries still go into the real diary. It lets the index be tried with 250 jornadas.
local function ViewDB()
    return ns.demoDB or ns.EnsureDatabase()
end

-- Chema's colours.
local FONT_COLOR = {
    title = { 0.95, 0.82, 0.52 },
    heading = { 0.25, 0.14, 0.02 },
    metadata = { 0.40, 0.30, 0.20 },
    body = { 0.18, 0.12, 0.06 },
    secondary = { 0.75, 0.75, 0.75 },
}
local HEADER_COLOR = "|cFFFF3333"      -- red place headers
local TIME_COLOR = "|cFF8A5A24"        -- muted prefix (time, mood)

local function SetColor(fontString, color)
    if fontString and color then fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
end

local function CreateText(parent, template, value, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetText(value or "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    if width then fs:SetWidth(width) end
    if fs.SetWordWrap then fs:SetWordWrap(true) end
    return fs
end

local function CreateBookButton(parent, label, width, height, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(label)
    button:SetScript("OnClick", callback)
    return button
end

-- A backdrop can fail on a client without BackdropTemplate; the book is still usable without it.
local function SafeBackdrop(frame, settings, r, g, b, a)
    if not frame or not frame.SetBackdrop then return end
    pcall(function()
        frame:SetBackdrop(settings)
        if r then frame:SetBackdropColor(r, g, b, a or 1) end
    end)
end

local function CreatePanel(parent, width, height)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    SafeBackdrop(frame, {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }, 0.08, 0.05, 0.04, 0.95)
    return frame
end

-- Jornada index (left panel) -----------------------------------------------------------
-- Preferred: a ScrollBox, which only creates frames for the rows on screen, so 250+
-- jornadas cost the same as 10. Fallback: the original ScrollFrame with one Button per
-- jornada. The ScrollBox is used only if the functions AND the templates exist and the
-- whole build succeeds (M5: "the function exists" does not mean "the template exists").
-- A row is Chema's: a 195 x 24 button "Jornada N" and, under it, "lugar · fecha"; 48 px per row.
local BUTTON_WIDTH, BUTTON_HEIGHT, ROW_STEP = 195, 24, 48

-- Chema's index line: the main place of the jornada (his diaries store it), else the place of the
-- first entry, else "Aventura"; then the date.
local function DaySubtitle(dayNumber)
    local day = ViewDB().days[dayNumber]
    day = type(day) == "table" and day or {}
    local events = type(day.events) == "table" and day.events or {}
    local place = day.mainZone
    if type(place) ~= "string" or place == "" then
        place = type(events[1]) == "table" and events[1].place or nil
    end
    if type(place) ~= "string" or place == "" then place = "Aventura" end
    return string.format("%s  ·  %s", place, tostring(day.dateLabel or "Fecha desconocida"))
end

-- Fills one index row (a ScrollBox element or a fallback button). The subtitle FontString is
-- added the first time the row is used and hangs under the button, in the space the view leaves.
local function FillIndexRow(button, dayNumber)
    button:SetText(string.format("Jornada %d", dayNumber))
    if not button.subtitle then
        local subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        subtitle:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 4, -3)
        subtitle:SetWidth(BUTTON_WIDTH - 5)
        subtitle:SetJustifyH("LEFT")
        subtitle:SetJustifyV("TOP")
        SetColor(subtitle, FONT_COLOR.secondary)
        button.subtitle = subtitle
    end
    button.subtitle:SetText(DaySubtitle(dayNumber))
    button:SetScript("OnClick", function() ns.SelectDay(dayNumber) end)
end

-- Raises if anything is missing; the half-built frames are hidden first.
local function BuildScrollBoxIndex(f, leftPanel)
    if not (CreateScrollBoxListLinearView and CreateDataProvider and ScrollUtil
            and ScrollUtil.InitScrollBoxListWithScrollBar) then
        error("faltan las funciones de ScrollBox", 0)
    end
    local holder = CreateFrame("Frame", nil, leftPanel)
    holder:SetPoint("TOPLEFT", 8, -8)
    holder:SetPoint("BOTTOMRIGHT", -8, 8)
    local box
    local ok, err = pcall(function()
        box = CreateFrame("Frame", nil, holder, "WowScrollBoxList")
        box:SetPoint("TOPLEFT", 0, 0)
        box:SetPoint("BOTTOMRIGHT", -18, 0)
        local bar = CreateFrame("EventFrame", nil, holder, "MinimalScrollBar")
        bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)
        -- Rows are 24 px buttons with 24 px of spacing: 48 px per row, the subtitle in the gap.
        -- (UNVERIFIED on the clients: the spacing argument; see README, "Book".)
        local view = CreateScrollBoxListLinearView(0, 0, 0, 0, ROW_STEP - BUTTON_HEIGHT)
        if view.SetPadding then view:SetPadding(0, 0, 0, 0, ROW_STEP - BUTTON_HEIGHT) end
        view:SetElementExtent(BUTTON_HEIGHT)
        view:SetElementInitializer("UIPanelButtonTemplate", FillIndexRow)
        ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    end)
    if not ok then
        holder:Hide()
        error(err, 0)
    end
    f.indexBox, f.indexMode = box, "scrollbox"
end

-- The original index: a ScrollFrame whose child holds one Button per jornada.
local function BuildButtonIndex(f, leftPanel)
    local indexScroll = CreateFrame("ScrollFrame", nil, leftPanel, "UIPanelScrollFrameTemplate")
    indexScroll:SetPoint("TOPLEFT", 8, -8)
    indexScroll:SetPoint("BOTTOMRIGHT", -26, 8)
    local indexChild = CreateFrame("Frame", nil, indexScroll)
    indexChild:SetSize(BUTTON_WIDTH, 1)
    indexScroll:SetScrollChild(indexChild)
    f.indexChild, f.indexScroll, f.indexMode = indexChild, indexScroll, "buttons"
end

local function BuildIndex(f, leftPanel)
    if ns.debug.buttons then
        f.indexFallbackReason = "forzado con /diario debug buttons"
    else
        local ok, err = pcall(BuildScrollBoxIndex, f, leftPanel)
        if ok then return end
        f.indexFallbackReason = string.sub(ns.StripPosition(err), 1, 120)
        ns.Debug("índice: sin ScrollBox (%s), se usan botones", f.indexFallbackReason)
    end
    BuildButtonIndex(f, leftPanel)
end

local function RefreshScrollBoxIndex(f, total)
    local list = {}
    for dayNumber = total, 1, -1 do list[#list + 1] = dayNumber end
    local retain = ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition
    f.indexBox:SetDataProvider(CreateDataProvider(list), retain)
end

local function RefreshButtonIndex(f, total)
    local buttons = f.dayButtons or {}
    for _, button in pairs(buttons) do
        button:Hide()
        if button.subtitle then button.subtitle:Hide() end
    end
    local y = 0
    for dayNumber = total, 1, -1 do
        local button = buttons[dayNumber]
        if not button then
            button = CreateFrame("Button", nil, f.indexChild, "UIPanelButtonTemplate")
            button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
            buttons[dayNumber] = button
        end
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, y)
        FillIndexRow(button, dayNumber)
        button:Show()
        button.subtitle:Show()
        y = y - ROW_STEP
    end
    f.dayButtons = buttons
    f.indexChild:SetHeight(math.max(1, -y + 5))
end

-- A broken index must not take the right page with it: report the first error to
-- the game's error handler and carry on.
local indexErrorReported
local function RefreshIndex(f, total)
    local ok, err
    if f.indexMode == "scrollbox" then
        ok, err = pcall(RefreshScrollBoxIndex, f, total)
    else
        ok, err = pcall(RefreshButtonIndex, f, total)
    end
    if ok then return end
    ns.Debug("índice: %s", tostring(err))
    if indexErrorReported then return end
    indexErrorReported = true
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler("AdventureJournal: error al actualizar el índice: " .. tostring(err)) end
end

-- "ScrollBox" or "botones (reason)", for /diario diag.
function ns.GetIndexMode()
    if not journalFrame then return "el libro aún no se ha abierto" end
    if journalFrame.indexMode == "scrollbox" then return "ScrollBox" end
    return "botones (" .. tostring(journalFrame.indexFallbackReason) .. ")"
end

local function BuildUI()
    if journalFrame then return end

    -- Main frame: dark background, dialog border.
    local f = CreateFrame("Frame", "AdventureJournalBookFrame", UIParent, "BackdropTemplate")
    journalFrame = f
    f:SetSize(820, 560)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    if f.SetFrameLevel then f:SetFrameLevel(20) end
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not (InCombatLockdown and InCombatLockdown()) then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    local background = f:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetAllPoints(f)
    background:SetVertexColor(0.12, 0.08, 0.06, 0.98)
    f.mainBackground = background
    SafeBackdrop(f, {
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        edgeSize = 24,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    })

    -- Title and close button.
    local title = CreateText(f, "GameFontNormalLarge",
        "Diario de Aventura - " .. ns.SafeString(ns.UnitNameSafe("player"), "Aventurero"), 400)
    title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)
    SetColor(title, FONT_COLOR.title)
    f.title = title

    local close = CreateFrame("Button", nil, f)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    close:SetScript("OnClick", function() f:Hide() end)

    -- Previous / next jornada and the page number (not in Chema's design; D4): the title bar.
    local nextButton = CreateBookButton(f, "Siguiente >", 84, 24, function() ns.SelectDay(ns.selectedDay + 1) end)
    nextButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -46, -11)
    f.nextButton = nextButton
    local pageNumber = CreateText(f, "GameFontHighlightSmall", "", 56)
    pageNumber:SetPoint("RIGHT", nextButton, "LEFT", -6, 0)
    pageNumber:SetJustifyH("CENTER")
    SetColor(pageNumber, FONT_COLOR.title)
    f.pageNumber = pageNumber
    local previous = CreateBookButton(f, "< Anterior", 84, 24, function() ns.SelectDay(ns.selectedDay - 1) end)
    previous:SetPoint("RIGHT", pageNumber, "LEFT", -6, 0)
    f.prevButton = previous

    -- Delete the jornada being shown (Edits.lua asks first). Left of the previous / next buttons.
    local deleteButton = CreateBookButton(f, "Eliminar", 84, 24, function() ns.AskDeleteDay(ns.selectedDay) end)
    deleteButton:SetPoint("TOPLEFT", f, "TOPLEFT", 436, -11)
    f.deleteButton = deleteButton

    -- Left panel: the index of jornadas.
    local leftPanel = CreatePanel(f, 240, 495)
    leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 15, -45)
    f.leftPanel = leftPanel
    BuildIndex(f, leftPanel)

    -- Right page: tiled.tga with a tooltip border.
    local rightPage = CreateFrame("Frame", nil, f, "BackdropTemplate")
    rightPage:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    rightPage:SetSize(538, 495)
    SafeBackdrop(rightPage, {
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    local paper = rightPage:CreateTexture(nil, "BACKGROUND")
    paper:SetTexture("Interface\\AddOns\\AdventureJournal\\Textures\\tiled.tga")
    paper:SetAllPoints(rightPage)
    rightPage.pageBackground = paper
    f.rightPage = rightPage

    local dayTitle = CreateText(rightPage, "QuestTitleFont", "Jornada", 250)
    dayTitle:SetPoint("TOPLEFT", rightPage, "TOPLEFT", 20, -15)
    SetColor(dayTitle, FONT_COLOR.heading)
    f.dayTitle = dayTitle

    local dayMeta = CreateText(rightPage, "GameFontHighlightSmall", "", 490)
    dayMeta:SetPoint("TOPLEFT", dayTitle, "BOTTOMLEFT", 0, -4)
    SetColor(dayMeta, FONT_COLOR.metadata)
    f.dayMeta = dayMeta

    -- Tabs: the events of the jornada, or its conversations. The active tab is the disabled one.
    local tabConversations = CreateBookButton(rightPage, "Conversaciones", 104, 22, function() ns.SetBookView("conversations") end)
    tabConversations:SetPoint("TOPRIGHT", rightPage, "TOPRIGHT", -14, -14)
    f.tabConversations = tabConversations
    local tabEvents = CreateBookButton(rightPage, "Acontecimientos", 112, 22, function() ns.SetBookView("events") end)
    tabEvents:SetPoint("RIGHT", tabConversations, "LEFT", -4, 0)
    f.tabEvents = tabEvents
    -- The pages of a long conversation list, under the tabs.
    local conversationNext = CreateBookButton(rightPage, "Después >", 62, 22, function() ns.SetConversationPage(ns.conversationPage + 1) end)
    conversationNext:SetPoint("TOPRIGHT", rightPage, "TOPRIGHT", -14, -40)
    conversationNext:Hide()
    f.conversationNext = conversationNext
    local conversationPageText = CreateText(rightPage, "GameFontHighlightSmall", "", 36)
    conversationPageText:SetPoint("RIGHT", conversationNext, "LEFT", -2, 0)
    conversationPageText:SetJustifyH("CENTER")
    SetColor(conversationPageText, FONT_COLOR.metadata)
    conversationPageText:Hide()
    f.conversationPageText = conversationPageText
    local conversationPrev = CreateBookButton(rightPage, "< Antes", 56, 22, function() ns.SetConversationPage(ns.conversationPage - 1) end)
    conversationPrev:SetPoint("RIGHT", conversationPageText, "LEFT", -2, 0)
    conversationPrev:Hide()
    f.conversationPrev = conversationPrev

    -- The entries.
    local contentScroll = CreateFrame("ScrollFrame", nil, rightPage, "UIPanelScrollFrameTemplate")
    contentScroll:SetPoint("TOPLEFT", rightPage, "TOPLEFT", 20, -68)
    contentScroll:SetPoint("BOTTOMRIGHT", rightPage, "BOTTOMRIGHT", -28, 15)
    local contentChild = CreateFrame("Frame", nil, contentScroll)
    contentChild:SetSize(470, 1)
    contentScroll:SetScrollChild(contentChild)
    -- `body` is the plain text of the page (every paragraph, separated by a blank line). It is not shown:
    -- the paragraphs are drawn one by one (ShowParagraphs) so each can have its edit icon. It is kept as
    -- the page's text for the test harness and diagnostics.
    local body = CreateText(contentChild, "QuestFont", "", 450)
    body:Hide()
    f.contentChild, f.contentScroll, f.body = contentChild, contentScroll, body
    f.rows = {}

    f:SetScript("OnShow", function() ns.RefreshUI() end)

    -- Side tabs on the right edge (the diary itself first; other addons add theirs). See the end of this file.
    if ns.BuildSideTabs then ns.BuildSideTabs(f) end

    -- Escape closes the book (bug #7).
    local alreadyRegistered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "AdventureJournalBookFrame" then alreadyRegistered = true end
    end
    if not alreadyRegistered then tinsert(UISpecialFrames, "AdventureJournalBookFrame") end

    -- CreateFrame returns a shown frame. Hide it so that ToggleUI's first call shows
    -- it instead of hiding it again (bug #8). OnShow refreshes the content.
    f:Hide()
end

function ns.SelectDay(dayNumber)
    local total = ViewDB().currentDay or 0
    if total < 1 then return end
    local chosen = math.max(1, math.min(total, tonumber(dayNumber) or total))
    if chosen ~= ns.selectedDay then ns.conversationPage = 1 end
    ns.selectedDay = chosen
    if journalFrame then ns.RefreshUI() end
end

function ns.SetBookView(view)
    ns.bookView = view == "conversations" and "conversations" or "events"
    ns.conversationPage = 1
    if journalFrame then ns.RefreshUI() end
end

function ns.SetConversationPage(page)
    ns.conversationPage = math.max(1, tonumber(page) or 1)
    if journalFrame then ns.RefreshUI() end
end

-- One entry as Chema writes it: a red header for entries that have one (places), "En <lugar>" on a
-- first entry without one, no header otherwise. The time (and the mood with showProfile) is a muted
-- prefix of the text: his design has none, this line keeps them (decision D4).
-- The first error of each kind goes to the game's error handler (visible with /console scriptErrors 1);
-- the page is drawn anyway, so one bad entry or a failing icon never blanks the book.
local reported = {}
local function ReportOnce(kind, err)
    ns.Debug("libro: %s: %s", kind, tostring(err))
    if reported[kind] and kind ~= "ventana de edición" then return end
    reported[kind] = true
    -- Also in the chat, so it can be read without /console scriptErrors 1.
    print("|cFFFF6060[Diario]|r error en el libro (" .. kind .. "): " .. tostring(err))
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler("AdventureJournal: error en el libro (" .. kind .. "): " .. tostring(err)) end
end

local NOTE_COLOR = "|cFF2A3F6B"        -- the description the player added under a sentence

local function EntryParagraph(day, index, entry, showProfile)
    local prose, header = entry.prose, entry.header
    if type(prose) ~= "string" or prose == "" then
        local composed, composedHeader = ns.ComposeEntry(entry)
        prose, header = composed, header or composedHeader
    end
    -- The player's own wording (Edits.lua) replaces the sentence; the generated one stays in the entry.
    local userText = type(entry.userText) == "string" and entry.userText ~= "" and entry.userText or nil
    local userNote = type(entry.userNote) == "string" and entry.userNote ~= "" and entry.userNote or nil
    if userText then prose = ns.EscapeUserText(userText) end
    if userNote then prose = prose .. "\n" .. NOTE_COLOR .. ns.EscapeUserText(userNote) .. "|r" end
    if type(header) ~= "string" or header == "" then header = nil end
    if index == 1 and not header then
        local place = type(entry.place) == "string" and entry.place ~= "" and entry.place
            or type(day.mainZone) == "string" and day.mainZone ~= "" and day.mainZone or "Azeroth"
        header = "En " .. place
    end
    local meta = type(entry.time) == "string" and entry.time or ""
    if showProfile and type(entry.characterProfile) == "string" and entry.characterProfile ~= "" then
        meta = meta == "" and entry.characterProfile or (meta .. "  ·  " .. entry.characterProfile)
    end
    if meta ~= "" then prose = TIME_COLOR .. meta .. "|r  " .. prose end
    if header then return string.format("%s%s|r\n%s", HEADER_COLOR, header, prose) end
    return prose
end

-- Paragraphs ---------------------------------------------------------------------------------------
-- One FontString per paragraph, chained one under the other, so the game does the layout and each paragraph
-- can have an edit icon. Rows are created on demand and reused (a jornada with 40 entries makes 40 rows once).
local ROW_TEXT_X, ROW_WIDTH, ROW_GAP, ICON_SIZE = 36, 418, 16, 16

local function GetRow(f, index)
    local row = f.rows[index]
    if row then return row end
    local fs = CreateText(f.contentChild, "QuestFont", "", ROW_WIDTH)
    SetColor(fs, FONT_COLOR.body)
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.3) end
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
    if fs.SetSpacing then fs:SetSpacing(4) end
    row = { fs = fs }
    f.rows[index] = row
    return row
end

-- The pencil icon is created the first time a row needs it. Its picture is Textures\edit.tga (ns.EDIT_ICON).
local function GetEditButton(f, row)
    if row.button then return row.button end
    local button = CreateFrame("Button", nil, f.contentChild)
    button:SetSize(ICON_SIZE, ICON_SIZE)
    -- Above the paragraph text, so nothing hides it.
    if button.SetFrameLevel and f.contentChild.GetFrameLevel then button:SetFrameLevel(f.contentChild:GetFrameLevel() + 5) end
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(button)
    icon:SetTexture(ns.EDIT_ICON)
    button.icon = icon
    -- A second, additive copy of the picture lights the icon under the mouse. Not essential.
    local ok, err = pcall(function()
        local highlight = button:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(button)
        highlight:SetTexture(ns.EDIT_ICON)
        highlight:SetBlendMode("ADD")
    end)
    if not ok then ns.Debug("libro: sin resalte en el icono: %s", tostring(err)) end
    button:SetScript("OnClick", function(self)
        local target = self.target
        if not target then return end
        local ok, result = pcall(ns.OpenEditDialog, target.day, target.index)
        if not ok then ReportOnce("ventana de edición", result)
        elseif not result then print("|cFFFF6060[Diario]|r no he encontrado esa anotación para editarla.") end
    end)
    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.edited and "Editar (ya tiene cambios tuyos)" or "Editar esta anotación")
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    row.button = button
    return button
end

-- Draws the paragraphs. targets[i] = { day = n, index = m } gives paragraph i an edit icon; a paragraph with
-- no target (conversations, messages, the demo diary) has none. Sets the scroll height.
local function ShowParagraphs(f, paragraphs, targets)
    local total, previous = 10, nil
    for i, text in ipairs(paragraphs) do
        local row = GetRow(f, i)
        local fs = row.fs
        fs:ClearAllPoints()
        if previous then
            fs:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -ROW_GAP)
            total = total + ROW_GAP
        else
            fs:SetPoint("TOPLEFT", f.contentChild, "TOPLEFT", ROW_TEXT_X, -10)
        end
        fs:SetText(text)
        fs:Show()
        total = total + (fs:GetStringHeight() or 0)
        previous = fs
        local target = targets and targets[i]
        if target then
            local ok, err = pcall(function()
                local button = GetEditButton(f, row)
                button.target = target
                button.edited = target.edited == true
                button:SetAlpha(button.edited and 1 or 0.55)
                button:ClearAllPoints()
                button:SetPoint("TOPRIGHT", fs, "TOPLEFT", -6, -2)
                button:Show()
            end)
            if not ok then ReportOnce("icono de edición", err) end
        elseif row.button then
            row.button.target = nil
            row.button:Hide()
        end
    end
    for i = #paragraphs + 1, #f.rows do
        local row = f.rows[i]
        row.fs:SetText("")
        row.fs:Hide()
        if row.button then row.button.target = nil; row.button:Hide() end
    end
    f.body:SetText(table.concat(paragraphs, "\n\n"))
    f.contentChild:SetHeight(math.max(100, total + 14))
    -- After an edit the page stays where it was; any other refresh starts at the top.
    local keep = f.keepScroll
    f.keepScroll = nil
    f.contentScroll:SetVerticalScroll(keep or 0)
end

-- Sets which tab looks active (the disabled one) and shows the conversation paging only where it belongs.
local function ShowTabs(f, view, pages)
    if view == "conversations" then
        f.tabConversations:Disable()
        f.tabEvents:Enable()
    else
        f.tabEvents:Disable()
        f.tabConversations:Enable()
    end
    if view == "conversations" and ns.ConversationsEnabled() and pages > 1 then
        f.conversationPrev:Show()
        f.conversationNext:Show()
        f.conversationPageText:Show()
        if ns.conversationPage <= 1 then f.conversationPrev:Disable() else f.conversationPrev:Enable() end
        if ns.conversationPage >= pages then f.conversationNext:Disable() else f.conversationNext:Enable() end
    else
        f.conversationPrev:Hide()
        f.conversationNext:Hide()
        f.conversationPageText:Hide()
    end
end

local function RefreshUIInner()
    if not journalFrame then return end
    local DB = ViewDB()
    local total = DB.currentDay or 0
    RefreshIndex(journalFrame, total)

    if total < 1 then
        journalFrame.dayTitle:SetText("Aún no hay jornadas")
        journalFrame.dayMeta:SetText("")
        ShowParagraphs(journalFrame, { "Tu historia comienza cuando salgas a explorar." })
        ShowTabs(journalFrame, "events", 1)
        journalFrame.pageNumber:SetText("Sin páginas")
        journalFrame.prevButton:Disable()
        journalFrame.nextButton:Disable()
        journalFrame.deleteButton:Disable()
        return
    end

    ns.selectedDay = math.max(1, math.min(total, ns.selectedDay))
    local day = DB.days[ns.selectedDay] or { events = {} }
    local events = day.events or {}
    local demoNote = ns.demoDB and "     ·     DATOS DE PRUEBA (no se guardan)" or ""
    journalFrame.dayTitle:SetText(string.format("Jornada %d", ns.selectedDay))
    journalFrame.dayMeta:SetText(string.format("%s     ·     %d acontecimientos%s", day.dateLabel or "Fecha desconocida", #events, demoNote))

    local view = CurrentView()
    local paragraphs, targets = {}, {}
    local pages = 1
    if view == "conversations" then
        journalFrame.dayMeta:SetText(string.format("%s     ·     %d conversaciones%s", day.dateLabel or "Fecha desconocida",
            ns.CountConversations(day), demoNote))
        if ns.ConversationsEnabled() then
            local page
            paragraphs, pages, page = ns.ConversationParagraphs(day, ns.conversationPage)
            ns.conversationPage = page
            journalFrame.conversationPageText:SetText(string.format("%d / %d", page, pages))
            if #paragraphs == 0 then
                paragraphs[1] = "No hay conversaciones guardadas en esta jornada."
            end
        else
            -- Nothing stored is shown while the option is off (what was saved stays in the file).
            paragraphs[1] = "El registro de conversaciones está desactivado. Actívalo con /diario conversaciones on "
                .. "o en Esc > Opciones > AddOns > Diario de Aventuras. Son palabras de otros jugadores, por eso no se guardan sin tu permiso."
        end
    elseif #events == 0 then
        paragraphs[1] = "No dejé constancia de grandes gestas durante esta jornada. Quizá fue un día de descanso, preparativos o caminos tranquilos. Incluso las pausas forman parte de una aventura."
    else
        local showProfile = ns.GetSetting("showProfile") == true
        for index, entry in ipairs(events) do
            local ok, text = pcall(EntryParagraph, day, index, entry, showProfile)
            if not ok then
                ReportOnce("anotación " .. index, text)
                text = "(No he podido mostrar esta anotación.)"
            end
            table.insert(paragraphs, text)
            -- The demo diary only exists in memory: it cannot be edited.
            if not ns.demoDB then
                targets[#paragraphs] = { day = ns.selectedDay, index = index, edited = ns.EntryIsEdited and ns.EntryIsEdited(entry) or false }
            end
        end
    end
    ShowParagraphs(journalFrame, paragraphs, targets)
    ShowTabs(journalFrame, view, pages)
    journalFrame.pageNumber:SetText(string.format("%d / %d", ns.selectedDay, total))
    -- Not the jornada in progress (the last one), and not the demo diary.
    if ns.demoDB or ns.selectedDay >= total then journalFrame.deleteButton:Disable() else journalFrame.deleteButton:Enable() end
    if ns.selectedDay <= 1 then journalFrame.prevButton:Disable() else journalFrame.prevButton:Enable() end
    if ns.selectedDay >= total then journalFrame.nextButton:Disable() else journalFrame.nextButton:Enable() end
end

function ns.RefreshUI()
    local ok, err = pcall(RefreshUIInner)
    if not ok then ReportOnce("RefreshUI", ns.StripPosition and ns.StripPosition(err) or err) end
end

-- Refreshes the page without jumping back to the top (used after an edit).
function ns.RefreshKeepingScroll()
    if not journalFrame then return end
    journalFrame.keepScroll = journalFrame.contentScroll:GetVerticalScroll()
    ns.RefreshIfVisible()
end

function ns.RefreshIfVisible()
    if journalFrame and journalFrame:IsShown() then ns.RefreshUI() end
end

function ns.ToggleUI()
    if not journalFrame then BuildUI() end
    if journalFrame:IsShown() then journalFrame:Hide() else journalFrame:Show() end
end

-- Opens the book at a given jornada (used by /diario hoy and /diario anterior).
function ns.OpenAtDay(dayNumber)
    if not journalFrame then BuildUI() end
    ns.SelectDay(dayNumber)
    journalFrame:Show()
end

-- ---------------------------------------------------------------------------------------------------
-- Side tabs.
-- The right edge of the book holds a stack of side tabs, styled like the tabs of the character window.
-- The first one is the diary itself and is always there. Other addons add their own tab to the stack
-- (so they share the space instead of each one placing a button on its own):
--
--   local index = AdventureJournalTabs.Add({
--       icon       = "Interface\\Icons\\Trade_Fishing",
--       tooltip    = "My tab",
--       onSelect   = function() ... end,   -- show your content (a child frame of the book is fine)
--       onDeselect = function() ... end,   -- hide it
--   })
--   AdventureJournalTabs.Select(index)     -- select a tab (1 = the diary)
--
-- A tab added before the book window exists is queued and created when the window is built.
-- ---------------------------------------------------------------------------------------------------
local sideTabs, queuedTabs = {}, {}

-- Same look as the character window's side tabs when they can be read; a plain icon button otherwise.
local function CreateSideTab(parent, iconPath)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(63, 63)
    btn.selTex, btn.hoverTex = {}, {}

    -- The icon goes first, in a child frame above the tab art, so nothing that fails or covers below
    -- can leave the tab without it.
    local holder = CreateFrame("Frame", nil, btn)
    holder:SetAllPoints(btn)
    holder:EnableMouse(false)
    local own = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    own:SetPoint("CENTER", holder, "CENTER", 0, 0)
    own:SetSize(34, 34)
    own:SetTexture(iconPath)
    btn.ownPath = tostring(iconPath)
    if not own:GetTexture() and type(iconPath) == "string" then
        own:SetTexture((iconPath:gsub("\\", "/"))) -- same path with forward slashes
    end
    btn.ownApplied = own:GetTexture() ~= nil
    own:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.ownIcon, btn.iconHolder = own, holder

    -- Tab art: copy the textures of the character window's side tab (each one on its own, so a
    -- failure in one does not stop the rest). Falls back to a plain dark square.
    local copied = 0
    local src = _G.CharacterFrameModeTab6
    if src and src.GetRegions then
        local w, h = src:GetSize()
        if w and w > 1 and h and h > 1 then btn:SetSize(w, h) end
        local map = {}
        for _, r in ipairs({ src:GetRegions() }) do
            local ok = pcall(function()
                if r:GetObjectType() == "MaskTexture" then return end -- the icon is drawn square, no mask needed
                local layer, sub = r:GetDrawLayer()
                local nr = btn:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
                map[r] = nr
                local atlas = r.GetAtlas and r:GetAtlas()
                if not atlas then nr:Hide() return end -- the source's own icon: not used
                nr:SetAtlas(atlas, false)
                pcall(function() nr:SetTexCoord(r:GetTexCoord()) end)
                if r:GetNumPoints() == 0 then
                    nr:SetAllPoints(btn)
                else
                    for i = 1, r:GetNumPoints() do
                        local p, rel, rp, x, y = r:GetPoint(i)
                        local target = (rel == nil or rel == src) and btn or map[rel] or btn
                        nr:SetPoint(p, target, rp or p, x or 0, y or 0)
                    end
                end
                local rw, rh = r:GetSize()
                if rw and rw > 0 and rh and rh > 0 then nr:SetSize(rw, rh) end
                pcall(function() nr:SetBlendMode(r:GetBlendMode()) end)
                pcall(function() nr:SetVertexColor(r:GetVertexColor()) end)
                nr:SetAlpha(r:GetAlpha())
                nr:SetShown(r:IsShown())
                if atlas:find("selected") then btn.selTex[#btn.selTex + 1] = nr; nr:Hide()
                elseif atlas:find("hover") then btn.hoverTex[#btn.hoverTex + 1] = nr; nr:Hide() end
                copied = copied + 1
            end)
            if not ok then map[r] = nil end
        end
    end
    if copied == 0 or #btn.selTex == 0 then
        local back = btn:CreateTexture(nil, "BACKGROUND")
        back:SetAllPoints(); back:SetColorTexture(0.08, 0.06, 0.04, 0.95)
        local sel = btn:CreateTexture(nil, "BORDER")
        sel:SetAllPoints(); sel:SetColorTexture(1, 0.82, 0, 0.3); sel:Hide()
        local hov = btn:CreateTexture(nil, "BORDER")
        hov:SetAllPoints(); hov:SetColorTexture(1, 1, 1, 0.15); hov:Hide()
        btn.selTex[#btn.selTex + 1] = sel
        btn.hoverTex[#btn.hoverTex + 1] = hov
    end

    btn:SetFrameLevel(parent:GetFrameLevel() + 10)
    holder:SetFrameLevel(btn:GetFrameLevel() + 5)
    function btn:SetSelected(on)
        for _, t in ipairs(self.selTex) do t:SetShown(on) end
    end
    return btn
end

local function SelectSideTabCore(index)
    for i, t in ipairs(sideTabs) do
        if i == index then
            t.btn:SetSelected(true)
            if i > 1 and not t.selected and t.spec.onSelect then pcall(t.spec.onSelect) end
            t.selected = true
        else
            t.btn:SetSelected(false)
            if t.selected and t.spec.onDeselect then pcall(t.spec.onDeselect) end
            t.selected = false
        end
    end
end

-- The diary's own controls (previous / next day, page number, delete) belong to the diary, so they are
-- hidden while another addon's tab is selected. A tab can keep them with keepDiaryControls = true.
local function SetDiaryControls(shown)
    if not journalFrame then return end
    for _, key in ipairs({ "prevButton", "nextButton", "pageNumber", "deleteButton" }) do
        local widget = journalFrame[key]
        if widget then widget:SetShown(shown) end
    end
end

local function SelectSideTab(index)
    SelectSideTabCore(index)
    local entry = sideTabs[index or 1]
    local show = (index or 1) == 1 or (entry and entry.spec.keepDiaryControls)
    SetDiaryControls(show and true or false)
end

local function CreateTabNow(spec)
    local parent = journalFrame
    local btn = CreateSideTab(parent, spec.icon or "Interface\\Icons\\INV_Misc_Book_09")
    local index = #sideTabs + 1
    if index == 1 then
        btn:SetPoint("TOPLEFT", parent, "TOPRIGHT", -4, -50)
    else
        btn:SetPoint("TOPLEFT", sideTabs[index - 1].btn, "BOTTOMLEFT", 0, -2)
    end
    btn:SetScript("OnMouseUp", function(_, _, upInside)
        if upInside ~= false then SelectSideTab(index) end
    end)
    btn:SetScript("OnEnter", function(self)
        for _, t in ipairs(self.hoverTex) do t:Show() end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(spec.tooltip or "")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        for _, t in ipairs(self.hoverTex) do t:Hide() end
        GameTooltip:Hide()
    end)
    sideTabs[index] = { btn = btn, spec = spec, selected = false }
    return index
end

function ns.BuildSideTabs(f)
    if sideTabs[1] then return end
    -- 1: the diary itself. Selecting it deselects every other tab, which hides their content.
    CreateTabNow({ icon = "Interface\\Icons\\INV_Misc_Book_09", tooltip = "Diario de Aventuras" })
    SelectSideTab(1)
    for _, spec in ipairs(queuedTabs) do spec.index = CreateTabNow(spec) end
    wipe(queuedTabs)
    -- Closing the book returns to the diary, so the next opening does not show another addon's content.
    f:HookScript("OnHide", function() SelectSideTab(1) end)
end

AdventureJournalTabs = {
    -- Returns the tab's index. Queued (and the index predicted) when the book window does not exist yet.
    Add = function(spec)
        if type(spec) ~= "table" then return nil end
        if journalFrame and sideTabs[1] then return CreateTabNow(spec) end
        queuedTabs[#queuedTabs + 1] = spec
        return 1 + #queuedTabs
    end,
    Select = function(index) if sideTabs[1] then SelectSideTab(index or 1) end end,
}
