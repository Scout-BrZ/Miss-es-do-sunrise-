-- Rascunho da campanha Adieu, da Guerra Vermelha; ainda não foi testado no jogo.
-- Uma etapa pelas regiões 24 a 27. As etapas seguem os objetos de passo, suas linhas e as posições
-- dos volumes de gatilho: o canal, a subida pelos Guardiões mortos, a montanha, as feras e o cânion.
local missions = require("missions")
local mission = require(missions.MISSION_JOURNEY)
local campaign = require("lib.campaign")
local music = require("mission_journey.music")
local falcons = require("mission_journey.falcons")
local checkpoints = require("mission_journey.checkpoints")
local unit = campaign.unit
local mount = require("mission_journey.mount")
local Slot, Squad, Directive = mission.Slot, mission.Squad, mission.Directive
-- Efeitos usados no teste da sequência inicial.
-- O primeiro já foi testado: deixa o jogador ferido.
-- O segundo é um candidato para a câmera desse estado.
-- Ainda não sabemos se ele também provoca alguma animação.
local efeitos_inicio = {
    -- Desativa os poderes
    Slot.HO_NOPOWER_HAVEN,
    -- Aplica o estado de Guardião ferido no início da sequência.
    Slot.HO_NOWEAPON_INJURED,
    -- Mantém a câmera associada ao estado ferido.
    Slot.HO_NOWEAPON_INJURED_CAMERA,
}

-- A Cidade em chamas ao redor do canal serve de cenário, não de combate. Estes esquadrões não têm objetivo.
local city = {
    id = "city",
    squads = {
        unit(Squad.SC_BRIDGE_1_SQUAD, Slot.SC_BRIDGE_1_SQUAD),
        unit(Squad.SC_BRIDGE_3_SQUAD, Slot.SC_BRIDGE_3_SQUAD),
        unit(Squad.SC_BRIDGE_5_SQUAD, Slot.SC_BRIDGE_5_SQUAD),
        unit(Squad.SC_BRIDGE_7_SQUAD, Slot.SC_BRIDGE_7_SQUAD),
        unit(Squad.SC_BRIDGE_TANK_SQUAD, Slot.SC_BRIDGE_TANK_SQUAD),
        unit(Squad.SC_BRIDGE_TANK_SQUAD_1, Slot.SC_BRIDGE_TANK_SQUAD_1),
        unit(Squad.SC_BRIDGE_TANK_SQUAD_2, Slot.SC_BRIDGE_TANK_SQUAD_2),
        unit(Squad.SC_ROOFTOP_01_SQUAD, Slot.SC_ROOFTOP_01_SQUAD),
        unit(Squad.SC_ROOFTOP_02_SQUAD, Slot.SC_ROOFTOP_02_SQUAD),
        unit(Squad.SC_ROOFTOP_03_SQUAD, Slot.SC_ROOFTOP_03_SQUAD),
        unit(Squad.SC_ROOFTOP_04_SQUAD, Slot.SC_ROOFTOP_04_SQUAD),
        unit(Squad.SC_ROOFTOP_05_SQUAD, Slot.SC_ROOFTOP_05_SQUAD),
        unit(Squad.SC_ROOFTOP_06_SQUAD, Slot.SC_ROOFTOP_06_SQUAD),
        unit(Squad.SC_SHADOW_TANK_SQUAD_1, Slot.SC_SHADOW_TANK_SQUAD_1),
        unit(Squad.SC_SHADOW_TANK_SQUAD_2, Slot.SC_SHADOW_TANK_SQUAD_2),
        unit(Squad.SC_SHADOW_TANK_SQUAD_3, Slot.SC_SHADOW_TANK_SQUAD_3),
        unit(Squad.SC_REAL_ROOFTOP_1, Slot.SC_REAL_ROOFTOP_1),
        unit(Squad.SC_REAL_ROOFTOP_2, Slot.SC_REAL_ROOFTOP_2),
        unit(Squad.SC_REAL_ROOFTOP_3, Slot.SC_REAL_ROOFTOP_3),
        unit(Squad.SC_REAL_ROOFTOP_4, Slot.SC_REAL_ROOFTOP_4),
        unit(Squad.SC_REAL_ROOFTOP_6, Slot.SC_REAL_ROOFTOP_6),
        unit(Squad.SC_REAL_ROOFTOP_7, Slot.SC_REAL_ROOFTOP_7),
        unit(Squad.SC_REAL_ROOFTOP_8, Slot.SC_REAL_ROOFTOP_8),
        unit(Squad.SQ_OMG_JUMPER_1, Slot.SQ_OMG_JUMPER_1),
        unit(Squad.SQ_OMG_JUMPER_2, Slot.SQ_OMG_JUMPER_2),
        unit(Squad.SQ_OMG_JUMPER_3, Slot.SQ_OMG_JUMPER_3),
        unit(Squad.SQ_OMG_JUMPER_4, Slot.SQ_OMG_JUMPER_4),
        unit(Squad.SQ_SAD_GHOST_2, Slot.SQ_SAD_GHOST_2),
    },
}

