
local addonName, addon = ...

addon = addon or {}

-- =========================================================
-- DIARIO DE AVENTURAS - INTERFAZ
-- WoW Forever / Classic Era 1.15.x
-- Interfaz independiente y sin modificar marcos protegidos
-- =========================================================

local journalFrame
local selectedDay
local SelectDay

local FONT_COLOR = {
    title = { 0.95, 0.82, 0.52 },
    heading = { 0.25, 0.14, 0.02 },
    metadata = { 0.40, 0.30, 0.20 },
    body = { 0.18, 0.12, 0.06 },
    secondary = { 0.75, 0.75, 0.75 },
}

-- =========================================================
-- UTILIDADES
-- =========================================================

local function SafeBackdrop(frame, settings, r, g, b, a)
    if not frame or not frame.SetBackdrop then
        return
    end

    pcall(function()
        frame:SetBackdrop(settings)

        if r then
            frame:SetBackdropColor(r, g, b, a or 1)
        end
    end)
end

local function SetColor(fontString, color)
    if fontString and color then
        fontString:SetTextColor(
            color[1],
            color[2],
            color[3],
            color[4] or 1
        )
    end
end

local function CreateText(parent, template, value, width)
    local fs = parent:CreateFontString(
        nil,
        "OVERLAY",
        template or "GameFontNormal"
    )

    fs:SetText(value or "")
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")

    if width then
        fs:SetWidth(width)
    end

    if fs.SetWordWrap then
        fs:SetWordWrap(true)
    end

    return fs
end

local function CreatePanel(parent, width, height)
    local frame = CreateFrame(
        "Frame",
        nil,
        parent,
        "BackdropTemplate"
    )

    frame:SetSize(width, height)

    SafeBackdrop(
        frame,
        {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {
                left = 2,
                right = 2,
                top = 2,
                bottom = 2
            }
        },
        0.08, 0.05, 0.04, 0.95
    )

    return frame
end
local function CreatePageBackground(frame)
    local texture = frame:CreateTexture(nil, "BACKGROUND")

    texture:SetTexture(
        "Interface\\AddOns\\AdventureJournal\\Textures\\tiled.tga"
    )

    texture:SetAllPoints(frame)

    frame.pageBackground = texture
end

local function HideFrame(frame)
    if frame and frame.Hide then
        frame:Hide()
    end
end

local function GetDatabase()
    if addon.EnsureDatabase then
        addon.EnsureDatabase()
    end

    return AdventureJournalDB
end

-- =========================================================
-- CONSTRUCCIÓN DE LA INTERFAZ
-- =========================================================

