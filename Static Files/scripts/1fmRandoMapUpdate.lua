LUAGUI_NAME = "1fmRandoMapUpdate"
LUAGUI_AUTH = "culk"
LUAGUI_DESC = "Kingdom Hearts 1FM Randomizer Update Tracker Map Tab"

-- TODO: test if can use global util functions

local game_version = 1

if os.getenv('LOCALAPPDATA') ~= nil then
    client_communication_path = os.getenv('LOCALAPPDATA') .. "\\KH1FM\\"
else
    client_communication_path = os.getenv('HOME') .. "/KH1FM/"
    ok, err, code = os.rename(client_communication_path, client_communication_path)
    if not ok and code ~= 13 then
        os.execute("mkdir " .. path)
    end
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function read_world()
    --[[Gets the numeric value of the currently occupied world]]
    local world_address = {0x2340E5C, 0x233FE84}
    return ReadByte(world_address[game_version])
end

function read_room()
    --[[Gets the numeric value of the currently occupied room]]
    local room_address = {0x2340E5C + 0x68, 0x233FE84 + 0x8}
    return ReadByte(room_address[game_version])
end

function is_in_gummi_ship()
    local inGummi = {0x50832D, 0x5075A8}
    return ReadByte(inGummi[game_version]) ~= 0
end

function read_gummi_select()
    local gummiselect = {0x507D7C, 0x50707C}
    return ReadByte(gummiselect[game_version])
end

function write_map_update_file(world_id, room_id)
    map_update_date = os.date("!%Y%m%d%H%M%S")
    --map_update_file_path = client_communication_path .. "mapupdate" .. "_" .. tostring(map_update_date) .. "_" .. tostring(world_id) .. "_" .. tostring(room_id) .. "_" .. tostring(current_gummi) .. "_" .. tostring(current_gummi_select)
    map_update_file_path = client_communication_path .. "mapupdate" .. "_" .. tostring(map_update_date) .. "_" .. world_id .. "_" .. room_id
    if not file_exists(map_update_file_path) then
        file = io.open(map_update_file_path, "w")
        io.output(file)
        io.write("")
        io.close(file)
    end
end

local canExecute = false

function _OnInit()
    IsEpicGLVersion  = 0x3A2B86
    IsSteamGLVersion = 0x3A29A6
    if GAME_ID == 0xAF71841E and ENGINE_TYPE == "BACKEND" then
        if ReadByte(IsEpicGLVersion) == 0xF0 then
            ConsolePrint("Epic Version Detected")
            game_version = 1
            canExecute = true
        end
        if ReadByte(IsSteamGLVersion) == 0xF0 then
            ConsolePrint("Steam Version Detected")
            game_version = 2
            canExecute = true
        end
    end
end

local WORLD_ID_OVERVIEW = 0
local WORLD_ID_AGRABAH = 8

-- Initialize world state.
local update_world = 0
local last_seen_world = 0
local last_seen_room = 0
local gummi_select = 255

function _OnFrame()
    if canExecute then
        local is_update = false
        if is_in_gummi_ship() then
            if update_world ~= WORLD_ID_OVERVIEW then
                -- Boarded gummi ship. Update map to Overworld.
                update_world = WORLD_ID_OVERVIEW
                last_seen_room = 0
                is_update = true
            end
        else
            if last_seen_world ~= read_world() then
                -- Current world changed. Update map to new world unless gummi select already updated.
                last_seen_world = read_world()
                if update_world ~= last_seen_world then
                    update_world = last_seen_world
                    is_update = true
                end
            elseif gummi_select ~= read_gummi_select() then
                -- Gummi travel selected for new world. Update map to new world.
                gummi_select = read_gummi_select()
                update_world = gummi_select
                is_update = true
            elseif last_seen_world ~= update_world then
                -- No longer in gummi ship. Returned to previous world.
                update_world = last_seen_world
                is_update = true
            end
            if update_world == WORLD_ID_AGRABAH and last_seen_room ~= read_room() then
                -- Update map for a room change in Agrabah due to Cave of Wonders.
                last_seen_room = read_room()
                is_update = true
            end
        end

        if is_update then
            write_map_update_file(update_world, last_seen_room)
        end
    end
end