-- A arena das feras fica entre os gatilhos de ida ao cânion e de ida até Hawthorne; ela pode ser ignorada.
local beasts = {
    id = "beasts",
    trigger = Slot.PT_BEAST,
    objective = Slot.OBJ_BOWL_BEAST,
    -- O encontro já posiciona os esquadrões antes de chamar esta função.
    -- Inicia a cena sem solicitar outro spawn dos mesmos atores.
    on_start = function(context)
        context:set_variable("journey.dawn_falcons.bowl_started",true)
        -- O encontro das feras solicita a seção 5, como no Dawn.
        context:slot(Slot.M_MUSIC_SENSOR_80B5E02A):set_music_section{section = 5, enabled = true}
        context:set_variable("journey.music.section", 5)
        local scene = context:scene(mission.Scene.SC_BEASTMASTER)
        scene:activate{}
        -- Primeira chave do SDK e chave usada pelo Dawn para liberar a cena.
        scene:send_event { key = 0x385838EC }
        scene:send_event { key = 0x286C14D7 }
    end,
    squads = {
        unit(Squad.BEAST_WARBEAST_0_SQUAD, Slot.BEAST_WARBEAST_0_SQUAD),
        unit(Squad.BEAST_WARBEAST_1A_SQUAD, Slot.BEAST_WARBEAST_1A_SQUAD),
        unit(Squad.BEAST_WARBEAST_1B_SQUAD, Slot.BEAST_WARBEAST_1B_SQUAD),
        unit(Squad.BEAST_WARBEAST_2_SQUAD, Slot.BEAST_WARBEAST_2_SQUAD),
        unit(Squad.BEAST_WARBEAST_2A_SQUAD, Slot.BEAST_WARBEAST_2A_SQUAD),
        unit(Squad.BEAST_WARBEAST_3_SQUAD, Slot.BEAST_WARBEAST_3_SQUAD),
        unit(Squad.BEAST_WARBEAST_3A_SQUAD, Slot.BEAST_WARBEAST_3A_SQUAD),
        unit(Squad.BEAST_WARBEAST_4_SQUAD, Slot.BEAST_WARBEAST_4_SQUAD),
        unit(Squad.BEAST_WARBEAST_4A_SQUAD, Slot.BEAST_WARBEAST_4A_SQUAD),
        unit(Squad.BEAST_WARBEAST_5_SQUAD, Slot.BEAST_WARBEAST_5_SQUAD),
        unit(Squad.BEAST_WARBEAST_5A_SQUAD, Slot.BEAST_WARBEAST_5A_SQUAD),
        unit(Squad.SQ_BOWL_LEGS, Slot.SQ_BOWL_LEGS),
        unit(Squad.SQ_BOWL_LEGS_1, Slot.SQ_BOWL_LEGS_1),
    },
}
-- Mantém apenas o segundo esquadrão de Ghost que estava na cidade.
-- Ainda precisamos confirmar qual participa da cena de busca.
local city_ghosts = {
    id = "city_ghosts",
    squads = {
        -- O primeiro ponto de spawn foi removido; mantém somente o segundo Ghost.
        unit(Squad.SQ_SAD_GHOST_2, Slot.SQ_SAD_GHOST_2),
    },
}

