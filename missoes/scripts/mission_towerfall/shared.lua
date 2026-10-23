-- Nomes compartilhados por todas as áreas de Homecoming (Retorno ao Lar). Os nomes gerados que são claros (Slot.PT_SHAXX_ENTERS,
-- Squad.SQ_SHAXX) são usados diretamente; este arquivo dá nomes mais claros aos demais: os estados da missão,
-- seus três sensores e suas referências de diálogo.
local missions = require("missions")
local mission = require(missions.MISSION_TOWERFALL)
local campaign = require("mission_towerfall.campaign")

local shared = {
    mission = mission,
    Slot = mission.Slot,
    Squad = mission.Squad,
    Directive = mission.Directive,
    scenes = mission.scenes,
    TaskGroup = mission.TaskGroup,
    unit = campaign.unit,
    line = campaign.line,
    directive_sensor = mission.Slot.M_DIRECTIVE_SENSOR_80B50913,
    dialogue_sensor = mission.Slot.M_DIALOG_SENSOR_80B50913,
    music_sensor = mission.Slot.M_MUSIC_SENSOR_80B50913,
    cue = mission.DialogueCue.M_DIALOG_SENSOR_80B50913,

}
-- Estado jogável de cada área e estados de ordinal 1 que contêm uma cena cinematográfica.
local states = mission.states
shared.states = {
    boulevard = states.STATE_80B500BC_0000_0000_80B500AD,   -- área 0, região 0
    outro = states.STATE_80B500BC_0001_0001_80B500AF,       -- área 1, região 9: cena cinematográfica final
    opening = states.STATE_80B500BC_0002_0001_80B500B1,     -- área 2, região 17: prefab_hro
    military = states.STATE_80B500BC_0004_0000_80B500B3,    -- área 4, região 32
    plaza = states.STATE_80B500BC_0006_0000_80B500B6,       -- área 6, região 48
    ship = states.STATE_80B500BC_0008_0000_80B500B8,        -- área 8, região 64
    boarding = states.STATE_80B500BC_0008_0001_80B500B9,    -- área 8, região 65: cena cinematográfica intermediária
    underwatch = states.STATE_80B500BC_0009_0000_80B500BB,  -- área 9, região 72
 }

 return shared