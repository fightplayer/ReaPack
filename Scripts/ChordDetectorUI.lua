-- Chord Detector UI for ReaScript (Lua)
-- Interactive window to detect chords from MIDI selection
-- @description Chord Detector Window UI
-- @version 1.0
-- @author fightplayer

-- Load the ChordDetector library
local scriptPath = debug.getinfo(1).source:match("@(.*/)")
package.path = scriptPath .. "?.lua;" .. package.path
local ChordDetector = require("ChordDetector")

-- =====================================================
-- UI State
-- =====================================================

local UI = {
  window_title = "Chord Detector",
  detected_chord = "---",
  last_notes = {},
  auto_detect = true,
  font_size = 32,
  history = {},
  max_history = 10,
  bg_color = {r = 0.1, g = 0.1, b = 0.1},
  text_color = {r = 1.0, g = 1.0, b = 1.0},
  chord_color = {r = 0.2, g = 0.8, b = 1.0},
}

-- =====================================================
-- Main Detection Function
-- =====================================================

local function detectAndUpdate()
  local notes = ChordDetector.getMIDINotesFromSelection()
  
  if #notes == 0 then
    UI.detected_chord = "---"
    return
  end
  
  -- Check if notes changed
  local notesChanged = false
  if #notes ~= #UI.last_notes then
    notesChanged = true
  else
    for i, note in ipairs(notes) do
      if note ~= UI.last_notes[i] then
        notesChanged = true
        break
      end
    end
  end
  
  if notesChanged then
    UI.last_notes = notes
    local chord = ChordDetector.detectFromNotes(notes)
    UI.detected_chord = chord
    
    -- Add to history
    table.insert(UI.history, 1, chord)
    if #UI.history > UI.max_history then
      table.remove(UI.history)
    end
  end
end

-- =====================================================
-- Drawing Functions
-- =====================================================

local function drawMainChord()
  -- Draw background
  gfx.set(UI.bg_color.r, UI.bg_color.g, UI.bg_color.b)
  gfx.rect(0, 0, gfx.w, gfx.h, true)
  
  -- Draw title
  gfx.set(UI.text_color.r, UI.text_color.g, UI.text_color.b)
  gfx.setfont(1, "Arial", 16)
  gfx.x = 20
  gfx.y = 20
  gfx.drawstr("Detected Chord:")
  
  -- Draw large chord name
  gfx.set(UI.chord_color.r, UI.chord_color.g, UI.chord_color.b)
  gfx.setfont(1, "Arial", UI.font_size, 'b')
  
  local chord_text = UI.detected_chord
  local str_w, str_h = gfx.measurestr(chord_text)
  gfx.x = (gfx.w - str_w) / 2
  gfx.y = (gfx.h * 0.35 - str_h) / 2
  gfx.drawstr(chord_text)
  
  -- Draw selected notes
  gfx.set(UI.text_color.r, UI.text_color.g, UI.text_color.b)
  gfx.setfont(1, "Arial", 12)
  gfx.x = 20
  gfx.y = gfx.h * 0.5
  gfx.drawstr("Selected Notes:")
  
  local notes_str = ""
  for i, note in ipairs(UI.last_notes) do
    local note_name = ChordDetector.numberToNoteName(note)
    notes_str = notes_str .. note_name .. " (MIDI: " .. note .. ")"
    if i < #UI.last_notes then
      notes_str = notes_str .. " | "
    end
  end
  
  gfx.x = 20
  gfx.y = gfx.h * 0.55
  gfx.drawstr(notes_str)
  
  -- Draw history label
  gfx.x = 20
  gfx.y = gfx.h * 0.7
  gfx.drawstr("Recent Detections:")
  
  -- Draw history
  local history_y = gfx.h * 0.75
  for i, chord in ipairs(UI.history) do
    gfx.x = 20
    gfx.y = history_y + (i - 1) * 20
    if i == 1 then
      gfx.set(UI.chord_color.r, UI.chord_color.g, UI.chord_color.b)
    else
      gfx.set(UI.text_color.r * 0.7, UI.text_color.g * 0.7, UI.text_color.b * 0.7)
    end
    gfx.drawstr(tostring(i) .. ". " .. chord)
  end
end

-- =====================================================
-- Mouse Interaction
-- =====================================================

local function handleMouseClick()
  local mouse_x = gfx.mouse_x
  local mouse_y = gfx.mouse_y
  
  -- Refresh button (top right)
  if mouse_x > gfx.w - 100 and mouse_x < gfx.w - 10 and mouse_y > 10 and mouse_y < 40 then
    detectAndUpdate()
    gfx.mouse_cap = 0
  end
  
  -- Clear history button
  if mouse_x > gfx.w - 100 and mouse_x < gfx.w - 10 and mouse_y > 50 and mouse_y < 80 then
    UI.history = {}
    gfx.mouse_cap = 0
  end
end

-- =====================================================
-- Window Setup and Loop
-- =====================================================

local function setup()
  gfx.init(UI.window_title, 600, 500, 0, 50, 50)
end

local function main()
  -- Check for window close
  if gfx.getchar() == -1 then
    return false
  end
  
  -- Handle mouse input
  if gfx.mouse_cap & 1 == 1 then
    handleMouseClick()
  end
  
  -- Auto-detect chords
  if UI.auto_detect then
    detectAndUpdate()
  end
  
  -- Draw UI
  drawMainChord()
  
  -- Draw buttons
  gfx.set(0.3, 0.3, 0.3)
  gfx.rect(gfx.w - 100, 10, 90, 30, true)
  gfx.set(1, 1, 1)
  gfx.setfont(1, "Arial", 11)
  gfx.x = gfx.w - 95
  gfx.y = 16
  gfx.drawstr("Refresh")
  
  gfx.set(0.3, 0.3, 0.3)
  gfx.rect(gfx.w - 100, 50, 90, 30, true)
  gfx.set(1, 1, 1)
  gfx.x = gfx.w - 95
  gfx.y = 56
  gfx.drawstr("Clear")
  
  gfx.update()
  
  -- Continue loop
  reaper.defer(main)
end

-- =====================================================
-- Startup
-- =====================================================

setup()
main()