local program = campaign.new{
    key = "journey",
    checkpoint_support = true,
    -- So considera a cinematic em reproducao depois do informe nativo de inicio.
    -- Coordena os dois videos pelo Lua, sem acionar o controlador C++ de encerramento.
    native_outro = false,
    outro_confirm_started = true,
    outro_confirm_arrival = true,
    outro_wait_terminated = true,
    finish = function(context)
        -- Seleciona o candidato 0 antes das cinematics, como no Dawn.
        context:slot(Slot.M_MUSIC_SENSOR_80B5E02A):set_music_section{section = 0, enabled = true}
        context:set_variable("journey.music.section", 0)
    end,
    -- Encerramento: resgate de Hawthorne, seguido por Ghaul e o Orador.
    -- A biblioteca aguarda o carregamento e o término de cada cinematic.
    outro = {
        {state = mission.states.STATE_80B5E01F_0003_0002_80B5E01A,
         cinematic = Slot.MID_A_CINEMATIC_CINEMATIC, spawn_set_hash = 0x811C9DC5},
        {state = mission.states.STATE_80B5E01F_0003_0003_80B5E01E,
         cinematic = Slot.MID_B_CINEMATIC_CINEMATIC, spawn_set_hash = 0x811C9DC5},
    },
    -- Abertura de Adieu: carrega o estado da cinematic antes da caminhada.
    -- A biblioteca segura o aparecimento do jogador durante a abertura.
    -- Ao terminar ou pular, seleciona o estado da primeira etapa: região 24.
    intro = {
        {state = mission.states.STATE_80B5E01F_0003_0001_80B5E019,
        cinematic = Slot.INTRO_CINEMATIC_CINEMATIC,
     },
    },
    directive_sensor = Slot.M_DIRECTIVE_SENSOR_80B5E02A,
    dialogue_sensor = Slot.M_DIALOG_SENSOR_80B5E02A,
    legs = {
        {id = "the_walk", state = mission.states.STATE_80B5E01F_0003_0000_80B5E018, arm = {
            Slot.PT_DLG_CITY_EXIT,
            Slot.PT_SHADOW_SCENE,
            Slot.PT_SCENE_TANK,
            Slot.PT_MOSQUITO_FLYBY,
            Slot.PT_GHOST_EXIT_2,
            Slot.PT_OMG_GOGOGO,
            Slot.PT_STUMBLE_1,
            Slot.PT_STUMBLE_2,
            Slot.PT_PLAYER_COLLAPSE,
            Slot.PT_GHOST_FINDING, mount.transition.trigger,
        }},
        {id = "mount", state = mount.transition.state, arm = {
            Slot.PT_FALCON_CLIMB,
            Slot.PT_FOLLOW_FALCON, -- Segunda cena do falcão da subida.
            Slot.PT_FALCON_3,
            Slot.PT_FALCON_4,
            Slot.PT_FALCON_1, -- Gatilho do falcão da próxima área.
            Slot.PT_CLIMB_FLYOVER,
            Slot.PT_DLG_MOUNTAIN_1, -- Música do Viajante, próxima ao volume original.
            Slot.PT_MOUNTAIN_FLYBY_2, -- Gatilho do teste da sequência da montanha.
            Slot.PT_FIND_GUARDIANS_HIGH,
            Slot.PT_FIND_GUARDIANS_LOW,
            Slot.PT_GOTO_MOUNTAIN,
            Slot.PT_GOTO_CANYON,
            Slot.PT_BEAST,
            Slot.PT_GOTO_HAW,
            Slot.PT_END_NAV,
            Slot.PT_GOTO_ARRIVAL, -- Inicia as duas cinematics finais.

        }},
    },
    steps = {
        -- O Ghost procura pelo Guardião no canal.
        {id = "ghost", directive = Directive.FIND_YOUR_GHOST,
            -- Ativa a cena de busca quando esta etapa começa.
            scene = mission.Scene.SC_GHOST_SEARCHING,
            -- Aplica o estado ferido e a câmera de caminhada.
            on_start = function(context)
            -- Seleciona os jogadores que receberão os efeitos.
            local filtro = context:slot(Slot.OF_SLOWDOWN_CITY)
            filtro:set_object_filter {
                players = true,
            }

            -- Aplica o estado ferido e o componente de câmera.
            for _, efeito in ipairs(efeitos_inicio) do
                context:slot(efeito):set_mission_effect {
                    filter = filtro,
                    enabled = true,
                    revision = context.attempt_generation * 2,
                }
            end

            -- Mantém os efeitos ativos; a conclusão da cura ainda será conectada.
            context:set_variable("journey.injured_test.active", true)
        end,
            ends = {trigger = Slot.PT_GHOST_FINDING}},
        -- O Guardião está vivo, mas perdeu a Luz; em seguida, há uma transmissão de emergência na saída do canal.
        {id = "canal", directive = Directive.REGROUP, navpoint = Slot.SLOT_0011_80B5E3F3,
            ends = {trigger = mount.transition.trigger}},
        mount.steps.rally,
        mount.steps.gun,
        mount.steps.falcon,
        mount.steps.mountain,
        {id = "bowl", directive = Directive.FOLLOW_YOUR_VISION_CA83E2E7,
            navpoint = Slot.AP_GOTO_HAW,
            ends = {trigger = Slot.PT_GOTO_HAW}},
        {id = "canyon", directive = Directive.FOLLOW_YOUR_VISION, navpoint = Slot.AP_HAWTHORNE,
            ends = {trigger = Slot.PT_GOTO_ARRIVAL}},
    },
    -- Desativa o posicionamento dos esquadrões da cidade no início.
    -- Preserva os encontros da subida, dos Guardiões e das feras.
    encounters = {city_ghosts, mount.encounters.climb, mount.encounters.guardians, beasts},
}

-- Limpeza reservada para a conclusão da cura; não é chamada por tempo ou chegada.
-- Isto nao comprova a animacao de levantar: estamos testando apenas o efeito ferido.
local function stop_injured_test(context, state)
    -- Evita remover novamente um teste que já terminou.
    if state:variable("journey.injured_test.active") ~= true then
        return
    end

    -- Remove todos os efeitos aplicados por este teste,
    -- incluindo o componente de câmera.
    for _, efeito in ipairs(efeitos_inicio) do
        context:slot(efeito):set_mission_effect {
            enabled = false,
            revision = context.attempt_generation * 2 + 1,
        }
    end
    -- A queda não pertence mais à lista de efeitos iniciais.
    -- Por isso, precisamos removê-la separadamente.
    if state:variable("journey.collapse.applied") == true then
    context:slot(Slot.HO_PLAYER_COLLAPSE):set_mission_effect {
        enabled = false,
        revision = context.attempt_generation * 2 + 1,
    }

    context:set_variable("journey.collapse.applied", false)
end
context:cancel_timer("journey.injured_test.timeout")
context:set_variable("journey.injured_test.active", false)
end

-- Encerra os efeitos transitorios da cura antes de carregar outra area.
-- Preserva HO_HEALED_CANAL, removido originalmente na coleta da arma.
local function finish_initial_healing(context, state)
    if state:variable("journey.finding.effects_finished") == true then return end
    for _, name in ipairs {
        "ghost_lights", "test_second_event", "test_fourth_event",
        "test_fifth_event", "test_sixth_event", "healing_player",
        "healed_canal", "transition_from_wounded", "release_pose", "release_camera",
    } do
        context:cancel_timer("journey.finding." .. name)
    end
    for _, slot in ipairs {
        Slot.HO_HEALING_PLAYER, Slot.HO_HEALING_GHOST,
        Slot.HO_TRANSITON_FROM_WOUNDED,
    } do
        context:slot(slot):set_mission_effect {
            enabled = false,
            revision = context.attempt_generation * 2 + 1,
        }
    end
    context:set_variable("journey.finding.effects_finished", true)
