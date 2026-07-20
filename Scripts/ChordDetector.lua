-- Chord Detector for ReaScript (Lua)
-- Detects chord names from MIDI note sequences
-- @description Chord Detection Algorithm Implementation
-- @version 1.0
-- @author fightplayer

-- =====================================================
-- 1. 音名と数値の相互変換定義
-- =====================================================

local NOTE_NAMES = {
  c = 0, ["c#"] = 1, db = 1,
  d = 2, ["d#"] = 3, eb = 3,
  e = 4, f = 5,
  ["f#"] = 6, gb = 6,
  g = 7, ["g#"] = 8, ab = 8,
  a = 9, ["a#"] = 10, bb = 10,
  b = 11
}

local NOTE_DISPLAY = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" }

-- =====================================================
-- 2. コードタイプ判定用マップの構築
-- =====================================================

local function buildStandardChordMap()
  return {
    -- Major chords
    { intervals = {0, 4, 7}, suffix = "" },                    -- Major
    { intervals = {0, 4, 7, 11}, suffix = "M7" },              -- Major 7
    { intervals = {0, 4, 7, 10}, suffix = "7" },               -- Dominant 7
    { intervals = {0, 4, 7, 9}, suffix = "6" },                -- Major 6
    { intervals = {0, 4, 7, 9, 11}, suffix = "6M7" },          -- Major 6/7
    
    -- Minor chords
    { intervals = {0, 3, 7}, suffix = "m" },                   -- Minor
    { intervals = {0, 3, 7, 11}, suffix = "mM7" },             -- Minor Major 7
    { intervals = {0, 3, 7, 10}, suffix = "m7" },              -- Minor 7
    { intervals = {0, 3, 7, 9}, suffix = "m6" },               -- Minor 6
    { intervals = {0, 3, 6}, suffix = "dim" },                 -- Diminished
    { intervals = {0, 3, 6, 10}, suffix = "m7b5" },            -- Half-diminished
    { intervals = {0, 3, 6, 9}, suffix = "dim7" },             -- Diminished 7
    
    -- Suspended chords
    { intervals = {0, 2, 7}, suffix = "sus2" },                -- Suspended 2
    { intervals = {0, 5, 7}, suffix = "sus4" },                -- Suspended 4
    { intervals = {0, 2, 7, 10}, suffix = "sus2(7)" },         -- Suspended 2 with 7
    { intervals = {0, 5, 7, 10}, suffix = "sus4(7)" },         -- Suspended 4 with 7
    
    -- Extended chords
    { intervals = {0, 4, 7, 11, 2}, suffix = "M7add9" },       -- Major 7 add 9
    { intervals = {0, 4, 7, 10, 2}, suffix = "7add9" },        -- Dominant 7 add 9
    { intervals = {0, 3, 7, 10, 2}, suffix = "m7add9" },       -- Minor 7 add 9
    
    -- Power chords and simple intervals
    { intervals = {0, 7}, suffix = "5" },                      -- Power chord
    { intervals = {0, 3}, suffix = "m3" },                     -- Just minor third
    { intervals = {0, 4}, suffix = "M3" },                     -- Just major third
  }
end

local function buildGeneratedChordMap()
  local map = {}
  
  -- Generate all combinations of common intervals
  local thirds = {{0, 3, "m"}, {0, 4, ""}}
  local fifths = {{0, 6, "b5"}, {0, 7, ""}, {0, 8, "#5"}}
  local sevenths = {{10, "7"}, {11, "M7"}}
  local ninths = {{2, "9"}, {3, "b9"}}
  local elevenths = {{5, "11"}}
  local thirteenths = {{9, "13"}}
  
  -- Build basic triad combinations
  for _, third_data in ipairs(thirds) do
    for _, fifth_data in ipairs(fifths) do
      if fifth_data[1] ~= 0 then
        local intervals = {third_data[1], fifth_data[1]}
        local suffix = third_data[3] .. (fifth_data[3] ~= "" and fifth_data[3] or "")
        table.insert(map, {intervals = intervals, suffix = suffix})
      end
    end
  end
  
  return map
end

-- =====================================================
-- 3. コア判定ロジック
-- =====================================================

local function normalizeNotes(noteArray)
  if #noteArray == 0 then return {} end
  
  local notes = {}
  local baseNote = noteArray[1]
  
  for i, note in ipairs(noteArray) do
    local relativeNote = note % 12
    if i > 1 and relativeNote < (notes[i-1] % 12) then
      relativeNote = relativeNote + 12
    end
    table.insert(notes, relativeNote)
  end
  
  return notes
end

local function getIntervals(noteArray)
  if #noteArray == 0 then return {} end
  
  local normalized = normalizeNotes(noteArray)
  local baseNote = normalized[1]
  local intervals = {}
  
  for _, note in ipairs(normalized) do
    table.insert(intervals, (note - baseNote) % 12)
  end
  
  table.sort(intervals)
  return intervals
end

local function intervalsToString(intervals)
  return table.concat(intervals, ",")
end

local function findChordMatch(intervals, chordMaps)
  for _, map in ipairs(chordMaps) do
    for _, chord_def in ipairs(map) do
      local sortedChord = {}
      for _, iv in ipairs(chord_def.intervals) do
        table.insert(sortedChord, iv)
      end
      table.sort(sortedChord)
      
      local sortedIntervals = {}
      for _, iv in ipairs(intervals) do
        table.insert(sortedIntervals, iv)
      end
      table.sort(sortedIntervals)
      
      if intervalsToString(sortedChord) == intervalsToString(sortedIntervals) then
        return chord_def.suffix
      end
    end
  end
  
  return nil
