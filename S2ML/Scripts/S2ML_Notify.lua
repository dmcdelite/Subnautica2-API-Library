-- S2ML_Notify.lua
-- Player HUD notification helpers with multi-channel fallback.
--
-- Subnautica 2's HUD system is not yet fully mapped. Channels are tried in
-- priority order; the UE4SS console window is always the final fallback.
--
-- USAGE:
--   S2ML.Notify.Message("Oxygen levels critical!", 5.0)
--   S2ML.Notify.ScreenMessage("Alien relic scanned.", 6.0, "cyan")
--   S2ML.Notify.Queue({ "Depth limit reached.", "Pressure increasing.", "Return to base." })
--   S2ML.Notify.Hint("Hold [F] to interact with the fabricator.")

S2ML.Notify = S2ML.Notify or {}

-- =============================================
-- CORE MESSAGE
-- =============================================

-- Display a notification to the local player.
-- Attempts 4 channels in priority order; always echoes to UE4SS console.
-- text     : string
-- duration : seconds (default 4.0)
function S2ML.Notify.Message(text, duration)
    duration = duration or 4.0

    -- Channel 1: Game-native notification manager
    local shown = false
    S2ML.SafeCall(function()
        local mgr = nil
        for _, cls in ipairs({ "NotificationManager", "HUDNotificationManager",
                                "UINotificationManager", "MessageManager" }) do
            local obj = nil
            S2ML.SafeCall(function() obj = FindFirstOf(cls) end)
            if obj and obj:IsValid() then mgr = obj; break end
        end
        if not mgr then return end
        for _, fn in ipairs({ "ShowNotification", "AddNotification",
                               "QueueNotification", "DisplayMessage", "ShowMessage" }) do
            local ok = pcall(function() mgr[fn](mgr, text, duration) end)
            if ok then shown = true; return end
        end
    end)
    if shown then print(string.format("[S2ML] %s", text)); return end

    -- Channel 2: PlayerController:ClientMessage
    S2ML.SafeCall(function()
        local PC = FindFirstOf("PlayerController")
        if PC and PC:IsValid() then
            PC:ClientMessage(text)  -- UE5: MsgLifeTime arg removed
            shown = true
        end
    end)
    if shown then print(string.format("[S2ML] %s", text)); return end

    -- Channel 3: HUD:AddDebugText
    S2ML.SafeCall(function()
        local HUD = FindFirstOf("HUD")
        if HUD and HUD:IsValid() then
            HUD:AddDebugText(text, nil, duration, {}, {}, true, false, false, false, nil, 0)
            shown = true
        end
    end)

    -- Channel 4: UE4SS console window (always works)
    print(string.format("[S2ML] %s", text))
end

-- =============================================
-- SCREEN MESSAGE (colored, centered)
-- =============================================

-- Display a tinted on-screen message via GEngine.
-- color : "white" | "green" | "yellow" | "red" | "cyan"  (default "white")
function S2ML.Notify.ScreenMessage(text, duration, color)
    duration = duration or 5.0
    color     = color    or "white"

    local colorTable = {
        white  = { R = 255, G = 255, B = 255, A = 255 },
        green  = { R =  50, G = 220, B =  50, A = 255 },
        yellow = { R = 255, G = 220, B =   0, A = 255 },
        red    = { R = 255, G =  60, B =  60, A = 255 },
        cyan   = { R =   0, G = 210, B = 255, A = 255 },
    }
    local col = colorTable[color] or colorTable.white

    -- Try GEngine:AddOnScreenDebugMessage
    S2ML.SafeCall(function()
        local Engine = FindFirstOf("GameEngine")
        if Engine and Engine:IsValid() then
            -- Key -1 = auto key (no replacement of previous message)
            Engine:AddOnScreenDebugMessage(-1, duration, col, text, true, { X = 1, Y = 1 })
        end
    end)

    -- Always echo to console as well
    print(string.format("[S2ML] %s", text))
end

-- =============================================
-- QUEUED MESSAGES
-- =============================================

-- Show multiple messages sequentially, separated by a delay.
-- messages       : { "msg1", "msg2", ... }
-- delayBetweenMs : milliseconds between messages (default 3000)
function S2ML.Notify.Queue(messages, delayBetweenMs)
    delayBetweenMs = delayBetweenMs or 3000
    for i, msg in ipairs(messages) do
        ExecuteInGameThreadWithDelay((i - 1) * delayBetweenMs, function()
            S2ML.Notify.Message(msg)
        end)
    end
end

-- =============================================
-- HINT  (longer, cyan — tutorial/discovery style)
-- =============================================

function S2ML.Notify.Hint(text)
    S2ML.Notify.ScreenMessage(text, 8.0, "cyan")
end

-- =============================================
-- SUCCESS / WARNING / ERROR SHORTHANDS
-- =============================================

function S2ML.Notify.Success(text) S2ML.Notify.ScreenMessage(text, 4.0, "green")  end
function S2ML.Notify.Warning(text) S2ML.Notify.ScreenMessage(text, 5.0, "yellow") end
function S2ML.Notify.Error(text)   S2ML.Notify.ScreenMessage(text, 6.0, "red")    end

S2ML.Log("S2ML_Notify loaded.", "DEBUG")