end

local previous_timer = program.on_event_timer_elapsed

program.on_event_timer_elapsed = function(context, state, event)
    -- Descarta eventos de cura ja enfileirados depois do encerramento.
    if state:variable("journey.finding.effects_finished") == true
        and string.sub(event.timer_name or "", 1, 16) == "journey.finding." then
        return
    end

    if event.timer_name == "journey.mount.transition" then
        if state:variable("journey.mount.transition_pending") == true then
            falcons.expect_arrival(context,"climb")
            context:set_variable("journey.mount.transition_pending", false)
            context:set_variable("journey.music.pending", 2)
            checkpoints.select(context, "climb", mount.transition.state, {
                -- Preserva a omissão da arma até a etapa de interação.
                Slot.O_AUTO_RIFLE,
                spawn_set_hash = mount.transition.spawn_set_hash,
            })
        end
    end

    -- Envia as chaves da cena dos cachorros sem interferir em SC_OMG_WHAT_ZBB.
    -- Solicita a sequência após a ativação do objeto.
    if event.timer_name == "journey.flyby.play" then
    context:slot(Slot.SEQ_CABAL_FLYBY):play_sequence{}

    -- Registra a solicitação; não confirma execução pelo cliente.
    context:set_variable("journey.flyby.sequence_requested", true)
