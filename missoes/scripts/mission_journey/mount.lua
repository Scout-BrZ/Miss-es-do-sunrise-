-- Conteúdo da próxima área: a subida da montanha e os Guardiões encontrados no caminho.
local missions = require("missions")
local mission = require(missions.MISSION_JOURNEY)
local campaign = require("lib.campaign")
local music = require("mission_journey.music")
local falcons = require("mission_journey.falcons")
local checkpoints = require("mission_journey.checkpoints")
local Slot, Squad, Directive = mission.Slot, mission.Squad, mission.Directive
local unit = campaign.unit
local kAutoRifleDefinitionHash = 1195725819

local transition = {
    trigger = Slot.PT_GOTO_CLIMB,
    state = mission.states.STATE_80B5E01F_0003_0000_80B5E018,
    -- Destino da subida dentro da mesma região.
    spawn_set_hash = 0x777EB298,
}

local climb = {
    id = "climb",
    -- A etapa falcon só começa depois da confirmação de coleta da arma.
    -- O gatilho pode ocorrer antes; os inimigos aguardam essa etapa.
    after = "falcon",
    trigger = Slot.PT_FALCON_CLIMB,
    -- A biblioteca solicita os esquadrões antes de chamar on_start.
    -- Isto ordena as solicitações; ainda não confirma a criação no cliente.
    on_start = function(context)
        context:set_variable("journey.dawn_falcons.climb_started",true)
        local scene = context:scene(mission.Scene.SC_PRIDE_ROCK)
        scene:activate{}
        -- Preserva as chaves já usadas para testar a cena de uivo.
        scene:send_event { key = 0x385838EC }
        scene:send_event { key = 0x50954B78 }
    end,
    squads = {
        unit(Squad.SQ_CLIMB_BEAST_PRIME, Slot.SQ_CLIMB_BEAST_PRIME),
        unit(Squad.SQ_CLIMB_BEAST_A, Slot.SQ_CLIMB_BEAST_A),
        unit(Squad.SQ_CLIMB_BEAST_A_1, Slot.SQ_CLIMB_BEAST_A_1),
        unit(Squad.SQ_CLIMB_BEAST_B, Slot.SQ_CLIMB_BEAST_B),
        unit(Squad.SQ_CLIMB_BEAST_B_1, Slot.SQ_CLIMB_BEAST_B_1),
        unit(Squad.SQ_CLIMB_BEAST_C, Slot.SQ_CLIMB_BEAST_C),
        unit(Squad.SQ_CLIMB_BEAST_C_1, Slot.SQ_CLIMB_BEAST_C_1),
        unit(Squad.SQ_CLIMB_BEAST_D, Slot.SQ_CLIMB_BEAST_D),
        unit(Squad.SQ_CLIMB_BEAST_D_1, Slot.SQ_CLIMB_BEAST_D_1),
        unit(Squad.SQ_CLIMB_BEAST_E, Slot.SQ_CLIMB_BEAST_E),
        unit(Squad.SQ_CLIMB_BEAST_E_1, Slot.SQ_CLIMB_BEAST_E_1),
        unit(Squad.SQ_CLIMB_BEAST_F, Slot.SQ_CLIMB_BEAST_F),
        unit(Squad.SQ_CLIMB_BEAST_F_1, Slot.SQ_CLIMB_BEAST_F_1),
    },
}

local guardians = {
    id = "guardians",
    trigger = Slot.PT_CLIMB_FLYOVER,
    squads = {
        unit(Squad.SQ_HARVEY_1, Slot.SQ_HARVEY_1),
        unit(Squad.SQ_HARVEY_2, Slot.SQ_HARVEY_2),
        unit(Squad.SQ_HARVEY_3, Slot.SQ_HARVEY_3),
        unit(Squad.SQ_HARVEY_4, Slot.SQ_HARVEY_4),
    },
}

