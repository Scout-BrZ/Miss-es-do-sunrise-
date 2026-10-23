-- Underwatch (área 9, região 72): do despertar até o salto para descer ao hangar.
local shared = require("mission_towerfall.shared")
local Slot, Squad, Directive, TaskGroup = shared.Slot, shared.Squad, shared.Directive,
    shared.TaskGroup
local scenes, cue = shared.scenes, shared.cue
local unit, line = shared.unit, shared.line
local shaxx_key = scenes.SCENE_SHAXX.event_keys

local underwatch = {}

underwatch.legs = {
    {id = "underwatch", state = shared.states.underwatch, arm = {
        Slot.PT_START, Slot.PT_SC_UNDERWATCH_INTRO_STAND, Slot.PT_WALL_EXPLODE,
        Slot.PT_CENTURION_INTRO, Slot.PT_CENTURION_INTRO_REINFORCE, Slot.PT_SHAXX_ENTERS,
        Slot.PT_SC_CIVILIAN_GROUND_1_LOOK, Slot.PT_SC_CIVILIAN_WALL_SIT_C, Slot.PT_SC_CIVILIANS_MID,
        Slot.PT_HERO_MOMENT, Slot.PT_WEAPON, Slot.PT_WEAPON_COMPLETE, Slot.PT_GOTO_MILITARY,
        Slot.PT_NUX_JUMP,
    }},
}

underwatch.steps = {
    -- pt_start só envia o evento quando o cliente já está no mundo, após a transição visual da chegada.
    {id = "wake", barrier = true, lines = {line(cue.CUE_1)}, music = 1,
        ends = {trigger = Slot.PT_START}},
    -- A cena de Cayde reproduz suas próprias falas e não informa as falas nem seu término: o objetivo muda
    -- 13,5 segundos após o início da cena, quando a última fala já terminou.
    {id = "home", directive = Directive.DEFEND_YOUR_HOME, navpoint = Slot.AP_IKORA,
        sequence = {
            {on = Slot.PT_SHAXX_ENTERS},
            {spoken = cue.CUE_10, after_ms = 2000,
                scenes = {{scene = scenes.SCENE_CAYDE_GOLDEN_GUN}}},
            {after_ms = 13500},
        },
        ends = {sequence = true}},
    -- Uma cena deixada em execução recomeça quando o cliente recarrega a Underwatch.
    {id = "find_zavala", directive = Directive.FIND_ZAVALA,
        sequence = {{after_ms = 3000, stop = {scenes.SCENE_CAYDE_GOLDEN_GUN}}},
        -- O salto para descer ao hangar, depois da área de ativação da fala CUE_30.
        ends = {trigger = Slot.PT_NUX_JUMP}},
}

-- Presentes desde o início: suas cenas os animam, mas não os criam. Ficam de fora os civis de teste,
-- o civil do momento heroico e wall_sit_c, cuja posição fica dentro da porta de Shaxx.
local CIVILIANS = {
    "SQ_CIVILIAN_CATATONIC", "SQ_CIVILIAN_KNEEL", "SQ_CIVILIAN_STAND", "SQ_CIVILIAN_WALL_SIT_A",
    "SQ_CIVILIAN_WALL_SIT_B", "SQ_CIVILIAN_GROUND_1", "SQ_CIVILIAN_GROUND_2",
    "SQ_CIVILIAN_ON_KNEES_CRYING",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_BENT_DOOR_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_BENT_INJURED_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_ARMS_WRAPPED_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_CROUCH_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_WORRIED_1_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_INJURED_WALL_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_CLASPED_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_CLASPED_FEMALE_SQ_CIVILIAN_REACT",
    "PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_TIRED_SQ_CIVILIAN_REACT",
}
local civilians = {}
for index, name in ipairs(CIVILIANS) do civilians[index] = unit(Squad[name], Slot[name]) end