end
    if event.timer_name == "journey.rooftop.test_event" then
        local chaves = {
            0x385838EC, 0xB687F07B, 0xDD6D986F, 0x5A9CAA14,
            0xDE3601F1, 0x83F56846, 0x83F56847, 0x85F02A9A,
        }
        local indice = state:variable("journey.rooftop.next_key") or 1
        local chave = chaves[indice]
        if chave ~= nil then
            context:scene(mission.Scene.SC_ROOFTOP_SCENE):send_event {key = chave}
            context:set_variable("journey.rooftop.test_key", chave)
            context:set_variable("journey.rooftop.next_key", indice + 1)
            -- Agenda a outra cena cinco segundos após enviar a quarta chave do telhado.
            if indice == 4
                and state:variable("journey.omg_what_zbb.scheduled") ~= true then
                context:set_variable("journey.omg_what_zbb.scheduled", true)
                context:start_timer("journey.omg_what_zbb.start", 5000)
            end
            if indice < #chaves then
                context:start_timer("journey.rooftop.test_event", 3000)
            end
        end
    end

    -- Ativa SC_OMG_WHAT_ZBB somente depois do atraso de cinco segundos.
    if event.timer_name == "journey.omg_what_zbb.start"
        and state:variable("journey.omg_what_zbb.requested") ~= true then
        context:scene(mission.Scene.SC_OMG_WHAT_ZBB):activate{spawn = true}
        context:set_variable("journey.omg_what_zbb.requested", true)
        context:set_variable("journey.omg_what_zbb.next_key", 1)
        -- Dá três segundos para a cena iniciar antes de enviar sua primeira chave.
        context:start_timer("journey.omg_what_zbb.test_event", 3000)
    end

    -- Envia as chaves suportadas pela cena SC_OMG_WHAT_ZBB.
    if event.timer_name == "journey.omg_what_zbb.test_event" then
        local chaves = {0x385838EC, 0xA07DCECA, 0x6E7469AE, 0xA899C47F}
        local indice = state:variable("journey.omg_what_zbb.next_key") or 1
        local chave = chaves[indice]
        if chave ~= nil then
            context:scene(mission.Scene.SC_OMG_WHAT_ZBB):send_event {key = chave}
            context:set_variable("journey.omg_what_zbb.test_key", chave)
            context:set_variable("journey.omg_what_zbb.next_key", indice + 1)
            if indice < #chaves then
                context:start_timer("journey.omg_what_zbb.test_event", 3000)
            end
        end
    end

    if event.timer_name == "journey.searching.next_event" then
        -- Ordem e intervalo experimentais. Para de enviar ao iniciar o encontro.
        if state:variable("journey.finding.requested") ~= true then
            local chaves = {
                0x385838EC, 0xFBA2AF26, 0xFBA2AF25,
                0xFBA2AF24, 0xB687F07B, 0x0F0CFF87,
            }
            local indice = state:variable("journey.searching.next_key") or 1
            local chave = chaves[indice]
            if chave ~= nil then
                context:scene(mission.Scene.SC_GHOST_SEARCHING):send_event {key = chave}
                context:set_variable("journey.searching.test_key", chave)
                context:set_variable("journey.searching.next_key", indice + 1)
                -- Agenda mais uma etapa somente se ainda restarem chaves.
            if indice < #chaves then
                    context:start_timer("journey.searching.next_event", 3000)
                end
            end
        end

    elseif event.timer_name == "journey.finding.ghost_lights" then
        if state:variable("journey.finding.requested") == true then
            local filtro_ghost = context:slot(Slot.OF_HEALING_GHOST)
            filtro_ghost:set_object_filter {
                target = context:slot(Slot.O_GHOST_FINDING),
            }

            context:slot(Slot.HO_GHOST_LIGHT):set_mission_effect {
                filter = filtro_ghost,
                enabled = true,
                revision = context.attempt_generation * 2,
            }
            context:slot(Slot.HO_GHOST_LIGHT_CONE):set_mission_effect {
                filter = filtro_ghost,
                enabled = true,
                revision = context.attempt_generation * 2,
            }
        end

    elseif event.timer_name == "journey.finding.test_second_event" then
        -- Terceira chave: o temporizador é iniciado ao alcançar PT_PLAYER_COLLAPSE.
        context:scene(mission.Scene.SC_GHOST_FINDING):send_event {
            key = 0xAC99BF27,
        }

         context:set_variable("journey.finding.test_key", 0xAC99BF27)

        -- Agenda a quarta chave após a terceira.
        -- Intervalo experimental; o comportamento da chave é desconhecido.
        context:start_timer("journey.finding.test_fourth_event", 3000)

        -- Solicita o efeito de cura junto com a última chave enviada acima.
        -- Seleciona o objeto do Ghost da cena de encontro.
        -- Precisamos confirmar no jogo se este é o objeto visível.
        local filtro = context:slot(Slot.OF_HEALING_GHOST)
        filtro:set_object_filter {
            target = context:slot(Slot.O_GHOST_FINDING),
        }

        -- Aplica o efeito de cura somente ao Ghost.
        context:slot(Slot.HO_HEALING_GHOST):set_mission_effect {
            filter = filtro,
            enabled = true,
            revision = context.attempt_generation * 2,
        }

        -- Aguarda sete segundos após solicitar a cura do Ghost.
        -- Este intervalo é de teste; não confirma o término da animação.
        context:start_timer("journey.finding.healing_player", 2000)

    elseif event.timer_name == "journey.finding.test_fourth_event" then
        -- Testa somente a quarta chave; seu comportamento ainda é desconhecido.
        context:scene(mission.Scene.SC_GHOST_FINDING):send_event {
            key = 0xAFCD176B,
        }
        context:set_variable("journey.finding.test_key", 0xAFCD176B)
        -- Intervalo experimental antes da quinta chave.
        context:start_timer("journey.finding.test_fifth_event", 3000)

    elseif event.timer_name == "journey.finding.test_fifth_event" then
        -- Quinta chave em teste; seu comportamento ainda não foi confirmado.
        context:scene(mission.Scene.SC_GHOST_FINDING):send_event {
            key = 0x3DCFB316,
        }
        context:set_variable("journey.finding.test_key", 0x3DCFB316)
        context:start_timer("journey.finding.test_sixth_event", 3000)

    elseif event.timer_name == "journey.finding.test_sixth_event" then
        -- Sexta chave em teste; não confirma o término da cura.
        context:scene(mission.Scene.SC_GHOST_FINDING):send_event {
            key = 0xB01280FE,
        }
        context:set_variable("journey.finding.test_key", 0xB01280FE)

    elseif event.timer_name == "journey.finding.healing_player" then
        -- Seleciona os jogadores sem alterar o filtro usado pelo Ghost.
        local filtro_jogador = context:slot(Slot.OF_HEALING_PLAYER)
        filtro_jogador:set_object_filter {
            players = true,
        }

        -- Solicita a cura do Guardião após o intervalo de sete segundos.
        -- Não remove o ferimento ou a queda nem confirma o fim da cena.
        context:slot(Slot.HO_HEALING_PLAYER):set_mission_effect {
            filter = filtro_jogador,
            enabled = true,
            revision = context.attempt_generation * 2,
        }

        -- Registra a solicitação de cura, sem confirmar seu término.
        context:set_variable("journey.finding.healing_requested", true)

        -- Etapas separadas por intervalos experimentais de três segundos.
        -- Os temporizadores não confirmam o término das animações.
        context:start_timer("journey.finding.healed_canal", 3000)

    elseif event.timer_name == "journey.finding.healed_canal" then
        -- Segunda etapa: solicita o estado curado do canal.
        local filtro_jogador = context:slot(Slot.OF_HEALING_PLAYER)
        context:slot(Slot.HO_HEALED_CANAL):set_mission_effect {
            filter = filtro_jogador,
            enabled = true,
            revision = context.attempt_generation * 2,
        }
        context:start_timer("journey.finding.transition_from_wounded", 3000)

    elseif event.timer_name == "journey.finding.transition_from_wounded" then
        -- Terceira etapa: solicita a transição de saída do estado ferido.
        local filtro_jogador = context:slot(Slot.OF_HEALING_PLAYER)
        context:slot(Slot.HO_TRANSITON_FROM_WOUNDED):set_mission_effect {
            filter = filtro_jogador,
            enabled = true,
            revision = context.attempt_generation * 2,
        }
        -- Só depois da transição será solicitada a remoção da câmera e da queda.
        context:start_timer("journey.finding.release_pose", 3000)

    elseif event.timer_name == "journey.finding.release_pose" then
    -- Remove juntos o estado de queda e o efeito de Guardião ferido.
    context:slot(Slot.HO_PLAYER_COLLAPSE):set_mission_effect {
        enabled = false,
        revision = context.attempt_generation * 2 + 1,
    }
    -- Encerra o estado ferido no mesmo momento em que a queda é removida.
    context:slot(Slot.HO_NOWEAPON_INJURED):set_mission_effect {
        enabled = false,
        revision = context.attempt_generation * 2 + 1,
    }

    -- Mantém a câmera por mais três segundos para observar a transição.
    context:start_timer("journey.finding.release_camera", 3000)

    elseif event.timer_name == "journey.finding.release_camera" then
    finish_initial_healing(context, state)
    -- A câmera é o último efeito removido nesta sequência.
    context:slot(Slot.HO_NOWEAPON_INJURED_CAMERA):set_mission_effect {
        enabled = false,
        revision = context.attempt_generation * 2 + 1,
    }
