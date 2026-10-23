-- O hangar (área 4, região 32): a cápsula de desembarque Cabal, as duas portas de Amanda, o ataque da nave de comando
-- e as explosões durante a fuga, até a saída para a praça.
local shared = require ("mission_towerfall.shared")
local Slot, Squad, TaskGroup = shared.Slot, shared.Squad, shared.TaskGroup
local scenes, cue = shared.scenes, shared.cue
local unit, line = shared.unit, shared.line

local military = {}

military.legs = {
    {id = "hangar", state = shared.states.military, arm = {
        Slot.PT_HANGAR_EARLY, Slot.PT_HANGAR_SPAWN, Slot.PT_HANGAR_SPAWN_BACKUP,
        Slot.PT_HANGAR_SPAWN_POD, Slot.PT_AMANDA_SKIP,
        Slot.PT_HANGAR_COMBAT, Slot.PT_HOLLIDAY, Slot.PT_HANGAR_FODDER_BACKUP_SPAWN,
        Slot.PT_ESCAPE_EXPLOSION_A_80B5036A,
        Slot.PT_ESCAPE_EXPLOSION_B_80B5036A, Slot.PT_NUX_CROUCH, Slot.PT_NUX_DOUBLE_JUMP,
        Slot.PT_GOTO_PLAZA_80B50B91,
    }},
}
-- O objetivo continua sendo "Encontre Zavala", desde a Underwatch.
military.steps = {
    {id = "hangar", ends = {trigger = Slot.PT_GOTO_PLAZA_80B50B91}},

    --{id = "home", directive = Directive.FIND_ZAVALA, navpoint = Slot.AP_IKORA},
}
-- Todos os esquadrões do hangar recebem o mesmo objetivo antes de serem posicionados.
local OBJECTIVE, GROUPS = Slot.OBJ_HANGAR, TaskGroup.OBJ_HANGAR
-- A animação de entrada da base de guerra Cabal faz o personagem saltar com sua
-- onde a inteligência artificial de combate assume o controle.
local INTRO = "WORLD_RIFLE_ANY_CABAL_WARBASE_INTRO"

local LEDGE_CENTURION = {
    unit(Squad.SQ_HANGAR_OVERLOOK_A_A_CENT, Slot.SQ_HANGAR_OVERLOOK_A_A_CENT, nil, 1),
}

local FODDERS = {
    unit(Squad.SQ_HANGAR_FODDER_A, Slot.SQ_HANGAR_FODDER_A),
    unit(Squad.SQ_HANGAR_FODDER_B, Slot.SQ_HANGAR_FODDER_B),
    unit(Squad.SQ_HANGAR_FODDER_C, Slot.SQ_HANGAR_FODDER_C),
}
local FODDER_CELLS = {
    Slot.SQ_HANGAR_FODDER_A_CELL, Slot.SQ_HANGAR_FODDER_B_CELL, Slot.SQ_HANGAR_FODDER_C_CELL,
}

