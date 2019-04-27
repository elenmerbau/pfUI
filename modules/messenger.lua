pfUI:RegisterModule("messenger", function ()
  --[[
  TODO:
  - Hide messages from chat
  - History
  - WHOIS-Query
  - Item-Paste
  - Tabs (?)
  - Shade Windows
  - Add to Playerdropdown: (Ignore, Friend, Guild-Invite)
  - Queue Popup when infight
  - Class portraits
  - Button-List of all Whispers
  ]]--

  local function CreateChatWindow(name)
    local frame = CreateFrame("Frame", "pfMessenger" .. name, UIParent)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown",function()
      this:StartMoving()
    end)

    frame:SetScript("OnMouseUp",function()
      this:StopMovingOrSizing()
    end)

    frame:SetWidth(320)
    frame:SetHeight(240)

    frame:SetPoint("CENTER", 0, 0)

    frame.data = {
      name = name,
      race = nil,
      class = pfUI_playerDB[name] and pfUI_playerDB[name]["class"] or "UNKNOWN",
      level = pfUI_playerDB[name] and pfUI_playerDB[name]["level"] or 0,
    }

    local data = frame.data

    frame.classicon = frame:CreateTexture(nil,"BACKGROUND")
    frame.classicon:SetTexture("Interface\\AddOns\\pfUI\\img\\classicons")
    frame.classicon:SetPoint("TOPLEFT", 2, -2)
    frame.classicon:SetWidth(28)
    frame.classicon:SetHeight(28)
    local t = CLASS_ICON_TCOORDS[frame.data.class]
    if t then
      frame.classicon:SetTexCoord(unpack(t))
    else
      frame.classicon:SetTexCoord(0,1,0,1)
    end

    frame.name = frame:CreateFontString(nil, "OVERLAY", frame)
    frame.name:SetFont(pfUI.font_default, 14, "OUTLINE")
    frame.name:SetPoint("TOPLEFT", 32, -3)
    frame.name:SetJustifyH("LEFT")
    frame.name:SetShadowColor(0, 0, 0)
    frame.name:SetShadowOffset(0.8, -0.8)
    frame.name:SetTextColor(1,1,1)
    local color
    if RAID_CLASS_COLORS[data.class] then
      color = RAID_CLASS_COLORS[data.class].colorStr
    end
    frame.name:SetText("|c" .. ( color or "ff33ffcc" ) .. name .. "|r")

    frame.info = frame:CreateFontString(nil, "OVERLAY", frame)
    frame.info:SetFont(pfUI.font_default, 11, "OUTLINE")
    frame.info:SetPoint("TOPLEFT", 32, -17)
    frame.info:SetJustifyH("LEFT")
    frame.info:SetShadowColor(0, 0, 0)
    frame.info:SetShadowOffset(0.8, -0.8)
    frame.info:SetTextColor(1,1,1,.5)

    local class = UNKNOWN
    for loc, raw in pairs(L["class"]) do
      if data.class == raw then class = loc end
    end

    frame.info:SetText(data.level .. " " .. (data.race and data.race .. " " .. class or class))

    frame.text = CreateFrame("ScrollingMessageFrame", "pfMessenger" .. name .. "Text", frame)
    frame.text:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.text:SetHeight(frame:GetHeight() - 68)
    frame.text:SetWidth(frame:GetWidth() - 10)
    frame.text:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
    frame.text:SetJustifyH("LEFT")
    frame.text:SetFading(false)
    frame.text:EnableMouse(true)
    frame.text:EnableMouseWheel(1)
    frame.text:SetMaxLines(512)

    frame.input = CreateFrame("EditBox", "pfMessenger" .. name .. "Input", frame)
    frame.input:SetTextColor(1,1.1,1)
    frame.input:SetHeight(20)
    frame.input:SetWidth(frame:GetWidth() - 10)
    frame.input:SetJustifyH("LEFT")
    frame.input:SetPoint("BOTTOM", 0, 5)
    frame.input:SetFontObject(GameFontWhite)
    frame.input:SetAutoFocus(false)
    frame.input:SetScript("OnEscapePressed", function(self)
      frame.input:ClearFocus()
    end)

    frame.input:SetScript("OnEnterPressed", function(self)
      SendChatMessage(this:GetText(), "WHISPER", nil, name)
      this:SetText("")
    end)

    frame.text:SetScript("OnMouseWheel", function()
      if arg1 > 0 then
        if IsShiftKeyDown() then
          this:PageUp()
        else
          this:ScrollUp()
        end
      else
        if IsShiftKeyDown() then
          this:PageDown()
        else
          this:ScrollDown()
        end
      end
    end)

    frame.text:SetScript("OnHyperlinkClick", function()
      ChatFrame_OnHyperlinkShow(arg1, arg2, arg3)
    end)

    frame.text:SetScript("OnMessageScrollChanged", function()
      -- recalc
    end)

    frame.close = CreateFrame("Button", "pfMessenger" .. name .. "Close", frame)
    frame.close:SetPoint("TOPRIGHT", -7, -9)
    pfUI.api.CreateBackdrop(frame.close)
    frame.close:SetHeight(12)
    frame.close:SetWidth(12)
    frame.close.texture = frame.close:CreateTexture("pfMessenger" .. name .. "CloseTex")
    frame.close.texture:SetTexture("Interface\\AddOns\\pfUI\\img\\close")
    frame.close.texture:ClearAllPoints()
    frame.close.texture:SetAllPoints(frame.close)
    frame.close.texture:SetVertexColor(1,.25,.25,1)
    frame.close:SetScript("OnEnter", function ()
      this.backdrop:SetBackdropBorderColor(1,.25,.25,1)
    end)

    frame.close:SetScript("OnLeave", function ()
      pfUI.api.CreateBackdrop(this)
    end)

    frame.close:SetScript("OnClick", function()
     this:GetParent():Hide()
    end)

    CreateBackdrop(frame.input)
    CreateBackdrop(frame.text)
    CreateBackdrop(frame)

    return frame
  end

  local function NewMessage(message, name, outgoing)
    local time = date("%H:%M")
    local player = "|Hplayer:".. name .."|h[".. name .."]|h"
    local color = outgoing and "|cffff55ff" or "|cffffaaff"
    local str = "|cffaaaaaa" .. time .. "|r " .. player .. ": " .. color .. message
    pfUI.messenger.windows[name].text:AddMessage(str)
  end

  pfUI.messenger = CreateFrame("Frame", "pfMessenger", UIParent)
  pfUI.messenger.windows = { }

  pfUI.messenger:RegisterEvent("CHAT_MSG_WHISPER")
  pfUI.messenger:RegisterEvent("CHAT_MSG_WHISPER_INFORM")

  pfUI.messenger:SetScript("OnEvent", function()
    local text, name = arg1, arg2
    local outgoing = ( event == "CHAT_MSG_WHISPER_INFORM" and true ) or nil

    if not pfUI.messenger.windows[name] then
      pfUI.messenger.windows[name] = CreateChatWindow(name)
    end

    NewMessage(text, name, outgoing)
    pfUI.messenger.windows[name]:Show()
  end)

end)
