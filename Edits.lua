-- Edits.lua: the player's own wording of a diary entry.
--
-- Every paragraph of the book has a small pencil icon (Textures\edit.tga, see README). It opens a window
-- where the player can rewrite the sentence the addon generated and/or add a description under it.
-- The edit never replaces what the addon wrote: it is stored next to it, so it can always be undone.
--   entry.userText   the player's version of the sentence (absent: the generated `prose` is shown)
--   entry.userNote   a description added under the sentence (optional)
--   entry.editedAt   epoch of the last edit
-- All three are optional and additive, so no schema bump (the version stays 3) and every older diary loads
-- as before. `prose`, `text` and the rest of the entry are never changed, so the import's duplicate
-- detection, the exporter and the old versions of the addon keep working. Conversations are other
-- players' words and are not editable.
local addonName, ns = ...

ns.EDIT_ICON = "Interface\\AddOns\\AdventureJournal\\Textures\\edit.tga"
ns.MAX_USER_TEXT = 1000

local function Trim(text)
    if type(text) ~= "string" then return "" end
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

-- The real diary's entry (never the demo diary), or nil.
function ns.GetEntry(dayNumber, index)
    local DB = ns.DB or ns.EnsureDatabase()
    local day = DB and DB.days and DB.days[dayNumber]
    local entry = type(day) == "table" and type(day.events) == "table" and day.events[index]
    if type(entry) == "table" then return entry, day end
    return nil
end

function ns.EntryIsEdited(entry)
    return type(entry) == "table"
        and ((type(entry.userText) == "string" and entry.userText ~= "")
            or (type(entry.userNote) == "string" and entry.userNote ~= ""))
end

-- The sentence generated for an entry (the stored prose, or composed now for one that has none).
function ns.GeneratedProse(entry)
    if type(entry.prose) == "string" and entry.prose ~= "" then return entry.prose end
    local prose = ns.ComposeEntry(entry)
    return type(prose) == "string" and prose or ""
end

-- Stores the player's version and description. A text that is empty, or equal to the generated one, means
-- "no own version". Returns true when the entry still has an edit.
function ns.SaveEntryEdit(entry, text, note)
    text, note = Trim(text), Trim(note)
    if string.len(text) > ns.MAX_USER_TEXT then text = string.sub(text, 1, ns.MAX_USER_TEXT) end
    if string.len(note) > ns.MAX_USER_TEXT then note = string.sub(note, 1, ns.MAX_USER_TEXT) end
    if text == "" or text == ns.GeneratedProse(entry) then text = nil end
    if note == "" then note = nil end
    entry.userText, entry.userNote = text, note
    entry.editedAt = (text or note) and time() or nil
    ns.RefreshKeepingScroll()
    return (text or note) ~= nil
end

function ns.ClearEntryEdit(entry)
    entry.userText, entry.userNote, entry.editedAt = nil, nil, nil
    ns.RefreshKeepingScroll()
end

-- The text the book shows for an entry's sentence. User text is shown literally: a "|" typed by the
-- player must never start a colour or link escape.
function ns.EscapeUserText(text)
    return (string.gsub(text, "|", "||"))
end

-- A multi-line text box with a border and a scroll bar. Returns the container; `.edit` is the EditBox.
function ns.CreateMultilineBox(parent, width, height, maxLetters)
    local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    box:SetSize(width, height)
    if box.SetBackdrop then
        pcall(function()
            box:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            })
            box:SetBackdropColor(0, 0, 0, 0.55)
        end)
    end
    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", -26, 6)
    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal or GameFontHighlight)
    edit:SetWidth(width - 36)
    edit:SetMaxLetters(maxLetters or ns.MAX_USER_TEXT)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scroll:SetScrollChild(edit)
    -- A click anywhere in the box puts the cursor in it.
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() edit:SetFocus() end)
    box.edit, box.scroll = edit, scroll
    return box
end

-- The window ------------------------------------------------------------------------------------
local dialog

local TYPE_NAMES = {}
local function TypeName(entryType)
    if next(TYPE_NAMES) == nil then
        for _, info in ipairs(ns.TYPE_INFO) do TYPE_NAMES[info.key] = info.label end
    end
    return TYPE_NAMES[entryType] or tostring(entryType)
