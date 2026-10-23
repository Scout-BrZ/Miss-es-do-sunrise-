-- Trilha de Adieu: índices musicais usados pelo controlador do Dawn.
local missions = require("missions")
local mission = require(missions.MISSION_JOURNEY)
local music = {}

function music.play(context, state, section)
    local previous = state:variable("journey.music.section")
    -- Não repete nem deixa um gatilho antigo substituir a trilha mais adiantada.
    if previous == section or previous == 0
        or (section ~= 0 and previous ~= nil and previous > section) then return end
    context:slot(mission.Slot.M_MUSIC_SENSOR_80B5E02A):set_music_section {
        section = section, enabled = true,
    }
    -- Registra a solicitação, não uma confirmação de áudio do cliente.
    context:set_variable("journey.music.section", section)
end

function music.on_arrival(context, state, event)
    if event.entered ~= true or event.held_region_index ~= 24 then return end
    local section = state:variable("journey.music.pending")
    if section then
        music.play(context, state, section)
        context:clear_variable("journey.music.pending")
    end
end
return music