-- Estas etapas ficam entre a saída do canal e a chegada ao cânion.
local steps = {
    rally = {
        id = "rally",
        directive = Directive.REGROUP,
        navpoint = Slot.AP_DEAD_GUARDIANS,
        ends = {trigger = Slot.PT_FIND_GUARDIANS_HIGH},
    },
    gun = {
        id = "gun",
        barrier = true,
        directive = Directive.ARM_YOURSELF,
        navpoint = Slot.AP_GET_GUN,
        on_start = function(context)
            context:activate_objects {
                slots = {Slot.O_AUTO_RIFLE},
                active = true,
            }
        end,
        ends = {
            collect = {
                slot = Slot.O_GET_GUN_CONE,
                definition_hash = kAutoRifleDefinitionHash,
                on_success = function(context)
                    -- Encerra o estado usado após a cura no canal.
                    -- No Dawn, ele já é removido na chegada aos arredores.
                    context:slot(Slot.HO_HEALED_CANAL):set_mission_effect {
                        enabled = false,
                        revision = context.attempt_generation * 2 + 1,
                    }
                    local smg_filter = context:slot(Slot.OF_FORCE_SWAP_SMG)
                    smg_filter:set_object_filter {
                        players = true,
                    }
                    context:slot(Slot.HO_FORCE_SWAP_SMG):set_mission_effect {
                        filter = smg_filter,
                        enabled = true,
                        revision = context.attempt_generation * 2,
                    }
                    local ammo_filter = context:slot(Slot.OF_HAVE_SOME_AMMO)
                    ammo_filter:set_object_filter {
                        players = true,
                    }
                    context:slot(Slot.HO_HAVE_SOME_AMMO):set_mission_effect {
                        filter = ammo_filter,
                        enabled = true,
                        revision = context.attempt_generation * 2,
                    }
                    context:activate_objects {
                        slots = {Slot.O_GET_GUN_CONE, Slot.O_AUTO_RIFLE},
                        active = false,
                    }

                end,
            },
        },
    },
    falcon = {
        id = "falcon",
        directive = Directive.FOLLOW_YOUR_VISION_B4B4B71D,
        navpoint = Slot.SLOT_000B_80B5E415,
        ends = {trigger = Slot.PT_GOTO_MOUNTAIN},
    },
    mountain = {
        id = "mountain",
        directive = Directive.FOLLOW_YOUR_VISION_ABA9EFFB,
        navpoint = Slot.AP_GOTO_CANYON,
        ends = {trigger = Slot.PT_GOTO_CANYON},
    },
}

local lib = require("lib.mission_lib")