end

local function CloseDialog()
    if dialog then dialog:Hide() end
end

local function BuildDialog()
    local f = CreateFrame("Frame", "AdventureJournalEditFrame", UIParent, "BackdropTemplate")
    f:SetSize(500, 478)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    if f.SetClampedToScreen then f:SetClampedToScreen(true) end
    local background = f:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\Buttons\\WHITE8X8")
    background:SetAllPoints(f)
    background:SetVertexColor(0.12, 0.08, 0.06, 0.98)
    if f.SetBackdrop then
        pcall(function()
            f:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
                insets = { left = 5, right = 5, top = 5, bottom = 5 } })
        end)
    end

    local function Label(template, x, y, text, width)
        local fs = f:CreateFontString(nil, "OVERLAY", template)
        fs:SetPoint("TOPLEFT", x, y)
        fs:SetWidth(width or 460)
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetText(text or "")
        return fs
    end

    local title = Label("GameFontNormalLarge", 20, -16, "Editar esta anotación")
    title:SetTextColor(0.95, 0.82, 0.52)
    f.meta = Label("GameFontHighlightSmall", 20, -44, "")
    Label("GameFontNormal", 20, -68, "Mi versión de la frase (puedes reescribirla entera):")
    f.textBox = ns.CreateMultilineBox(f, 460, 150, ns.MAX_USER_TEXT)
    f.textBox:SetPoint("TOPLEFT", 20, -88)
    Label("GameFontNormal", 20, -250, "Descripción añadida (opcional, se muestra debajo):")
    f.noteBox = ns.CreateMultilineBox(f, 460, 100, ns.MAX_USER_TEXT)
    f.noteBox:SetPoint("TOPLEFT", 20, -270)
    f.hint = Label("GameFontHighlightSmall", 20, -378,
        "El texto que generó el diario no se pierde: «Volver al original» lo recupera. "
        .. "Si dejas la frase igual que el original, solo se guarda la descripción.")

    local function Button(label, width, x, onClick)
        local button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        button:SetSize(width, 24)
        button:SetPoint("BOTTOMLEFT", x, 18)
        button:SetText(label)
        button:SetScript("OnClick", onClick)
        return button
    end
    f.save = Button("Guardar", 100, 20, function()
        local entry = f.entry
        if entry then ns.SaveEntryEdit(entry, f.textBox.edit:GetText(), f.noteBox.edit:GetText()) end
        CloseDialog()
    end)
    f.restore = Button("Volver al original", 140, 130, function(self)
        -- Throws away the player's words: ask for a second click.
        if not f.restoreArmed then
            f.restoreArmed = true
            self:SetText("¿Seguro? Otra vez")
            return
        end
        if f.entry then ns.ClearEntryEdit(f.entry) end
        CloseDialog()
    end)
    f.cancel = Button("Cancelar", 100, 280, CloseDialog)

    f:SetScript("OnHide", function(self)
        self.entry, self.restoreArmed = nil, false
        self.restore:SetText("Volver al original")
    end)
    local registered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "AdventureJournalEditFrame" then registered = true end
    end
    if not registered then tinsert(UISpecialFrames, "AdventureJournalEditFrame") end
    f:Hide()
    dialog = f   -- only a fully built window is kept: a failed build is retried at the next click
end

-- Opens the window for entry `index` of jornada `dayNumber` of the real diary.
function ns.OpenEditDialog(dayNumber, index)
    local entry, day = ns.GetEntry(dayNumber, index)
    if not entry then return false end
    if not dialog then BuildDialog() end
    local f = dialog
    f.entry, f.restoreArmed = entry, false
    f.restore:SetText("Volver al original")
    f.meta:SetText(string.format("Jornada %d  ·  %s  ·  %s", dayNumber, tostring(entry.time or "--:--:--"), TypeName(entry.type)))
    f.textBox.edit:SetText(type(entry.userText) == "string" and entry.userText ~= "" and entry.userText or ns.GeneratedProse(entry))
    f.noteBox.edit:SetText(type(entry.userNote) == "string" and entry.userNote or "")
    if ns.EntryIsEdited(entry) then f.restore:Enable() else f.restore:Disable() end
    f:Show()
    if f.textBox.edit.SetFocus then f.textBox.edit:SetFocus() end
    return true