-- Cada civil que reage reproduz a cena de seu prefab usando apenas a primeira chave de evento.
local hallway = {
    {scene = scenes.SC_CIVILIAN_GROUND_1}, {scene = scenes.SC_CIVILIAN_GROUND_2},
    {scene = scenes.SC_CIVILIAN_ON_KNEES_CRYING}, {scene = scenes.SC_CIVILIAN_KNEEL},
    {scene = scenes.SC_CIVILIAN_CATATONIC},
}
local REACTS = {
    "BENT_DOOR", "BENT_INJURED", "ARMS_WRAPPED", "CROUCH", "WORRIED_1", "INJURED_WALL", "CLASPED",
    "CLASPED_FEMALE", "TIRED",
}
for _, name in ipairs(REACTS) do
    local scene = scenes["PF_SC_T0_UNDERWATCH_CIVILIAN_REACT_" .. name .. "_SC_CIVILIAN_REACT"]
    hallway[#hallway + 1] = {scene = scene, keys = {scene.event_keys[1]}}
end

underwatch.encounters = {
    {id = "fake_fight", squads = {
        unit(Squad.SQ_FRAME_FAKE_FIGHT, Slot.SQ_FRAME_FAKE_FIGHT),
        unit(Squad.SQ_RED_GUARD_FAKE_FIGHT, Slot.SQ_RED_GUARD_FAKE_FIGHT),
    }},
    {id = "civilians_present", squads = civilians},
    -- A cena não cria seus Cabais, por isso eles são posicionados aqui. O robô e o Guarda Vermelho são
    -- removidos antes, para evitar que os Cabais os ataquem. A fala CUE_6 acompanha a entrada do jogador na área da explosão.
    {id = "wall", after = "home", trigger = Slot.PT_SC_UNDERWATCH_INTRO_STAND,
        objective = Slot.OBJ_CABAL_FIRST_CONTACT, groups = TaskGroup.OBJ_CABAL_FIRST_CONTACT,
        squads = {
            unit(Squad.SQUAD_FIRST_CONTACT_CABAL, Slot.SQUAD_FIRST_CONTACT_CABAL),
            unit(Squad.SQUAD_FIRST_CONTACT_CABAL_BACKUP_A, Slot.SQUAD_FIRST_CONTACT_CABAL_BACKUP_A),
        },
        lines = {line(cue.CUE_5)},
        retire = {Squad.SQ_FRAME_FAKE_FIGHT, Squad.SQ_RED_GUARD_FAKE_FIGHT},
        sequence = {
            {scenes = {{scene = scenes.SCENE_CABAL_FIRST_CONTACT}},
                move = {to = "open", slots = {Slot.D_UNDERWATCH_COLLAPSING_WALL}, snap = true}},
            {on = Slot.PT_WALL_EXPLODE, after_ms = 2000, lines = {line(cue.CUE_6)}},
        }},
    -- A célula vinculada faz a cena criar o Centurião e o robô que ele empala.
    {id = "centurion", after = "home", trigger = Slot.PT_CENTURION_INTRO,
        objective = Slot.OBJ_CENTURION_INTRO, groups = TaskGroup.OBJ_CENTURION_INTRO,
        squads = {
            unit(Squad.SQ_CENTURION_INTRO_BACKUP, Slot.SQ_CENTURION_INTRO_BACKUP),
            unit(Squad.SQ_CENTURION_INTRO_RUSH, Slot.SQ_CENTURION_INTRO_RUSH),
        },
        scenes = {{scene = scenes.SC_CENTURION_INTRO, bind = {Slot.SQ_CENTURION_INTRO_CELL_1}}}},
    -- As portas só existem após serem instanciadas e ficam fechadas inicialmente. Shaxx não é um participante de sua
    -- cena e, por isso, é posicionado aqui.
    {id = "shaxx_doors", after = "home", trigger = Slot.PT_CENTURION_INTRO_REINFORCE,
        squads = {unit(Squad.SQ_SHAXX, Slot.SQ_SHAXX)},
        lines = {line(cue.CUE_10)},
        objects = {slots = {Slot.O_SHAXX_DOOR_ENTER, Slot.O_SHAXX_DOOR_EXIT, Slot.GUN_DOOR}},
        -- Mantenha a interação pressionada para abrir: o registro de uso é enviado como ainda não utilizado.
        interact = {slots = {Slot.DOOR_INTERACTABLE}, used = false},
        sequence = {
            {interacted = Slot.DOOR_INTERACTABLE, move = {to = "open", slots = {Slot.D_GUN_DOOR}},
                interact = {slots = {Slot.DOOR_INTERACTABLE}, active = false}},
        }},
    -- Nenhuma chave de evento é enviada no início; cada área de ativação no caminho para o arsenal envia as próximas.
    {id = "shaxx", after = "home", trigger = Slot.PT_SC_CIVILIAN_GROUND_1_LOOK,
        scenes = {{scene = scenes.SCENE_SHAXX, keys = {}}},
        sequence = {
            {on = Slot.PT_SC_CIVILIANS_MID,
                signal = {scene = scenes.SCENE_SHAXX, keys = {shaxx_key[1], shaxx_key[2]}}},
            {on = Slot.PT_WEAPON,
                signal = {scene = scenes.SCENE_SHAXX, keys = {shaxx_key[4], shaxx_key[5]}}},
            -- A chave de evento 3 fecha a porta após as duas falas de Shaxx.
            {after_ms = 5500, signal = {scene = scenes.SCENE_SHAXX, keys = {shaxx_key[3]}}},
        }},
    -- Todas as cenas são reproduzidas ao mesmo tempo quando o jogador passa pela porta de Shaxx.
    {id = "civilians", after = "home", trigger = Slot.PT_SC_CIVILIAN_WALL_SIT_C,
        scenes = hallway},
    -- Dois Cabais para um combate adicional; a cena e o civil do momento heroico ficam de fora.
    {id = "hero_moment", after = "home", trigger = Slot.PT_HERO_MOMENT,
        objective = Slot.OBJ_CENTURION_INTRO, groups = TaskGroup.OBJ_CENTURION_INTRO,
        squads = {
            unit(Squad.SQ_CABAL_HERO_MOMENT, Slot.SQ_CABAL_HERO_MOMENT),
            unit(Squad.SQ_CABAL_HERO_MOMENT_B, Slot.SQ_CABAL_HERO_MOMENT_B),
        }},
    -- Caminho de saída: o Guarda Vermelho fica na saída.
    {id = "post_gun", after = "home", trigger = Slot.PT_WEAPON_COMPLETE,
        objective = Slot.OBJ_POST_GUN, groups = TaskGroup.OBJ_POST_GUN,
        squads = {unit(Squad.SQ_RED_GUARD_ADS, Slot.SQ_RED_GUARD_ADS)}},
    -- Nenhum gatilho informa a entrada na área da fala CUE_30: a fala é enviada no corredor, e o cliente aguarda
    -- até o jogador chegar à área de ativação para reproduzi-la.
    {id = "cue30", after = "home", trigger = Slot.PT_GOTO_MILITARY,
        lines = {line(cue.CUE_30, Slot.SLOT_0004_80B5168C)}},
}

-- O registro de uso deste objeto é enviado junto com sua etapa.
underwatch.omit = {Slot.DOOR_INTERACTABLE}

return underwatch