local function BuildUI()

    if journalFrame then
        return
    end

    -- -----------------------------------------------------
    -- MARCO PRINCIPAL
    -- -----------------------------------------------------

   local f = CreateFrame(
    "Frame",
    "AdventureJournalBookFrame",
    UIParent,
    "BackdropTemplate"
)

    journalFrame = f

    f:SetSize(820, 560)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(20)

    f:SetMovable(true)
    f:EnableMouse(true)

    -- Movimiento limitado al propio marco.
    f:RegisterForDrag("LeftButton")

    f:SetScript("OnDragStart", function(self)
        if not InCombatLockdown or not InCombatLockdown() then
            self:StartMoving()
        end
    end)

    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    if f.SetClampedToScreen then
        f:SetClampedToScreen(true)
    end

        -- Fondo principal independiente
    local mainBackground = f:CreateTexture(
        nil,
        "BACKGROUND"
    )

    mainBackground:SetTexture(
        "Interface\\Buttons\\WHITE8X8"
    )

    mainBackground:SetAllPoints(f)

    mainBackground:SetVertexColor(
        0.12, 0.08, 0.06, 0.98
    )

    f.mainBackground = mainBackground

    -- Borde exterior
    SafeBackdrop(
        f,
        {
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 24,
            insets = {
                left = 5,
                right = 5,
                top = 5,
                bottom = 5
            }
        }
    )

    -- -----------------------------------------------------
    -- TÍTULO
    -- -----------------------------------------------------

    local playerName = UnitName("player") or "Aventurero"

    local title = CreateText(
        f,
        "GameFontNormalLarge",
        "Diario de Aventura - " .. playerName,
        700
    )

    title:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -15)

    SetColor(title, FONT_COLOR.title)

    f.title = title

    -- -----------------------------------------------------
    -- BOTÓN DE CIERRE
    -- -----------------------------------------------------

    local close = CreateFrame(
        "Button",
        nil,
        f
    )

    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    close:SetNormalTexture(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Up"
    )

    close:SetPushedTexture(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Down"
    )

    close:SetHighlightTexture(
        "Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight",
        "ADD"
    )

    close:SetScript("OnClick", function()
        f:Hide()
    end)

    -- -----------------------------------------------------
    -- PANEL IZQUIERDO
    -- -----------------------------------------------------

    local leftPanel = CreatePanel(f, 240, 495)

    leftPanel:SetPoint(
        "TOPLEFT",
        f,
        "TOPLEFT",
        15,
        -45
    )

    f.leftPanel = leftPanel

    -- -----------------------------------------------------
    -- ÍNDICE / SCROLL IZQUIERDO
    -- -----------------------------------------------------

    local indexScroll = CreateFrame(
        "ScrollFrame",
        "AdventureJournal_IndexScroll",
        leftPanel,
        "UIPanelScrollFrameTemplate"
    )

    indexScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 8, -8)
    indexScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -26, 8)

    local indexChild = CreateFrame(
        "Frame",
        nil,
        indexScroll
    )

    indexChild:SetSize(195, 1)

    indexScroll:SetScrollChild(indexChild)

    f.indexScroll = indexScroll
    f.indexChild = indexChild
    f.dayItems = {}

    -- -----------------------------------------------------
    -- PÁGINA DERECHA
    -- -----------------------------------------------------

    local rightPage = CreateFrame(
        "Frame",
        nil,
        f,
"BackdropTemplate"
    )

    rightPage:SetPoint(
        "TOPLEFT",
        leftPanel,
        "TOPRIGHT",
        10,
        0
    )

    rightPage:SetSize(538, 495)

    SafeBackdrop(
        rightPage,
        {
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
            insets = {
                left = 0,
                right = 0,
                top = 0,
                bottom = 0
            }
        }
    )

    CreatePageBackground(rightPage)

    f.rightPage = rightPage

    -- -----------------------------------------------------
    -- TÍTULO DE JORNADA
    -- -----------------------------------------------------

    local dayTitle = CreateText(
        rightPage,
        "QuestTitleFont",
        "Jornada",
        490
    )

    dayTitle:SetPoint(
        "TOPLEFT",
        rightPage,
        "TOPLEFT",
        20,
        -15
    )

    SetColor(dayTitle, FONT_COLOR.heading)

    f.dayTitle = dayTitle

    -- -----------------------------------------------------
    -- METADATOS
    -- -----------------------------------------------------

    local dayMeta = CreateText(
        rightPage,
        "GameFontHighlightSmall",
        "",
        490
    )

    dayMeta:SetPoint(
        "TOPLEFT",
        dayTitle,
        "BOTTOMLEFT",
        0,
        -4
    )

    SetColor(dayMeta, FONT_COLOR.metadata)

    f.dayMeta = dayMeta

    -- -----------------------------------------------------
    -- SCROLL DEL CONTENIDO
    -- -----------------------------------------------------

    local contentScroll = CreateFrame(
        "ScrollFrame",
        "AdventureJournal_ContentScroll",
        rightPage,
        "UIPanelScrollFrameTemplate"
    )

    contentScroll:SetPoint(
        "TOPLEFT",
        rightPage,
        "TOPLEFT",
        20,
        -55
    )

    contentScroll:SetPoint(
        "BOTTOMRIGHT",
        rightPage,
        "BOTTOMRIGHT",
        -28,
        15
    )

    local contentChild = CreateFrame(
        "Frame",
        nil,
        contentScroll
    )

    contentChild:SetSize(470, 1)

    contentScroll:SetScrollChild(contentChild)

    f.contentScroll = contentScroll
    f.contentChild = contentChild

    -- -----------------------------------------------------
    -- TEXTO PRINCIPAL
    -- -----------------------------------------------------

    local body = CreateText(
        contentChild,
        "QuestFont",
        "",
        450
    )

    body:SetPoint(
        "TOPLEFT",
        contentChild,
        "TOPLEFT",
        10,
        -10
    )

    body:SetPoint(
        "TOPRIGHT",
        contentChild,
        "TOPRIGHT",
        -10,
        -10
    )

    SetColor(body, FONT_COLOR.body)

    if body.SetShadowColor then
        body:SetShadowColor(0, 0, 0, 0.3)
    end

    if body.SetShadowOffset then
        body:SetShadowOffset(1, -1)
    end

    if body.SetSpacing then
        body:SetSpacing(4)
    end

    f.body = body

    -- -----------------------------------------------------
    -- ACTUALIZACIÓN AL MOSTRAR
    -- -----------------------------------------------------

    f:SetScript("OnShow", function()
        if addon.RefreshUI then
            addon:RefreshUI()
        end
    end)

    -- ESC CIERRA EL DIARIO
    if UISpecialFrames then
        local alreadyRegistered = false

        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "AdventureJournalBookFrame" then
                alreadyRegistered = true
                break
            end
        end

                if not alreadyRegistered then
            table.insert(
                UISpecialFrames,
                "AdventureJournalBookFrame"
            )
        end
    end

    -- El marco debe empezar oculto para que /diario
    -- lo muestre en su primera ejecución.
    f:Hide()