military.encounters = {
    -- A música do hangar começa quando o jogador aterrissa nele.
    -- Seção 4, identificada de ouvido.
    {id = "overlook", after = "hangar", trigger = Slot.PT_HANGAR_EARLY, music = 4,
        objective = OBJECTIVE, groups = GROUPS,
        squads = {unit(Squad.SQ_HANGAR_OVERLOOK_A_A, Slot.SQ_HANGAR_OVERLOOK_A_A)},
        move = {to = "close", slots = {Slot.D_GATING_AMANDA_START, Slot.D_GATING_AMANDA_HANGAR},
            snap = true}},
        -- A cápsula só existe após ser instanciada; sua cena a abre mais tarde.
        -- Dois esquadrões da plataforma elevada permanecem onde foram posicionados até a cápsula abrir.
    {id = "entrance", after = "hangar", trigger = Slot.PT_HANGAR_SPAWN,
        objective = OBJECTIVE, groups = GROUPS, hold = true,
        squads = {
            unit(Squad.SQ_HANGAR_OVERLOOK_A_C, Slot.SQ_HANGAR_OVERLOOK_A_C),
            unit(Squad.SQ_HANGAR_OVERLOOK_B_A, Slot.SQ_HANGAR_OVERLOOK_B_A),
        },
        objects = {slots = {Slot.O_CABAL_DROP_POD_MILITARY_HALLWAY}}},
        -- O Centurião da borda aguarda ao pé da plataforma elevada, associado ao objetivo, mas sem grupo de tarefas;
        -- ao entrar em combate com o jogador, ele sobe com a mochila a jato à frente dele. Qualquer comando enviado depois
        -- interrompe esse comportamento: um grupo próprio, mesmo o mais simples, o afasta do jogador, e uma
        -- nova avaliação ou atualização de percepção o impede de saltar.
    {id = "ledge_centurion", after = "hangar", trigger = Slot.PT_HANGAR_SPAWN,
        objective = OBJECTIVE, squads = LEDGE_CENTURION},
        -- A cena abre a cápsula (em cerca de 2,7 segundos) e exige os três Legionários dentro dela; os dois
        -- esquadrões da plataforma elevada começam a se mover junto com a cena.
    {id = "pod_squad", after = "hangar", trigger = Slot.PT_HANGAR_SPAWN_BACKUP,
        objective = OBJECTIVE, groups = GROUPS, squads = {
            unit(Squad.SQ_MILITARY_HALLWAY_DESTRUCTION, Slot.SQ_MILITARY_HALLWAY_DESTRUCTION,
                nil, 3)},
        release = {"entrance"},
        scenes = {{scene = scenes.SC_MILITARY_HALLWAY_DESTRUCTION}}},
    -- A explosão C atinge a primeira porta, que se abre com a detonação.
    {id = "first_door", after = "hangar", trigger = Slot.PT_HANGAR_SPAWN_POD, sequence = {
        {after_ms = 1000,
            place = {objective = OBJECTIVE, groups = GROUPS, squads = {
                unit(Squad.SQ_HANGAR_OVERLOOK_B_B, Slot.SQ_HANGAR_OVERLOOK_B_B),
            }},
            scenes = {{scene = scenes.SC_EXPLOSION_C_80B5036A}},
            move = {to = "open", slots = {Slot.D_GATING_AMANDA_START}}},
    }},
    -- Antes da segunda porta, a nave de comando e sua escolta são posicionadas de uma só vez; depois,
    -- a explosão D abre a porta.
    {id = "second_door", after = "hangar", trigger = Slot.PT_AMANDA_SKIP,
        objects = {slots = {
            Slot.CABAL_DESTROYER, Slot.DOGFIGHT_BANK_RIGHT_INIT, Slot.DOGFIGHT_BANK_LEFT_A,
            Slot.DOGFIGHT_BANK_LEFT_B, Slot.DOGFIGHT_BANK_LEFT_C,
            Slot.DOGFIGHT_SHIPS_DISPLACEMENT_A,
            Slot.DOGFIGHT_SHIPS_DISPLACEMENT_B, Slot.DOGFIGHT_SHIPS_DISPLACEMENT_C,
            Slot.DOGFIGHT_BANK_RIGHT_A, Slot.DOGFIGHT_BANK_RIGHT_B, Slot.DOGFIGHT_BANK_RIGHT_C,
            Slot.O_CABAL_CARRIER_R_80B5036A, Slot.O_CABAL_CARRIER_L_80B5036A,
        }},
        move = {to = "open",
            slots = {Slot.D_CABAL_CARRIER_R_80B5036A, Slot.D_CABAL_CARRIER_L_80B5036A}},
        scenes = {{scene = scenes.SC_EXPLOSION_D_80B5036A}},
        -- A fala CUE_34 ocorre um segundo após a abertura da porta; nenhuma área informada pelo cliente corresponde a esse momento.
        sequence = {
            {after_ms = 1200, move = {to = "open", slots = {Slot.D_GATING_AMANDA_HANGAR}}},
            {after_ms = 1000, lines = {line(cue.CUE_34)}},
        }},
    -- Os seis mísseis atingem o alvo assim que aparecem, por isso são criados em intervalos.
    {id = "missiles", after = "hangar", trigger = Slot.PT_AMANDA_SKIP, sequence = {
        {after_ms = 250, objects = {slots = {Slot.O_CABAL_MISSILE_1_80B5036A}}},
        {after_ms = 250, objects = {slots = {Slot.O_CABAL_MISSILE_2_80B5036A}}},
        {after_ms = 250, objects = {slots = {Slot.O_CABAL_MISSILE_3_80B5036A}}},
        {after_ms = 250, objects = {slots = {Slot.O_CABAL_MISSILE_4}}},
        {after_ms = 250, objects = {slots = {Slot.O_CABAL_MISSILE_5}}},
        {after_ms = 250, objects = {slots = {Slot.O_CABAL_MISSILE_6}}},
    }},
    {id = "combat_music", after = "hangar", trigger = Slot.PT_HANGAR_COMBAT, music = 8},
    -- Os soldados comuns chegam por cima da nave de comando usando sua animação de entrada. O grupo 13 passa a manter a área de tiro:
    -- essa atribuição é enviada após eles aterrissarem, pois atribuir um objetivo antes impede
    -- que eles apareçam.
    -- Eles partem quando o jogador alcança a área logo antes da explosão A, para aterrissarem no momento da detonação.
    {id = "fodders", after = "hangar", trigger = Slot.PT_HANGAR_FODDER_BACKUP_SPAWN,
        perform = {cells = FODDER_CELLS, sequence = INTRO},
        sequence = {{after_ms = 5000,
            assign = {objective = OBJECTIVE, group = GROUPS.GROUP_13, squads = FODDERS}}}},
    {id = "explosion_a", after = "hangar", trigger = Slot.PT_ESCAPE_EXPLOSION_A_80B5036A,
        scenes = {{scene = scenes.SC_EXPLOSION_A_80B5036A}}},
    -- A segunda cápsula cai com seus três Legionários no momento da explosão.
    {id = "explosion_b", after = "hangar", trigger = Slot.PT_ESCAPE_EXPLOSION_B_80B5036A,
        objective = OBJECTIVE, groups = GROUPS,
        squads = {unit(Squad.SQ_HANGAR_A_B, Slot.SQ_HANGAR_A_B, nil, 1)},
        scenes = {{scene = scenes.SC_EXPLOSION_B_80B5036A}}},
    -- Estes dois grupos são posicionados à frente do jogador quando ele atravessa a escadaria e defendem sua área
    -- junto à segunda explosão: o grupo 14 mantém a posição no chão, e o grupo 15, na plataforma acima.
    {id = "stairwell_ground", after = "hangar", trigger = Slot.PT_HOLLIDAY,
        sequence = {{after_ms = 4000, place = {objective = OBJECTIVE, approach = GROUPS.GROUP_14,
            squads = {unit(Squad.SQ_HANGAR_A_A, Slot.SQ_HANGAR_A_A)}}}}},
    {id = "stairwell_overlook", after = "hangar", trigger = Slot.PT_HOLLIDAY,
        sequence = {{after_ms = 4000, place = {objective = OBJECTIVE, approach = GROUPS.GROUP_15,
            squads = {unit(Squad.SQ_HANGAR_A_B_SNIPER, Slot.SQ_HANGAR_A_B_SNIPER)}}}}},
    {id = "nux_crouch", after = "hangar", trigger = Slot.PT_NUX_CROUCH, lines = {line(cue.CUE_37)}},
    -- A música 9 finaliza o evento musical do combate no hangar.
    {id = "exit_music", after = "hangar", trigger = Slot.PT_NUX_DOUBLE_JUMP, music = 9, 
        sequence = {{after_ms = 5000, music = 1}},
    }
}
return military