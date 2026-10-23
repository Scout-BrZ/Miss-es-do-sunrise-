local missions = require("missions")
local mission = require(missions.CAMPAIGN_SOCIAL_SPACE_D2)
local lib = require("lib.mission_lib")

-- The Farm. One bubble, one authored state, region 0.
-- Squads first, then the state: the rest binds under its lease.
-- A paired scene over the same anchors is one place twice. One group per place.

local FARM_STATE = lib.one(mission.states.STATE_80B84013_0000_0000_80B84012, "farm state")

local SQUADS = lib.list(
    -- Teste: somente Tyra Karn.
    mission.Squad.SQ_CRYPTARCH,
    -- Suraya Hawthorne.
    mission.Squad.SQ_HAWTHORNE

)

local OBJECTS = lib.list(
    -- vendor plaza dressing and its three frames
    mission.Slot.O_FALCON_1,
    mission.Slot.O_SHAXX_BANNER_1,
    mission.Slot.O_SHAXX_BANNER_2,
    mission.Slot.O_REDJACK_GUARD_1,
    mission.Slot.O_REDJACK_GUARD_2,
    mission.Slot.O_REDJACK_GUARD_3,
    mission.Slot.POT_CIVILIAN_FEM02_DATAPAD_STAND,

    -- the two cleaner circles behind the foreman
    mission.Slot.O_CLEANER_1_80B8477A,
    mission.Slot.O_CLEANER_2_80B8477A,
    mission.Slot.O_CLEANER_3_80B8477A,
    mission.Slot.O_CLEANER_4_80B8477A,
    mission.Slot.O_CLEANER_5_80B8477A,
    mission.Slot.O_CLEANER_6_80B8477A,
    mission.Slot.O_CLEANER_1_80B84792,
    mission.Slot.O_CLEANER_2_80B84792,
    mission.Slot.O_CLEANER_3_80B84792,
    mission.Slot.O_CLEANER_4_80B84792,
    mission.Slot.O_CLEANER_5_80B84792,
    mission.Slot.O_CLEANER_6_80B84792,

    -- welders. Each group is its own bay; a repeated animation name is not one actor twice.
    mission.Slot.POT_CIV_MAINT_FEM01_WELD_FORWARD_1_80B849F4,
    mission.Slot.POT_CIV_MAINT_MALE01_DPAD_TYPING_STAND_1,
    mission.Slot.POT_CIV_MAINT_MALE02_WELD_DOWN_1_80B849F4,
    mission.Slot.POT_CIV_MAINT_FEM02_WELD_UP_1,
    mission.Slot.POT_CIV_MAINT_FEM01_WELD_FORWARD_1_80B84A04,
    mission.Slot.POT_CIV_MAINT_MALE02_WELD_DOWN_1_80B84A04,
    mission.Slot.POT_CIV_MAINT_FEM01_WELD_DOWN_1,
    mission.Slot.POT_CIV_MAINT_FEM01_WELD_FORWARD_2,

    -- the hawk each kept scene carries
    mission.Slot.O_HAWK_AWAY_TEAM_80B845C8,
    mission.Slot.O_HAWK_AWAY_TEAM_80B84746,
    mission.Slot.O_SOCCER_HAWK,

    -- the ball. Its goals, scoreboards and flares stay out: nothing keeps score.
    mission.Slot.O_MILITARY_FOOTBALL
)

-- TODO: drive the Vertigo course (80B849B3 orbs and waypoints); no script owns its stages yet.
-- TODO: drive the field's goals and scoreboards (80B847F7); no script owns the score yet.
-- TODO: place 80B847EC's ship and commando once the farm cinematics are understood.
-- TODO: name 80B84A18's four objects before activating them.

local SCENES = lib.list(
    mission.Scene.SC_FIREPLACE_TRIO_FOCUS,
    mission.Scene.DAY_GRASS_WALKERS_1_SCENE,
    mission.Scene.DAY_GRASS_WALKERS_5_SCENE,
    mission.Scene.FARM_AWAY_TEAM_A,
    mission.Scene.FARM_SOCCER_HAWK_FLIGHT,
    mission.Scene.ARRIVAL_SCENE,
    mission.Scene.FARM_WORKERS_WALK_1
)

-- A sensor holds one state. Where the data authors several, the first ordinal is the idle.
local function idle(name, sensor, state)
    return {sensor = lib.one(sensor, name .. " sensor"), state = lib.one(state, name .. " idle")}
end

local IDLES = lib.list(
    idle("zavala", mission.Slot.SQ_ZAVALA_IDLE,
        mission.PerformanceState.SQ_ZAVALA_IDLE.STATE_08BA6CD2),
    idle("ikora", mission.Slot.SQ_IKORA_IDLE,
        mission.PerformanceState.SQ_IKORA_IDLE.STATE_C7D3EBEA),
    idle("cayde", mission.Slot.SQ_CAYDE_IDLE,
        mission.PerformanceState.SQ_CAYDE_IDLE.STATE_11D3E6E3),
    idle("artie", mission.Slot.SQ_ARTIE_IDLE,
        mission.PerformanceState.SQ_ARTIE_IDLE.STATE_806FF3C1),
    idle("crucible", mission.Slot.SQ_CRUCIBLE_IDLE,
        mission.PerformanceState.SQ_CRUCIBLE_IDLE.STATE_D9474D64),
    -- Tyra Karn: o Cryptarch da Chácara.
    -- O estado 6996DACA é o idle usado pelo Dawn para esse NPC.
    idle("tyra_karn", mission.Slot.SQ_CRYPTARCH_IDLE,
        mission.PerformanceState.SQ_CRYPTARCH_IDLE.STATE_6996DACA),
    idle("hawthorne", mission.Slot.SQ_HAWTHORNE_IDLE,
        mission.PerformanceState.SQ_HAWTHORNE_IDLE.STATE_FD41C0E5),
    idle("postmaster", mission.Slot.SQ_POSTMASTER_IDLE,
        mission.PerformanceState.SQ_POSTMASTER_IDLE.STATE_870A7D66)
)

-- The Eververse sensor has no authored state, so that vendor gets no idle request.

-- A reattach reopens this script in a fresh VM, so the mark lives in mission state.
local BUILT_KEY = "farm_built"

local function build(context)
    lib.place_all(context, SQUADS, context.sdk.squad_modes.reinforce)
    context:select_state(FARM_STATE)
    context:activate_objects{slots = OBJECTS, active = true}
    lib.activate_scenes(context, SCENES)
    lib.play_idles(context, IDLES)
end

return {
    on_event_region_changed = function(context, state, event)
        if event.region_index ~= FARM_STATE.region_index or state:variable(BUILT_KEY) then
            return
        end
        context:set_variable(BUILT_KEY, true)
        build(context)
    end,
    
}