-- Libera a cena apenas quando o jogador chega ao volume do falcão.
local function on_player_trigger(context, state, event)
    falcons.on_trigger(context, state, event)
    falcons.update_combat(context, state, climb.squads)
    -- Aproximações Lua dos volumes musicais: os volumes exatos não têm PT próprio.
    if lib.is_slot(context, event, Slot.PT_DLG_MOUNTAIN_1) then
        music.play(context, state, 4)
    elseif lib.is_slot(context, event, Slot.PT_END_NAV) then
        music.play(context, state, 6)
    end


    -- Teste de Flyby 2: efeito de sobrevoo da nave capital Cabal.
    -- A ligação com este objeto é experimental; não foi confirmada no Dawn.
    if lib.is_slot(context, event, Slot.PT_MOUNTAIN_FLYBY_2)
        and state:variable("journey.flyby2.effect_requested") ~= true then
        context:activate_objects {
            slots = {Slot.O_CABAL_CARRIER},
            active = true,
        }
        local nave = context:slot(Slot.D_CABAL_CARRIER)

        -- Solicita energia total antes de solicitar o movimento.
        nave:set_channel {
            channel = context.sdk.device_channels.power,
            value = context.sdk.unit(1),
            snap = true,
        }

        -- Solicita o avanço gradual até a posição normalizada 1.
        nave:set_channel {
            channel = context.sdk.device_channels.position,
            value = context.sdk.unit(0.1),
            snap = false,
        }
        -- Este filtro estava sem uso no script; seleciona somente a nave.
        local filter = context:slot(Slot.OF_CLEAR_CLIMB)
        filter:set_object_filter { target = context:slot(Slot.O_CABAL_CARRIER) }
        context:slot(Slot.HO_CABAL_CAPITAL_SHIP_FLYOVER):set_mission_effect {
            filter = filter,
            enabled = true,
            revision = context.attempt_generation * 2,
        }
        -- Registra a solicitação, não a confirmação da animação no cliente.
        context:set_variable("journey.flyby2.effect_requested", true)
    end

    -- Solicita o teletransporte para a próxima área da montanha.
    -- A variável impede repetir a solicitação enquanto o jogador
    -- permanece dentro do gatilho.
    if lib.is_slot(context, event, Slot.PT_GOTO_MOUNTAIN)
        and state:variable("journey.mountain.transition_requested") ~= true then

                -- Encerra o sobrevoo antes de carregar a próxima área.
        if state:variable("journey.flyby2.effect_requested") == true
            and state:variable("journey.flyby2.cleaned") ~= true then

            local filter = context:slot(Slot.OF_CLEAR_CLIMB)

            -- Desativa o efeito usando o mesmo filtro da ativação.
            context:slot(Slot.HO_CABAL_CAPITAL_SHIP_FLYOVER):set_mission_effect {
                filter = filter,
                enabled = false,
                revision = context.attempt_generation * 2 + 1,
            }

            -- Solicita a remoção da nave antes da transição.
            context:activate_objects {
                slots = {Slot.O_CABAL_CARRIER},
                active = false,
            }

            -- Impede repetir a limpeza nesta tentativa.
            context:set_variable("journey.flyby2.cleaned", true)
        end

        -- Encerra os falcões da subida e prepara os próximos somente na chegada.
        falcons.retire(context,state,"climb")
        falcons.expect_arrival(context,"mountain")
        context:set_variable("journey.music.pending", 3)
        checkpoints.select(context, "mountain",
            mission.states.STATE_80B5E01F_0003_0000_80B5E018,
            {
                -- Mantém a mesma omissão usada no primeiro teletransporte.
                Slot.O_AUTO_RIFLE,

                -- Terceira chegada jogável indicada pelo Dawn.
                spawn_set_hash = 0xEDE37EC8,
            }
        )

        -- Registra a solicitação, não a confirmação de chegada.
        context:set_variable(
            "journey.mountain.transition_requested",
            true
        )
    end
    -- A variável impede repetir a fala nas próximas atualizações do gatilho.
    if lib.is_slot(context, event, Slot.PT_FIND_GUARDIANS_HIGH)
    and state:variable("journey.guardians.cue24_requested") ~= true then

        context:slot(Slot.M_DIALOG_SENSOR_80B5E02A):play_dialogue_cue {
            cue = mission.DialogueCue.M_DIALOG_SENSOR_80B5E02A.CUE_24,
        }

        context:set_variable("journey.guardians.cue24_requested", true)
    end
    -- Solicita a fala 27 uma vez ao entrar no gatilho LOW.
    if lib.is_slot(context, event, Slot.PT_FIND_GUARDIANS_LOW)
    and state:variable("journey.guardians.cue27_requested") ~= true then

        context:slot(Slot.M_DIALOG_SENSOR_80B5E02A):play_dialogue_cue {
            cue = mission.DialogueCue.M_DIALOG_SENSOR_80B5E02A.CUE_27,
        }

        context:set_variable("journey.guardians.cue27_requested", true)
    end

    if lib.is_slot(context,event,Slot.PT_GOTO_ARRIVAL) then
        falcons.retire(context,state)
    end
end

return {
    on_player_trigger = on_player_trigger,
    -- Mantenha os campos existentes abaixo.
    transition = transition,
    encounters = {
        climb = climb,
        guardians = guardians,
    },
    steps = steps,
}