end

-- =========================================================
-- SELECCIÓN DE JORNADA
-- =========================================================

SelectDay = function(dayNumber)

    local DB = GetDatabase()

    if not DB then
        return
    end

    local total = tonumber(DB.currentDay) or 0

    if total < 1 then
        return
    end

    if not dayNumber or dayNumber == 0 then
        selectedDay = total
    else
        selectedDay = math.max(
            1,
            math.min(
                total,
                tonumber(dayNumber) or total
            )
        )
    end

    if journalFrame and journalFrame:IsShown() then
        addon:RefreshUI()
    end
end

-- =========================================================
-- ACTUALIZACIÓN DEL ÍNDICE
-- =========================================================

local function RefreshIndex(DB)

    local f = journalFrame
    local total = tonumber(DB.currentDay) or 0
    local dayItems = f.dayItems or {}

    for _, item in pairs(dayItems) do
        HideFrame(item.btn)
        HideFrame(item.subText)
    end

    local y = 0

    for dayNumber = total, 1, -1 do

        local day = DB.days and DB.days[dayNumber] or {}
        local events = day.events or {}

        local placeInfo =
            day.mainZone
            or (events[1] and events[1].place)
            or "Aventura"

        local dateInfo = day.dateLabel or "Fecha desconocida"

        local item = dayItems[dayNumber]

        if not item then

            item = {}

            local btn = CreateFrame(
                "Button",
                nil,
                f.indexChild,
                "UIPanelButtonTemplate"
            )

            btn:SetSize(195, 24)

            item.btn = btn

            local subText = f.indexChild:CreateFontString(
                nil,
                "OVERLAY",
                "GameFontHighlightSmall"
            )

            subText:SetWidth(190)
            subText:SetJustifyH("LEFT")
            subText:SetJustifyV("TOP")

            SetColor(subText, FONT_COLOR.secondary)

            item.subText = subText

            dayItems[dayNumber] = item
        end

        item.btn:ClearAllPoints()

        item.btn:SetPoint(
            "TOPLEFT",
            f.indexChild,
            "TOPLEFT",
            0,
            y
        )

        item.btn:SetText(
            string.format("Jornada %d", dayNumber)
        )

        item.subText:ClearAllPoints()

        item.subText:SetPoint(
            "TOPLEFT",
            item.btn,
            "BOTTOMLEFT",
            4,
            -3
        )

        item.subText:SetText(
            string.format(
                "%s  ·  %s",
                tostring(placeInfo),
                tostring(dateInfo)
            )
        )

        local chosenDay = dayNumber

        item.btn:SetScript("OnClick", function()
            SelectDay(chosenDay)
        end)

        item.btn:Show()
        item.subText:Show()

        y = y - 48
    end

    f.dayItems = dayItems

    f.indexChild:SetHeight(
        math.max(1, -y + 5)
    )
end

-- =========================================================
-- ACTUALIZACIÓN DEL CONTENIDO
-- =========================================================