end

-- Deleting a jornada ---------------------------------------------------------------------------------
-- Removes jornada `dayNumber` of the real diary; the later ones move up a number (delete 7: 8 becomes 7).
-- The last jornada is the one in progress (new entries go to it), so it cannot be deleted. Returns true, or
-- false and the reason in Spanish.
function ns.DeleteDay(dayNumber)
    local DB = ns.EnsureDatabase()
    local total = DB.currentDay
    if type(dayNumber) ~= "number" or dayNumber < 1 or dayNumber > total or type(DB.days[dayNumber]) ~= "table" then
        return false, "Esa jornada no existe."
    end
    if dayNumber == total then
        return false, "No se puede eliminar la jornada en curso: es donde se anotan los acontecimientos de ahora."
    end
    local keep = {}
    for index = 1, total do
        if index ~= dayNumber then keep[#keep + 1] = DB.days[index] end
    end
    DB.days = keep
    DB.currentDay = #keep
    -- Keep looking at the same jornada (it may have a new number), or at its neighbour if it was this one.
    local selected = ns.selectedDay or DB.currentDay
    if selected > dayNumber then selected = selected - 1 end
    ns.selectedDay = math.max(1, math.min(DB.currentDay, selected))
    ns.conversationPage = 1
    -- An open edit window points at an entry of the removed jornada.
    if _G.AdventureJournalEditFrame and _G.AdventureJournalEditFrame:IsShown() then _G.AdventureJournalEditFrame:Hide() end
    ns.RefreshIfVisible()
    return true
end

local DELETE_POPUP = "ADVENTUREJOURNAL_DELETE_DAY"
local armedDay   -- no StaticPopup on this client: the button asks for a second click

local function DescribeDay(dayNumber)
    local day = ns.DB and ns.DB.days and ns.DB.days[dayNumber] or {}
    local events = type(day.events) == "table" and #day.events or 0
    local talks = type(day.conversations) == "table" and #day.conversations or 0
    return string.format("la jornada %d (%d anotaciones, %d conversaciones)", dayNumber, events, talks)
end

local function DoDelete(dayNumber)
    armedDay = nil
    local ok, reason = ns.DeleteDay(dayNumber)
    if ok then
        print("|cFFFFD700[Diario]|r Jornada " .. dayNumber .. " eliminada. Las siguientes han subido de número.")
    else
        print("|cFFFFD700[Diario]|r " .. tostring(reason))
    end
end

-- The book's Eliminar button. Asks first; there is no way back (back up the SavedVariables to be safe).
function ns.AskDeleteDay(dayNumber)
    if ns.demoDB then return end
    local DB = ns.EnsureDatabase()
    if dayNumber == DB.currentDay then
        print("|cFFFFD700[Diario]|r No se puede eliminar la jornada en curso: es donde se anotan los acontecimientos de ahora.")
        return
    end
    if StaticPopupDialogs and StaticPopup_Show then
        if not StaticPopupDialogs[DELETE_POPUP] then
            StaticPopupDialogs[DELETE_POPUP] = {
                text = "%s",
                button1 = ACCEPT or "Aceptar",
                button2 = CANCEL or "Cancelar",
                OnAccept = function(_, data) DoDelete(data) end,
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
        end
        local question = "¿Eliminar " .. DescribeDay(dayNumber) .. "?\n\nLas jornadas siguientes subirán de número. No se puede deshacer."
        local ok, dialog = pcall(StaticPopup_Show, DELETE_POPUP, question, nil, dayNumber)
        if ok and dialog then return end
    end
    if armedDay == dayNumber then
        DoDelete(dayNumber)
    else
        armedDay = dayNumber
        print("|cFFFFD700[Diario]|r Pulsa otra vez Eliminar para borrar " .. DescribeDay(dayNumber) .. ".")
    end
end