end
    -- Preserva os temporizadores normais da campanha.
    if previous_timer then
        previous_timer(context, state, event)
    end
end

local previous_trigger = program.on_event_player_trigger

program.on_event_player_trigger = function(context, state, event)
    local lib = require("lib.mission_lib")

    -- O Dawn só permite deixar a subida depois do combate do acampamento.
    falcons.update_combat(context,state,mount.encounters.climb.squads,beasts.squads)
    -- Encaminha os gatilhos para a lógica da montanha.
    mount.on_player_trigger(context, state, event)

    -- Solicita a fala 20 quando o jogador entra na área da cena de sombras.
    -- A variável impede repetir a solicitação enquanto estiver marcada.
    if lib.is_slot(context, event, Slot.PT_DLG_CITY_EXIT)
        and state:variable("journey.shadow.cue20_requested") ~= true then

        context:slot(Slot.M_DIALOG_SENSOR_80B5E02A):play_dialogue_cue {
            cue = mission.DialogueCue.M_DIALOG_SENSOR_80B5E02A.CUE_20,
        }

        context:set_variable("journey.shadow.cue20_requested", true)
    end
    -- Solicita a fala 16 quando o jogador entra na área da cena de sombras.
    -- A variável impede repetir a solicitação enquanto estiver marcada.
    if lib.is_slot(context, event, Slot.PT_SHADOW_SCENE)
        and state:variable("journey.shadow.cue16_requested") ~= true then

        context:slot(Slot.M_DIALOG_SENSOR_80B5E02A):play_dialogue_cue {
            cue = mission.DialogueCue.M_DIALOG_SENSOR_80B5E02A.CUE_16,
        }

        -- Solicita a seção musical 1 no mesmo gatilho da fala 16.
        -- Índice 1 usado pelo Dawn na cidade; aqui acompanha a fala 16.
        music.play(context, state, 1)
        context:set_variable("journey.shadow.cue16_requested", true)
    end
        -- Inicia o teste da ponte ao entrar na área dos tanques.
    -- A variável impede repetir a solicitação enquanto estiver marcada.
    if lib.is_slot(context, event, Slot.PT_SCENE_TANK)
        and state:variable("journey.bridge.requested") ~= true then

        -- Cancela os temporizadores do teste anterior de spawn separado.
        context:cancel_timer("journey.bridge.tank_1")
        context:cancel_timer("journey.bridge.tank_2")

        -- Usa a mesma preparação de elenco das cenas do telhado.
        -- A DLL reserva os squads e vincula os atores antes de ativar a cena.
        -- Este modo solicita o elenco completo, sem intervalo entre tanques.
        local cena = context:scene(mission.Scene.SC_BRIDGE_SCENE)
        cena:activate {
            spawn = true,
        }
        -- Testa somente a primeira chave.
        -- Ainda precisamos observar qual ação ela provoca no jogo.
        cena:send_event {
            key = 0x385838EC,
        }

        -- Registra a solicitação para acompanhar pela aba Mission state.
        -- Isso não confirma que a animação foi executada pelo cliente.
        context:set_variable("journey.bridge.requested", true)
        context:set_variable("journey.bridge.test_key", 0x385838EC)
    end
    -- Testa o sobrevoo uma única vez por tentativa.
    if lib.is_slot(context, event, Slot.PT_MOSQUITO_FLYBY)
    and state:variable("journey.flyby.requested") ~= true then

    -- Solicita a ativação do objeto da nave.
    context:activate_objects {
        slots = {Slot.O_MOSQUITO_FLYBY},
        active = true,
    }

    context:set_variable("journey.flyby.requested", true)

    -- Intervalo experimental para separar a ativação da sequência.
    context:start_timer("journey.flyby.play", 3000)
end

    -- Ativa a cena e solicita a primeira chave ao entrar no gatilho.
    if lib.is_slot(context, event, Slot.PT_OMG_GOGOGO)
        and state:variable("journey.rooftop.requested") ~= true then

        context:scene(mission.Scene.SC_ROOFTOP_SCENE):activate {
            spawn = true,
        }

        context:scene(mission.Scene.SC_ROOFTOP_SCENE):send_event {
            key = 0x385838EC,
        }

        context:set_variable("journey.rooftop.requested", true)
        context:set_variable("journey.rooftop.test_key", 0x385838EC)

        -- A primeira já foi solicitada; continua pela segunda.
        context:set_variable("journey.rooftop.next_key", 2)
        context:start_timer("journey.rooftop.test_event", 3000)