function addon:RefreshUI()

    if not journalFrame then
        return
    end

    local DB = GetDatabase()

    if not DB then
        return
    end

    local total = tonumber(DB.currentDay) or 0

    RefreshIndex(DB)

    -- -----------------------------------------------------
    -- SIN JORNADAS
    -- -----------------------------------------------------

    if total < 1 then

        selectedDay = nil

        journalFrame.dayTitle:SetText(
            "Aún no hay jornadas"
        )

        journalFrame.dayMeta:SetText("")

        journalFrame.body:SetText(
            "Tu historia comienza cuando salgas a explorar."
        )

        journalFrame.contentChild:SetHeight(150)

        journalFrame.contentScroll:SetVerticalScroll(0)

        return
    end

    -- -----------------------------------------------------
    -- VALIDAR SELECCIÓN
    -- -----------------------------------------------------

    if not selectedDay
        or selectedDay > total
        or selectedDay < 1 then

        selectedDay = total
    end

    local day = DB.days and DB.days[selectedDay]

    if not day then
        day = { events = {} }
    end

    local events = day.events or {}

    -- -----------------------------------------------------
    -- ENCABEZADO
    -- -----------------------------------------------------

    journalFrame.dayTitle:SetText(
        string.format(
            "Jornada %d",
            selectedDay
        )
    )

    journalFrame.dayMeta:SetText(
        string.format(
            "%s     ·     %d acontecimientos",
            day.dateLabel or "Fecha desconocida",
            #events
        )
    )

    -- -----------------------------------------------------
    -- CONSTRUIR TEXTO
    -- -----------------------------------------------------

    local entriesText = {}

    if #events == 0 then

        entriesText[1] =
            "No dejé constancia de grandes gestas durante esta jornada."

    else

        for i, entry in ipairs(events) do

            local header = entry.header
            local prose = entry.prose

            -- Mantener compatibilidad con ComposeEntry
            if not prose or prose == "" then

                if addon.ComposeEntry then

                    local generatedHeader, generatedProse =
                        addon.ComposeEntry(entry)

                    header = header or generatedHeader
                    prose = generatedProse
                end
            end

            prose =
                prose
                or entry.text
                or "Acontecimiento grabado"

            if i == 1 and (not header or header == "") then

                local place =
                    entry.place
                    or day.mainZone
                    or "Azeroth"

                header = "En " .. place
            end

            if header and header ~= "" then

                table.insert(
                    entriesText,
                    string.format(
                        "|cFFFF3333%s|r\n%s",
                        header,
                        prose
                    )
                )

            else

                table.insert(
                    entriesText,
                    prose
                )
            end
        end
    end

    -- -----------------------------------------------------
    -- MOSTRAR TEXTO
    -- -----------------------------------------------------

    journalFrame.body:SetText(
        table.concat(entriesText, "\n\n")
    )

    -- Ajustar altura del contenido al texto
    local textHeight = journalFrame.body:GetStringHeight()

    local finalHeight = math.max(
        150,
        textHeight + 40
    )

    journalFrame.contentChild:SetHeight(finalHeight)

    -- Reiniciar scroll
    journalFrame.contentScroll:SetVerticalScroll(0)
end

-- =========================================================
-- APERTURA Y CIERRE
-- =========================================================

local function ToggleJournal()

    if not journalFrame then
        BuildUI()
    end

    if journalFrame:IsShown() then

        journalFrame:Hide()

    else

        journalFrame:Show()

    end
end

-- =========================================================
-- COMANDOS DE CHAT
-- =========================================================

SLASH_ADVENTUREJOURNAL1 = "/diario"
SLASH_ADVENTUREJOURNAL2 = "/journal"

SlashCmdList["ADVENTUREJOURNAL"] = function(message)

    message = string.lower(
        string.gsub(message or "", "^%s*(.-)%s*$", "%1")
    )

    if message == "" or message == "abrir" then

        ToggleJournal()

    elseif message == "hoy" or message == "actual" then

        if not journalFrame then
            BuildUI()
        end

        local DB = GetDatabase()

        if DB then
            SelectDay(DB.currentDay or 1)
        end

        journalFrame:Show()

    end
end

-- =========================================================
-- BINDING DE TECLADO
-- =========================================================

function AdventureJournal_Toggle()
    ToggleJournal()
end

-- =========================================================
-- FIN DE ADVENTUREJOURNAL.LUA
-- =========================================================

-- =========================================================
-- DIAGNÓSTICO DE BLOQUEOS
-- =========================================================

local diagnosticFrame = CreateFrame("Frame")

local function DiagnosticMessage(message)
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffff4444[AJ DIAGNÓSTICO]|r " .. tostring(message)
        )
    end
end

diagnosticFrame:RegisterEvent("ADDON_ACTION_BLOCKED")
diagnosticFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

diagnosticFrame:SetScript("OnEvent", function(self, event, addonName, functionName)

    DiagnosticMessage("Evento: " .. tostring(event))
    DiagnosticMessage("Addon implicado: " .. tostring(addonName))
    DiagnosticMessage("Función bloqueada: " .. tostring(functionName))

    if type(debugstack) == "function" then
        DiagnosticMessage(debugstack(2, 5, 5))
    end

end)

SLASH_AJDIAGNOSTIC1 = "/ajdiag"

SlashCmdList["AJDIAGNOSTIC"] = function()
    DiagnosticMessage("El sistema de diagnóstico está funcionando.")
end
