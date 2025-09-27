function filemanager_current_version()
  return "v0.2.1"
end

function sanitize_filename(str)
  str = tostring(str or "")
  -- Replace entities and separators
  str = str:gsub("&", " and ")
  str = str:gsub(":%s*", " - ")                   -- normalize any colon to " - "
  -- Remove/replace Windows-invalid and control chars: \ / : * ? " < > | and control chars
  str = str:gsub("[%c%z<>:\"/\\|%?%*]+", "-")
  -- Collapse repeated separators but preserve spaced hyphen separators
  -- Collapse runs within each class first
  str = str:gsub("%s+", " ")
  str = str:gsub("_+", "_")
  str = str:gsub("%.+", ".")
  str = str:gsub("%-+", "-")
  -- Normalize only hyphens that already have spaces around to a single " - "
  str = str:gsub("%s+%-%s+", " - ")
  -- Trim leading/trailing separators, spaces, and dots
  str = str:gsub("^[%s%._%-]+", ""):gsub("[%s%._%-]+$", "")
  return str
end

function is_in_list(str, list)
  local str_lower = str:lower()
  for _, v in ipairs(list) do
    if str_lower:sub(1, #v:lower()) == v:lower() then
      return true
    end
  end
  return false
end

function is_hentai(a_name)
    local hentai = anime.restricted
    -- this function is a hack because it is totally arbitrary
    -- there are some titles that we choose to override the anidb classification
    local hentai_titles = {
        "Apocalypse Zero",
        "Bikini Warriors",
        "Cream Lemon",
        "Harem in the Labyrinth of Another World",
        "High School D",
        "Interspecies Reviewers",
        "Kodomo no Jikan",
        "Lemon Angel",
        "Lemon Cream",
        "Midori",
        "Nukitashi The Animation",
        "Queen's Blade",
        "School Days",
        "Violence Jack",
        "Wicked City",
    }
    if is_in_list(a_name, hentai_titles) then
        hentai = true
    end
    return hentai
end

local maxnamelen = 77
local spacechar = " "

local animename = anime:getname(Language.English) or anime.preferredname

local episodename = ""
local engepname = episode:getname(Language.English) or ""
local episodenumber = ""

-- If the episode is not a complete movie then add an episode number/name
if anime.type ~= AnimeType.Movie or not engepname:find("^Complete Movie") then
  local fileversion = ""
  if (file.anidb and file.anidb.version > 1) then
    fileversion = "v" .. file.anidb.version
  end
  -- Padding previously used total episode count with a minimum of 2 digits.
  -- Remove zero padding entirely by forcing padding to 1 digit.
  local epnumpadding = 1
  -- Add prefix for non-regular episode types
  local epprefix = ""
  if episode and episode.type and episode.type ~= EpisodeType.Episode then
    if episode.type == EpisodeType.Credits then
      epprefix = "C"
    elseif episode.type == EpisodeType.Special then
      epprefix = "S"
    elseif episode.type == EpisodeType.Trailer then
      epprefix = "T"
    else
      epprefix = "X"
    end
  end
  episodenumber = epprefix .. episode_numbers(epnumpadding) .. fileversion

  -- If this file is associated with a single episode and the episode doesn't have a generic name, then add the episode name
  if #episodes == 1 and not engepname:find("^Episode") and not engepname:find("^OVA") then
    episodename = episode:getname(Language.English) or ""
  end
end

local res, codec, bitdepth = "", "", ""
if file.media and file.media.video then
  res = file.media.video.res or ""
  codec = file.media.video.codec or ""
  if file.media.video.bitdepth and file.media.video.bitdepth ~= 8 then
    bitdepth = file.media.video.bitdepth .. "bit"
  end
end

-- Build ordered audio track list and language summaries
local audioTracks = {}
local dublangs = from({})
if file.media and file.media.audio then
  audioTracks = file.media.audio
  dublangs = from(file.media.audio):select("language"):distinct()
end
local sublangs = from({})
if file.media and file.media.sublanguages then
  sublangs = from(file.media.sublanguages):distinct()
end

local source = ""
if file.anidb then
  source = file.anidb.source or ""
  -- Dub and sub languages from anidb are usually more accurate for summaries,
  -- but we use actual file tracks (audioTracks) for DUB/DUAL/MULTI tagging to preserve order/count.
  if file.anidb.media then
    if file.anidb.media.dublanguages then
      local dublangs_r = from(file.anidb.media.dublanguages):distinct()
      if dublangs_r:first() ~= "unk" then
        dublangs = dublangs_r
      end
    end
    if file.anidb.media.sublanguages then
      local sublangs_r = from(file.anidb.media.sublanguages):distinct()
      if sublangs_r:first() ~= "unk" then
        sublangs = sublangs_r
      end
    end
  end
end

local movie_info = "(" .. table.concat({ res, codec, bitdepth, source }, " "):cleanspaces(spacechar) .. ")"
local ep_info = "(" .. table.concat({ res, codec }, " "):cleanspaces(spacechar) .. ")"

-- Determine native language from AniDB titles (UDP ANIME titles proxy via Shoko API)
local function get_native_language_from_anidb()
  local candidates = { Language.Japanese, Language.Korean, Language.Chinese }
  for _, lang in ipairs(candidates) do
    local title = anime:getname(lang)
    if title and title ~= "" then
      return lang
    end
  end
  -- Fallback
  return Language.Japanese
end

-- DUB/DUAL/MULTI logic based on track count and first track language vs AniDB native language
local langtag = ""
local audioTrackCount = #audioTracks
if audioTrackCount == 2 then
  local firstAudioLang = audioTracks[1] and audioTracks[1].language or nil
  local nativeLang = get_native_language_from_anidb()
  if firstAudioLang ~= nil and nativeLang ~= nil and firstAudioLang == nativeLang then
    langtag = "[DUAL]"
  else
    langtag = "[DUB]"
  end
elseif audioTrackCount >= 3 then
  langtag = "[MULTI]"
end

local centag = ""
if file.anidb then
  if file.anidb.censored then
    centag = "[CEN]"
  end
end

local group = ""
if file.anidb then
  if file.anidb.releasegroup then
    group = "[" .. (file.anidb.releasegroup.shortname or file.anidb.releasegroup.name) .. "]"
  end
end

local fileinfo = ""
local namelist = ""

if anime.type == AnimeType.Movie then
  namelist = {
    animename:truncate(maxnamelen),
    episodenumber,
    episodename:truncate(maxnamelen),
    movie_info,
    langtag,
    centag,
    group
  }

  if is_hentai(animename) then
    destination = "Hentai Movies"
  else
    destination = "Anime Movies"
  end

else
  namelist = {
    episodenumber,
    episodename:truncate(maxnamelen),
    ep_info,
    langtag,
    centag,
    group
  }

  if is_hentai(animename) then
    destination = "Hentai"
  else
    destination = "Anime"
  end

end

subfolder = sanitize_filename(animename)
filename = sanitize_filename(table.concat(namelist, " "):cleanspaces(spacechar))
