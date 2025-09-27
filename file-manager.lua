function filemanager_current_version()
  return "v0.1.6"
end

function sanitize_filename(str)
  str = tostring(str or "")
  -- Replace entities and separators
  str = str:gsub("&", " and ")
  str = str:gsub(":%s*", " - ")                   -- normalize any colon to " - "
  -- Remove/replace Windows-invalid and control chars: \ / : * ? " < > | and control chars
  str = str:gsub("[%c%z<>:\"/\\|%?%*]+", "-")
  -- Collapse runs of space/._- to a single char
  str = str:gsub("[%s%._%-]+", function(s) return s:sub(1,1) end)
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
  -- Padding is determined from the number of episodes of the same type in the anime (#tostring() gives the number of digits required, e.g. 10 eps -> 2 digits)
  -- Padding is at least 2 digits
  local totalEpisodes = 0
  if anime.episodecounts and episode and episode.type and anime.episodecounts[episode.type] then
    totalEpisodes = anime.episodecounts[episode.type]
  end
  local epnumpadding = math.max(#tostring(totalEpisodes), 2)
  episodenumber = episode_numbers(epnumpadding) .. fileversion

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

local dublangs = from({})
if file.media and file.media.audio then
  dublangs = from(file.media.audio):select("language"):distinct()
end
local sublangs = from({})
if file.media and file.media.sublanguages then
  sublangs = from(file.media.sublanguages):distinct()
end

local source = ""
if file.anidb then
  source = file.anidb.source or ""
  -- Dub and sub languages from anidb are usually more accurate
  -- But will return a single unknown language if there is none, needs to be fixed in Shoko
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

local langtag = ""
local nonnativedublangs = dublangs:except({ Language.Japanese, Language.Chinese, Language.Korean, Language.Unknown })
if nonnativedublangs:count() == 1 and dublangs:count() == 2 then
  langtag = "[DUAL]"
elseif dublangs:count() > 2 then
  langtag = "[MULTI]"
elseif nonnativedublangs:count() > 0 then
  langtag = "[DUB]"
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