end

-- =====================================================
-- 4. 転回形とオンベース判定
-- =====================================================

local function detectChord(noteArray, chordMaps)
  if #noteArray == 0 then return "?" end
  
  local candidates = {}
  local baseNoteName = NOTE_DISPLAY[(noteArray[1] % 12) + 1]
  
  -- 1. 基本判定
  local intervals = getIntervals(noteArray)
  local suffix = findChordMatch(intervals, chordMaps)
  if suffix then
    table.insert(candidates, baseNoteName .. suffix)
  end
  
  -- 2. ベース音固定 + 上部和音の転回判定
  if #noteArray > 1 then
    for rotation = 1, #noteArray - 1 do
      local rotated = {}
      for i = rotation, #noteArray do
        table.insert(rotated, noteArray[i])
      end
      
      local rotIntervals = getIntervals(rotated)
      local rotSuffix = findChordMatch(rotIntervals, chordMaps)
      if rotSuffix then
        table.insert(candidates, baseNoteName .. rotSuffix .. "/" .. NOTE_DISPLAY[(noteArray[rotation] % 12) + 1])
      end
    end
  end
  
  -- 3. 全体の転回判定
  for rotation = 1, #noteArray - 1 do
    local rotated = {}
    for i = 0, #noteArray - 1 do
      table.insert(rotated, noteArray[((i + rotation - 1) % #noteArray) + 1])
    end
    
    local rotIntervals = getIntervals(rotated)
    local rotSuffix = findChordMatch(rotIntervals, chordMaps)
    if rotSuffix then
      table.insert(candidates, NOTE_DISPLAY[(rotated[1] % 12) + 1] .. rotSuffix .. "/" .. baseNoteName)
    end
  end
  
  -- =====================================================
  -- 5. 候補の集約とスコアリング
  -- =====================================================
  
  -- 重複排除
  local uniqueCandidates = {}
  local seen = {}
  for _, cand in ipairs(candidates) do
    if not seen[cand] then
      table.insert(uniqueCandidates, cand)
      seen[cand] = true
    end
  end
  
  if #uniqueCandidates == 0 then
    return baseNoteName .. "?"
  elseif #uniqueCandidates == 1 then
    return uniqueCandidates[1]
  else
    -- スコアリング
    local function scoreChord(chordName)
      local score = 0
      
      -- Penalize complex notations
      if string.find(chordName, "omit") then score = score - 3 end
      if string.find(chordName, "/") then score = score - 2 end
      
      local commaCount = #chordName - #(chordName:gsub(",", ""))
      score = score - commaCount
      
      -- Favor simpler notations
      local length = #chordName
      score = score - length * 0.1
      
      return score
    end
    
    local bestChord = uniqueCandidates[1]
    local bestScore = scoreChord(bestChord)
    
    for i = 2, #uniqueCandidates do
      local score = scoreChord(uniqueCandidates[i])
      if score > bestScore then
        bestScore = score
        bestChord = uniqueCandidates[i]
      end
    end
    
    return bestChord
  end
end

-- =====================================================
-- 6. パブリック API
-- =====================================================

local ChordDetector = {}

function ChordDetector.detectFromNotes(noteArray)
  local standardMap = buildStandardChordMap()
  local generatedMap = buildGeneratedChordMap()
  
  return detectChord(noteArray, {standardMap, generatedMap})
end

function ChordDetector.noteNameToNumber(noteName)
  return NOTE_NAMES[string.lower(noteName)] or 0
end

function ChordDetector.numberToNoteName(number)
  return NOTE_DISPLAY[(number % 12) + 1]
end

-- =====================================================
-- 7. ユーティリティ関数
-- =====================================================

function ChordDetector.getMIDINotesFromSelection()
  if not reaper then return {} end
  
  local notes = {}
  local take = reaper.MIDIEditor_GetActiveTake(reaper.MIDIEditor_GetActive())
  
  if not take then return {} end
  
  local i = 0
  repeat
    local retval, selected, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_EnumSelNotes(take, i)
    if retval == -1 then break end
    if selected then
      table.insert(notes, pitch)
    end
    i = i + 1
  until retval == -1
  
  table.sort(notes)
  return notes
end

-- =====================================================
-- 8. 使用例とテスト
-- =====================================================

function ChordDetector.runTests()
  if not reaper then return end
  
  local testCases = {
    {60, 64, 67},          -- C major (C E G)
    {60, 63, 67},          -- C minor (C Eb G)
    {60, 64, 67, 71},      -- C major 7 (C E G B)
    {60, 64, 67, 70},      -- C dominant 7 (C E G Bb)
    {60, 65, 67},          -- C sus4 (C F G)
    {64, 67, 60},          -- C/E (first inversion)
    {67, 60, 64},          -- C/G (second inversion)
  }
  
  reaper.ShowConsoleMsg("=== Chord Detection Test ===\n")
  for _, notes in ipairs(testCases) do
    local notesStr = table.concat(notes, " ")
    local chord = ChordDetector.detectFromNotes(notes)
    reaper.ShowConsoleMsg(string.format("Notes: %s -> %s\n", notesStr, chord))
  end
end

return ChordDetector
