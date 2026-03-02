--[[
IBUY self-tests.

Purpose:
- Provide quick runtime checks for core helper logic without external test frameworks.

Inputs / Outputs:
- Input: Current IBUY globals and configured watch list.
- Output: Chat log with PASS/FAIL lines and summary.

Invariants:
- Tests do not mutate long-term config permanently; original state is restored.

How to debug:
- Run /ibuy selftest
- Enable /ibuy debug on to see additional runtime logs.
]]

local IBUY = _G.IBUY

local function TLog(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff[IBUY Test]|r " .. tostring(msg))
end

local function AssertEqual(name, actual, expected)
    if actual ~= expected then
        error(string.format("%s failed. expected=%s actual=%s", name, tostring(expected), tostring(actual)))
    end
end

function IBUY.RunSelfTests()
    if not IBUY_DB then
        TLog("FAIL: IBUY_DB ist nicht initialisiert.")
        return
    end

    local passed = 0
    local failed = 0
    local originalOrder = {}
    for i, v in ipairs(IBUY_DB.watchOrder or {}) do
        originalOrder[i] = v
    end

    local function Run(name, fn)
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
            TLog("PASS: " .. name)
        else
            failed = failed + 1
            TLog("FAIL: " .. name .. " -> " .. tostring(err))
        end
    end

    -- Why this exists:
    -- Parsing item IDs from links is central to matching vendor rows.
    Run("ExtractItemID parses link", function()
        local id = IBUY._ExtractItemID("|cffffffff|Hitem:16224::::::::::::|h[Test]|h|r")
        AssertEqual("extract id", id, 16224)
    end)

    -- Example input/output:
    -- Input watchOrder: {16224, "16224", 27860}
    -- Output watchOrder: {16224, 27860}
    Run("EnsureWatchIndex removes duplicates", function()
        IBUY_DB.watchOrder = { 16224, "16224", 27860, 27860 }
        IBUY._EnsureWatchIndex()
        AssertEqual("watch count", #IBUY_DB.watchOrder, 2)
        AssertEqual("watch #1", IBUY_DB.watchOrder[1], 16224)
        AssertEqual("watch #2", IBUY_DB.watchOrder[2], 27860)
        AssertEqual("is watching 16224", IBUY._IsWatching(16224), true)
    end)

    Run("AddWatchItem and RemoveWatchItem", function()
        IBUY_DB.watchOrder = {}
        IBUY._EnsureWatchIndex()
        local okAdd = select(1, IBUY._AddWatchItem(99999))
        AssertEqual("add success", okAdd, true)
        AssertEqual("watch length after add", #IBUY_DB.watchOrder, 1)
        local okRemove = select(1, IBUY._RemoveWatchItem(99999))
        AssertEqual("remove success", okRemove, true)
        AssertEqual("watch length after remove", #IBUY_DB.watchOrder, 0)
    end)

    -- Restore original config after tests.
    IBUY_DB.watchOrder = originalOrder
    IBUY._EnsureWatchIndex()

    TLog(string.format("Summary: %d passed, %d failed", passed, failed))
end