end

    -- Inicia as chaves da busca apenas na segunda área de saída do Ghost.
    if lib.is_slot(context, event, Slot.PT_GHOST_EXIT_2)
        and state:variable("journey.searching.started") ~= true
        and state:variable("journey.finding.requested") ~= true then
        context:scene(mission.Scene.SC_GHOST_SEARCHING):send_event {
            key = 0x385838EC,
        }
        context:set_variable("journey.searching.started", true)
        context:set_variable("journey.searching.test_key", 0x385838EC)
        context:set_variable("journey.searching.next_key", 2)
        -- As cinco chaves restantes seguem com três segundos entre elas.
        context:start_timer("journey.searching.next_event", 3000)
    end

    -- Identifica qual área de tropeço enviou o evento.
    local numero_tropeco = nil

    if lib.is_slot(context, event, Slot.PT_STUMBLE_1) then
        numero_tropeco = 1
    elseif lib.is_slot(context, event, Slot.PT_STUMBLE_2) then
        numero_tropeco = 2
    end

    if numero_tropeco ~= nil
        and state:variable("journey.collapse.applied") ~= true then

        -- Cada área aplica o efeito somente uma vez.
        local chave = "journey.stumble." .. numero_tropeco

        if state:variable(chave) ~= true then
            local filtro = context:slot(Slot.OF_STUMBLE_CITY)
            filtro:set_object_filter {
                players = true,
            }

            -- Uma revisão diferente permite reaplicar o efeito na segunda área.
            context:slot(Slot.HO_STUMBLE):set_mission_effect {
                filter = filtro,
                enabled = true,
                revision = context.attempt_generation * 10 + numero_tropeco,
            }

            context:set_variable(chave, true)
        end
    end

    -- Aplica a queda somente no gatilho correspondente,
    -- enquanto o jogador está ferido e apenas uma vez.
    if lib.is_slot(context, event, Slot.PT_PLAYER_COLLAPSE)
        and state:variable("journey.injured_test.active") == true
        and state:variable("journey.collapse.applied") ~= true then

        local filtro = context:slot(Slot.OF_SLOWDOWN_CITY)

        context:slot(Slot.HO_PLAYER_COLLAPSE):set_mission_effect {
            filter = filtro,
            enabled = true,
            revision = context.attempt_generation * 2,
        }

        context:set_variable("journey.collapse.applied", true)

        -- A segunda chave acontece neste gatilho; a terceira segue após o intervalo.
        if state:variable("journey.finding.requested") == true then
            context:scene(mission.Scene.SC_GHOST_FINDING):send_event {
                key = 0x86685186,
            }
            context:set_variable("journey.finding.test_key", 0x86685186)
            context:start_timer("journey.finding.test_second_event", 5000)
        end
    end

    -- Inicia o encontro e sua primeira chave na segunda área de tropeço.
    if lib.is_slot(context, event, Slot.PT_STUMBLE_2)
        and state:variable("journey.finding.requested") ~= true then

        -- Encerra a busca antes de ativar o encontro.
        context:cancel_timer("journey.searching.next_event")
        context:scene(mission.Scene.SC_GHOST_SEARCHING):stop{}
        context:scene(mission.Scene.SC_GHOST_FINDING):activate{}
        context:scene(mission.Scene.SC_GHOST_FINDING):send_event {
            key = 0x385838EC,
        }

        context:set_variable("journey.finding.requested", true)
        context:set_variable("journey.finding.test_key", 0x385838EC)
        -- Dá tempo para a cena processar a primeira chave antes dos efeitos do Ghost.
        context:start_timer("journey.finding.ghost_lights", 3000)
    end

    -- Mantém o processamento normal da campanha.
    if previous_trigger then
        previous_trigger(context, state, event)
    end

    -- Ao sair do canal, seleciona o estado jogável da região 24.
    if lib.is_slot(context, event, mount.transition.trigger)
        and state:variable("journey.mount.transition_requested") ~= true then
        finish_initial_healing(context, state)
        -- Impede novos eventos temporizados da cena de busca.
        context:cancel_timer("journey.searching.next_event")

        -- Encerra as cenas do Fantasma antes de sair da cidade.
        context:scene(mission.Scene.SC_GHOST_SEARCHING):stop{}
        context:scene(mission.Scene.SC_GHOST_FINDING):stop{}
        -- Agenda a preparação dos falcões após a confirmação de chegada.
        falcons.expect_arrival(context,"climb")
        context:set_variable("journey.mount.transition_requested", true)
        context:set_variable("journey.mount.transition_pending", true)
        context:start_timer("journey.mount.transition", 1000)
    end
end

local previous_load = program.on_load
program.on_load = function(context, state)
    -- Descarta os timers da versão anterior: somente o volume libera a cena.
    context:cancel_timer("journey.falcon_climb1.start")
    context:cancel_timer("journey.falcon_climb1.event")
    -- Cancela o teste anterior e remove o escurecimento caso ainda esteja ativo.
    context:cancel_timer("journey.mount.fade_timeout")
    if state:variable("journey.mount.transition_fade_active") == true then
        context:slot(Slot.HO_FADEOUT_CITY):set_mission_effect {
            enabled = false,
            revision = context.attempt_generation * 2 + 1,
        }
        context:set_variable("journey.mount.transition_fade_active", false)
    end
    -- Cancela o temporizador antigo sem remover os efeitos ao recarregar.
    context:cancel_timer("journey.injured_test.timeout")
    context:cancel_timer("journey.mount.transition")
    if state:variable("journey.mount.transition_pending") == true then
        falcons.expect_arrival(context,"climb")
        context:set_variable("journey.mount.transition_pending", false)
        context:set_variable("journey.music.pending", 2)
        checkpoints.select(context, "climb", mount.transition.state, {
            -- Preserva a omissão da arma até a etapa de interação.
            Slot.O_AUTO_RIFLE,
            spawn_set_hash = mount.transition.spawn_set_hash,
        })
    end
    if previous_load then previous_load(context, state) end
end

-- Só troca a trilha da chegada quando o cliente confirma a região jogável.
local previous_music_arrival = program.on_event_client_state_changed
program.on_event_client_state_changed = function(context, state, event)
    if previous_music_arrival then previous_music_arrival(context, state, event) end
    music.on_arrival(context, state, event)
    falcons.on_arrival(context,state,event)
end

-- Mantém os callbacks da campanha e observa o elenco e os combates dos falcões.
local previous_falcon_object = program.on_event_object_state
program.on_event_object_state = function(context,state,event)
    if previous_falcon_object then previous_falcon_object(context,state,event) end
    falcons.on_object_state(context,state,event)
end
local previous_falcon_squad = program.on_event_squad_state
program.on_event_squad_state = function(context,state,event)
    if previous_falcon_squad then previous_falcon_squad(context,state,event) end
    falcons.update_combat(context,state,mount.encounters.climb.squads,beasts.squads)
end
local previous_falcon_death = program.on_event_entity_died
program.on_event_entity_died = function(context,state,event)
    if previous_falcon_death then previous_falcon_death(context,state,event) end
    falcons.update_combat(context,state,mount.encounters.climb.squads,beasts.squads)
end

-- Ativa a area de Treva da atividade, sem iniciar uma contagem de wipe.
local function enable_journey_darkness(context)
    context:slot(Slot.HARD_WIPE_GLOBALS):set_darkness_zone {
        enabled = true,
    }
end

-- Preserva o inicio original da campanha.
local previous_darkness_start = program.on_start
program.on_start = function(context, state)
    enable_journey_darkness(context)
    if previous_darkness_start then previous_darkness_start(context, state) end
end

-- Reaplica a restricao ao recarregar o script durante a atividade.
local previous_darkness_load = program.on_load
program.on_load = function(context, state)
    enable_journey_darkness(context)
    if previous_darkness_load then previous_darkness_load(context, state) end
end

-- Restaura os efeitos e os controles especificos do trecho salvo.
local function restore_checkpoint_local(context, state, checkpoint)
    local filter = context:slot(Slot.OF_HEALING_PLAYER)
    filter:set_object_filter {players = true}
    for _, slot in ipairs {
        Slot.HO_HEALING_PLAYER, Slot.HO_HEALING_GHOST,
        Slot.HO_TRANSITON_FROM_WOUNDED, Slot.HO_HEALED_CANAL,
        Slot.HO_PLAYER_COLLAPSE, Slot.HO_NOWEAPON_INJURED,
        Slot.HO_NOWEAPON_INJURED_CAMERA, Slot.HO_FADEOUT_CITY,
    } do
        context:slot(slot):set_mission_effect {
            enabled = false, revision = context.attempt_generation * 2 - 1,
        }
    end
    context:slot(Slot.HARD_WIPE_GLOBALS):set_darkness_zone {enabled = true}
    context:slot(Slot.HO_NOPOWER_HAVEN):set_mission_effect {
        filter = filter, enabled = true,
        revision = context.attempt_generation * 2,
    }
    if checkpoint.area then
        context:set_variable("journey.finding.effects_finished", true)
        context:set_variable("journey.finding.requested", true)
        context:set_variable("journey.mount.transition_requested", true)
        context:set_variable("journey.mount.transition_pending", false)
        if checkpoint.area == "climb" then
            -- Conserva o estado pos-cura ate coletar a arma novamente.
            context:slot(Slot.HO_HEALED_CANAL):set_mission_effect {
                filter = filter, enabled = true,
                revision = context.attempt_generation * 2,
            }
        else
            -- O retorno do wipe nao e uma solicitacao do segundo teletransporte.
            context:clear_variable("journey.mountain.transition_requested")
            -- O wipe rearma o sobrevoo; o gatilho podera solicitar a nave novamente.
            context:clear_variable("journey.flyby2.effect_requested")
            context:clear_variable("journey.flyby2.cleaned")
            context:slot(Slot.HO_CABAL_CAPITAL_SHIP_FLYOVER):set_mission_effect {
                enabled = false, revision = context.attempt_generation * 2 - 1,
            }
            context:activate_objects {slots={Slot.O_CABAL_CARRIER}, active=false}
        end
        falcons.prepare(context, state, checkpoint.area)
    end
    music.play(context, state, checkpoint.music)
end

-- Instala os callbacks do wipe depois de todos os callbacks locais.
-- O canal position conserva o progresso entre teletransportes da mesma regiao.
-- Reposiciona a nave imediatamente e aguarda a confirmacao desta solicitacao.
local function prepare_checkpoint_return(context, state, checkpoint)
    context:slot(Slot.HO_CABAL_CAPITAL_SHIP_FLYOVER):set_mission_effect {
        enabled=false, revision=context.attempt_generation * 2 - 1,
    }
    return context:slot(Slot.D_CABAL_CARRIER):set_channel {
        channel=context.sdk.device_channels.position,
        value=context.sdk.unit(0), snap=true,
    }
end
program = checkpoints.install(program, {
    restore_local=restore_checkpoint_local,
    prepare_return=prepare_checkpoint_return,
    reset_next=falcons.reset_next,
})

return program
