local lib = require("lib.mission_lib")
-- Limpeza dos registros seen de ciclos encerrados; nao altera os esquadroes.
local variables = require("mission_towerfall.campaign.variables")
local plaza_repeat = {name = "plaza_repeat"}


function plaza_repeat.check(content, builder)
    local config = content.repeat_defense
    if config == nil then return end

    local legs = builder:need("legs")

    assert(legs.step_ids[config.start_step],
        "repeat_defense: etapa inicial desconhecida")

    assert(legs.armed[config.stop_trigger],
        "repeat_defense: gatilho de saída não habilitado")

    assert(type(config.waves) == "table" and #config.waves > 0,
        "repeat_defense: informe as ondas")

    -- Confere os dados necessários para o bombardeio.
    local bombardment = config.bombardment

    assert(type(bombardment) == "table",
        "repeat_defense: informe a configuração do bombardeio")

    assert(type(bombardment.combat_scene) == "table"
        and type(bombardment.combat_scene.id) == "string",
        "repeat_defense: cena de combate inválida")

    assert(type(bombardment.shield_scene) == "table"
        and type(bombardment.shield_scene.id) == "string",
        "repeat_defense: cena do escudo inválida")

    assert(bombardment.zavala_slot ~= nil,
        "repeat_defense: informe o slot de Zavala")

    assert(bombardment.missile_object ~= nil,
        "repeat_defense: informe o objeto dos mísseis")

    assert(bombardment.missile_device ~= nil,
        "repeat_defense: informe o dispositivo dos mísseis")

    assert(config.missile_cue ~= nil,
        "repeat_defense: informe a fala dos mísseis")

    assert(type(bombardment.prepare_ms) == "number"
        and bombardment.prepare_ms >= 0,
        "repeat_defense: tempo de preparação inválido")

    assert(type(bombardment.duration_ms) == "number"
        and bombardment.duration_ms > 0,
        "repeat_defense: duração do bombardeio inválida")
end

function plaza_repeat.build(content, builder)
        local config = content.repeat_defense
        if config == nil then return end

        local core = builder:need("core")

        -- Configuração das cenas e dos tempos do bombardeio.
        local bombardment = config.bombardment

        local function key(context, suffix)
            return content.key .. ".repeat_defense."
                .. tostring(context.attempt_generation) .. "." .. suffix
        end

        local function cycle(context, state)
            return state:variable(key(context, "cycle")) or 0
        end

        local function wave_for(number)
            -- O resto da divisão faz a seleção voltar ao início da lista.
            -- Com duas ondas: ciclos 1, 2, 3, 4 selecionam ondas 1, 2, 1, 2.
            -- O número do ciclo continua crescendo para distinguir eventos antigos.
            return config.waves[((number - 1) % #config.waves) + 1]
        end

        local function seen_key(context, number, index)
            return key(context, "cycle." .. number .. ".seen." .. index)
        end
        -- Descarta somente confirmacoes de ciclos que nao serao mais consultados.
    local function cleanup_old_cycles(context, state, last_finished)
        -- O marcador pertence a esta tentativa e evita percorrer o mesmo historico
        -- novamente. last_finished inclui o ultimo ciclo autorizado para descarte.
        local progress_key = key(context, "cleaned_through")
        local cleaned = state:variable(progress_key) or 0
        if last_finished <= cleaned then
            return
        end

        local disposable_names = {}

        -- Inclui tambem ciclos anteriores acumulados antes desta implementacao.
        -- A recuperacao pode pular numeros; remover nomes ausentes e permitido.
        for number = cleaned + 1, last_finished do
            for index in ipairs(wave_for(number)) do
                disposable_names[#disposable_names + 1] =
                    seen_key(context, number, index)
            end
        end

        local _, performed =
            variables.cleanup(context, disposable_names)

        if performed then
            -- Atualiza so depois da limpeza. As remocoes e o marcador participam
            -- da mesma transacao do callback na DLL.
            context:set_variable(progress_key, last_finished)
        end
    end

        local function timer_name(context, number)
            return key(context, "cycle." .. number .. ".interval")
        end

        -- Nome exclusivo do temporizador de aparecimento deste ciclo.
        local function spawn_timer_name(context, number)
            return key(context, "cycle." .. number .. ".spawn_timeout")
        end

        local function end_bombardment(context, state)
            -- Encerra somente os efeitos que esta repetição solicitou.
            if state:variable(key(context, "shield_owned")) == true then
                context:scene(bombardment.shield_scene.id):stop{}
                context:set_variable(key(context, "shield_owned"), false)
            end
            if state:variable(key(context, "missiles_owned")) == true then
                context:activate_objects{slots = {bombardment.missile_object}, active = false}
                context:set_variable(key(context, "missiles_owned"), false)
            end
            context:clear_variable(key(context, "shield_request"))
        end

        local function stop(context, state)
            end_bombardment(context, state)
            if state:variable(key(context, "combat_owned")) == true then
                context:scene(bombardment.combat_scene.id):stop{}
                context:set_variable(key(context, "combat_owned"), false)
            end
            context:clear_variable(key(context, "combat_request"))
            context:set_variable(key(context, "status"), "stopped")
            -- A repeticao parou: inclusive o ultimo ciclo pode ser descartado.
            -- Preserva status e identificadores para bloquear eventos atrasados.
            -- Isto limpa dados da repeticao, nao o progresso geral da missao.
            cleanup_old_cycles(context, state, cycle(context, state))
        end

        local function can_run(context, state)
            if state:variable(key(context, "status")) == "stopped" then
                return false
            end

            if core.finished(context, state, config.start_step) then
                stop(context, state)
                return false
            end

            return core.graph():started(context, state, config.start_step)
        end

        local function say(context, cue)
            context:slot(content.dialogue_sensor):play_dialogue_cue{
                cue = cue,
            }
        end
        -- Prepara Zavala para participar da cena do escudo.
        local function prepare_shield(context, state, restart)
            end_bombardment(context, state)
            -- Preserva o retorno à primeira onda durante toda a fase do bombardeio.
            context:set_variable(key(context, "restart_pending"), restart == true)
            context:set_variable(key(context, "status"), "preparing_shield")

            -- Libera Zavala da cena de combate.
            context:scene(bombardment.combat_scene.id):stop{}
            context:set_variable(key(context, "combat_owned"), false)
            context:clear_variable(key(context, "combat_request"))

            -- Identifica a preparação atual para ignorar temporizadores antigos.
            local generation =
                (state:variable(key(context, "bombardment_generation")) or 0) + 1

            context:set_variable(key(context, "bombardment_generation"), generation)

            context:start_timer(
                key(context, "shield_prepare." .. generation),
                bombardment.prepare_ms
            )
            -- Se a preparação ou a ativação não responder, segue sem bombardeio.
            context:start_timer(key(context, "shield_timeout." .. generation),
                bombardment.prepare_ms + 5000)
        end

        local function start_wave(context, state, restart)
            restart = restart == true or state:variable(key(context, "restart_pending")) == true
            context:set_variable(key(context, "restart_pending"), false)
            local number = cycle(context, state) + 1
            -- Avança até um identificador novo que selecione a primeira onda.
            -- Nunca reutiliza os registros nem os temporizadores de ciclos antigos.
            if restart then
                while (number - 1) % #config.waves ~= 0 do
                    number = number + 1
                end
            end
            local wave = wave_for(number)

            context:set_variable(key(context, "cycle"), number)
            context:set_variable(key(context, "status"), "combat")
            context:set_variable(key(context, "reinforcement_finished"), false)
            -- O novo ciclo ja foi selecionado; preserva suas confirmacoes.
            -- Limpa antes de alocar novos seen, mesmo com menos de 400 variaveis.
            cleanup_old_cycles(context, state, number - 1)

            -- Cada ciclo precisa de novas confirmações de integrantes vivos.
            for index in ipairs(wave) do
                context:set_variable(seen_key(context, number, index), false)
            end

            for _, unit in ipairs(wave) do
                context:slot(unit.source):assign_combat_objective{
                    objective = context:slot(config.objective),
                    task_group = unit.group,
                }

                local squad = context:squad(unit.squad)
                local request = {}
                -- Na recuperação, substitui os integrantes do esquadrão reiniciado.
                
                if restart then request.mode = context.sdk.squad_modes.replace end
                if unit.count ~= nil then
                    local counts = squad:counts()

                    for lane = 1, counts.count do
                        counts:set(lane, unit.count)
                    end

                    request.counts = counts
                end

                squad:place(request)
            end

            -- Dá 30 segundos para os esquadrões serem registrados vivos.
            context:start_timer(
                spawn_timer_name(context, number),
                30000
            )

            say(context, config.reinforcement_cue)
            -- Reativa o combate após liberar Zavala do escudo e dar tempo aos reforços.
            context:start_timer(key(context, "cycle." .. number .. ".combat_scene"), 3000)
        end

        local function wait_before_reinforcements(context, state)
            end_bombardment(context, state)
            -- Dá 3 segundos entre encerrar o escudo e posicionar os reforços.
            context:set_variable(key(context, "status"), "waiting_reinforcements")
            local generation = state:variable(key(context, "bombardment_generation"))
            context:start_timer(key(context, "reinforcements_wait." .. generation), 3000)
        end

        local function recovery_timer_name(context, number)
            return key(context, "cycle." .. number .. ".cleanup")
        end

        local function force_timer_name(context, number)
            return key(context, "cycle." .. number .. ".force_restart")
        end

        local function missing_spawn(context, state)
            local number = cycle(context, state)
            for index in ipairs(wave_for(number)) do
                if state:variable(seen_key(context, number, index)) ~= true then
                    return true
                end
            end
            return false
        end

        local function retire_wave(context, state)
            for _, unit in ipairs(wave_for(cycle(context, state))) do
                local squad = context:squad(unit.squad)
                local counts = squad:counts()
                for lane = 1, counts.count do counts:set(lane, 0) end
                -- Mesmo mecanismo de retirada usado por campaign/actions.lua.
                squad:place{counts = counts, mode = context.sdk.squad_modes.replace}
            end
        end

        local function begin_recovery(context, state)
            -- Impede que eventos da retirada sejam tratados como combate normal.
            context:set_variable(key(context, "status"), "recovering")
            context:scene(bombardment.combat_scene.id):stop{}
            context:set_variable(key(context, "combat_owned"), false)
            context:clear_variable(key(context, "combat_request"))
            retire_wave(context, state)
            -- As verificações intermediárias não renovam estes 2 segundos.
            context:start_timer(force_timer_name(context, cycle(context, state)), 2000)
            context:start_timer(recovery_timer_name(context, cycle(context, state)), 1000)
        end

        local function finish_recovery(context, state)
            local squads = {}
            for _, unit in ipairs(wave_for(cycle(context, state))) do
                squads[#squads + 1] = unit.squad
            end
            -- Se a retirada for confirmada, não precisa esperar o prazo máximo.
            if context:cohort{squads = squads}.alive_count == 0 then
                prepare_shield(context, state, true)
            else
                -- Verifica novamente sem adiar o reinício forçado.
                context:start_timer(recovery_timer_name(context, cycle(context, state)), 1000)
            end
        end

        local function wave_gone(context, state)
            local number = cycle(context, state)
            if number < 1 then return false end

            local squads = {}

            for index, unit in ipairs(wave_for(number)) do
                -- Zero vivos antes do primeiro aparecimento não é vitória.
                if state:variable(seen_key(context, number, index)) ~= true then
                    return false
                end

                squads[#squads + 1] = unit.squad
            end

            return context:cohort{squads = squads}.alive_count == 0
        end

        -- Diagnóstico: registra as condições sem alterar as regras de avanço.
        local function diagnose(context, state)
            local function record(name, value)
                local target = key(context, "debug." .. name)
                if state:variable(target) ~= value then
                    context:set_variable(target, value)
                end
            end

            local status = state:variable(key(context, "status")) or "waiting"
            local number = cycle(context, state)
            record("status", status)
            record("cycle", number)
            record("cue61_finished",
                state:variable(key(context, "reinforcement_finished")) == true)

            if number < 1 then return end
            local squads, missing = {}, {}
            for index, unit in ipairs(wave_for(number)) do
                squads[#squads + 1] = unit.squad
                if state:variable(seen_key(context, number, index)) ~= true then
                    missing[#missing + 1] = tostring(index)
                end
            end
            local alive = context:cohort{squads = squads}.alive_count
            record("missing_seen", #missing == 0 and "none" or table.concat(missing, ","))
            record("alive", alive == nil and "unknown" or alive)
        end

        -- Solicita o ataque com os mesmos comandos usados na entrada da praça.
        -- A repetição visual de um dispositivo já aberto precisa ser validada no jogo.
        local function begin_bombardment(context, state)
            local generation = state:variable(key(context, "bombardment_generation"))
            context:set_variable(key(context, "status"), "bombardment")
            context:set_variable(key(context, "missile_finished"), false)
            context:set_variable(key(context, "bombardment_elapsed"), false)
            say(context, config.missile_cue)

            -- Ativa o objeto do ataque após o envio das chaves da cena do escudo.
            context:activate_objects{
                slots = {bombardment.missile_object},
                active = true,
            }
            context:set_variable(key(context, "missiles_owned"), true)

            -- Solicita a abertura do dispositivo da torre para o ataque de mísseis.
            context:slot(bombardment.missile_device):transition{
                transition = context.sdk.device_transitions.open,
            }

            context:start_timer(
                key(context, "bombardment_end." .. generation),
                bombardment.duration_ms
            )
            -- Dá mais 15 segundos para receber o fim da CUE_60 após o tempo previsto.
            context:start_timer(key(context, "bombardment_timeout." .. generation),
                bombardment.duration_ms + 15000)
        end

        local function begin_interval(context, state)
            -- Usado tanto pelo término da CUE_62 quanto pelo prazo máximo.
            context:set_variable(key(context, "status"), "interval")
            context:start_timer(timer_name(context, cycle(context, state)), config.interval_ms or 8000)
        end

        local function update(context, state)
            diagnose(context, state)
            if not can_run(context, state) then return end

            local status = state:variable(key(context, "status"))

            -- Começa a fase após o envio das chaves da cena do escudo.
            if status == "shield_ready" then
                begin_bombardment(context, state)
                return
            end

            -- Exige o término da fala e do tempo, independentemente da ordem.
            if status == "bombardment" then
                if state:variable(key(context, "bombardment_elapsed")) == true
                    and state:variable(key(context, "missile_finished")) == true then
                    wait_before_reinforcements(context, state)
                end
                return
            end

            if status == "shield_failed" then
                -- Uma falha na cena não deve impedir a chegada dos reforços.
                wait_before_reinforcements(context, state)
                return
            end

            if status == nil or status == "active" then
                prepare_shield(context, state)
                return
            end

            if status == "combat"
                and state:variable(key(context, "reinforcement_finished")) == true
                and wave_gone(context, state) then

                -- Aguarda CUE_61 terminar antes de solicitar CUE_62.
                context:set_variable(key(context, "status"), "advance_dialogue")
                say(context, config.advance_cue)
                -- Não depende indefinidamente da confirmação de término da fala.
                context:start_timer(key(context, "cycle." .. cycle(context, state) .. ".advance_timeout"), 15000)
            end
        end

        builder:on("on_event_player_trigger", function(context, state, event)
            if lib.is_slot(context, event, config.stop_trigger) then
                stop(context, state)
            end
        end)

        builder:on("on_event_squad_state", function(context, state, event)
            if not can_run(context, state) then return end
            if state:variable(key(context, "status")) ~= "combat" then
                return
            end

            local number = cycle(context, state)
            if number < 1 then return end

            for index, unit in ipairs(wave_for(number)) do
                if lib.is_slot(context, event, unit.source)
                    and (event.alive_count or 0) > 0 then

                    context:set_variable(
                        seen_key(context, number, index),
                        true
                    )
                end
            end

            update(context, state)
        end)
        -- Trata o resultado da ativação da cena do escudo.
builder:on("on_event_effect_result", function(context, state, event)
    if not can_run(context, state) then return end

    -- Aceita somente resultados de ativação de cenas.
    if event.effect ~= "scene.activate"
        or event.request_key == nil then
        return
    end

    -- A cena de combate usa keys = {}, como nas ondas obrigatórias.
    -- Registra a resposta sem enviar as chaves do escudo para essa cena.
    local combat_request = state:variable(key(context, "combat_request"))
    if combat_request ~= nil and combat_request == event.request_key.value then
        context:clear_variable(key(context, "combat_request"))
        context:set_variable(key(context, "debug.combat_outcome"), tostring(event.outcome))
        return
    end

    -- Ignora solicitações de outras cenas ou de preparações anteriores.
    local pending = state:variable(key(context, "shield_request"))

        if pending == nil or pending ~= event.request_key.value then
            return
        end

        context:clear_variable(key(context, "shield_request"))

        if state:variable(key(context, "status")) ~= "shield_pending" then
            return
        end

        -- Só envia as chaves quando a ativação foi preparada para transporte.
        if event.outcome == "transport_staged" then
            local shield = context:scene(bombardment.shield_scene.id)

            for _, event_key in ipairs(bombardment.shield_scene.event_keys or {}) do
                shield:send_event{key = event_key}
            end

            context:set_variable(key(context, "status"), "shield_ready")
        else
            -- Guarda o resultado para identificar uma ativação não aceita.
            context:set_variable(
                key(context, "debug.shield_outcome"),
                tostring(event.outcome)
            )
            context:set_variable(key(context, "status"), "shield_failed")
        end
    end)

        builder:on("on_event_dialogue_finished", function(context, state, event)
            if not can_run(context, state) then return end

            context:set_variable(key(context, "debug.last_finished_cue"), event.cue or -1)

            -- Só aceita eventos do sensor de diálogo desta missão.
            local sensor = context:slot(content.dialogue_sensor)

            if event.dialogue_registry_key ~= sensor.registry_key
                or event.dialogue_slot_type ~= sensor.slot_type
                or event.dialogue_slot_index ~= sensor.slot_index then
                return
            end

            local status = state:variable(key(context, "status"))

            -- Este evento já passou pela verificação do sensor de diálogo.
            if status == "bombardment" and event.cue == config.missile_cue then
                context:set_variable(key(context, "missile_finished"), true)
                update(context, state)
                return
            end

            if status == "combat"
                and event.cue == config.reinforcement_cue then

                context:set_variable(
                    key(context, "reinforcement_finished"),
                    true
                )
                update(context, state)

            elseif status == "advance_dialogue"
                and event.cue == config.advance_cue then

                begin_interval(context, state)
            end
        end)

        builder:on("on_event_timer_elapsed", function(context, state, event)
            if not can_run(context, state) then return end
            -- Aceita somente o temporizador da preparação atual.
            local generation =
                state:variable(key(context, "bombardment_generation"))

            -- Limites de espera exclusivos da preparação atual; eventos antigos são ignorados.
            if generation ~= nil
                and event.timer_name == key(context, "reinforcements_wait." .. generation) then
                if state:variable(key(context, "status")) == "waiting_reinforcements" then
                    start_wave(context, state)
                end
                return
            end
            if generation ~= nil
                and event.timer_name == key(context, "shield_timeout." .. generation) then
                local status = state:variable(key(context, "status"))
                if status == "preparing_shield" or status == "shield_pending" then
                    context:set_variable(key(context, "debug.shield_outcome"), "timeout")
                    wait_before_reinforcements(context, state)
                end
                return
            end
            if generation ~= nil
                and event.timer_name == key(context, "bombardment_timeout." .. generation) then
                if state:variable(key(context, "status")) == "bombardment" then
                    context:set_variable(key(context, "debug.shield_outcome"), "dialogue_timeout")
                    wait_before_reinforcements(context, state)
                end
                return
            end

            -- Só aceita o término do bombardeio da preparação atual.
            if generation ~= nil
                and event.timer_name == key(context, "bombardment_end." .. generation) then
                if state:variable(key(context, "status")) == "bombardment" then
                    context:set_variable(key(context, "bombardment_elapsed"), true)
                    update(context, state)
                end
                return
            end

            if generation ~= nil
                and event.timer_name == key(context, "shield_prepare." .. generation) then

                if state:variable(key(context, "status")) == "preparing_shield" then
                    -- Vincula a cena ao Zavala existente.
                    context:slot(bombardment.zavala_slot):bind_combatant_to_squad{}

                    context:set_variable(key(context, "status"), "shield_pending")
                    context:set_variable(key(context, "shield_owned"), true)

                    -- Guarda a solicitação para reconhecer sua confirmação.
                    local request =
                        context:scene(bombardment.shield_scene.id):activate{}

                    context:set_variable(key(context, "shield_request"), request.value)
                end

                return
            end
            local number = cycle(context, state)
            local status = state:variable(key(context, "status"))
            if event.timer_name == key(context, "cycle." .. number .. ".combat_scene") then
                if status == "combat" then
                    context:slot(bombardment.zavala_slot):bind_combatant_to_squad{}
                    context:set_variable(key(context, "combat_owned"), true)
                    local request = context:scene(bombardment.combat_scene.id):activate{}
                    context:set_variable(key(context, "combat_request"), request.value)
                    context:set_variable(key(context, "debug.combat_outcome"), "pending")
                end
                return
            end
            if event.timer_name == key(context, "cycle." .. number .. ".advance_timeout") then
                if status == "advance_dialogue" then
                    context:set_variable(key(context, "debug.cue62_timeout"), true)
                    begin_interval(context, state)
                end
                return
            end
            -- Só o temporizador do ciclo atual pode iniciar uma recuperação.
            if event.timer_name == force_timer_name(context, number) then
                if status == "recovering" then
                    -- Repete a retirada e reinicia mesmo sem confirmação do cliente.
                    retire_wave(context, state)
                    prepare_shield(context, state, true)
                end
                return
            end
            if event.timer_name == spawn_timer_name(context, number) then
                if status == "combat" and missing_spawn(context, state) then
                    begin_recovery(context, state)
                end
                return
            end
            if event.timer_name == recovery_timer_name(context, number) then
                if status == "recovering" then
                    finish_recovery(context, state)
                end
                return
            end
            if state:variable(key(context, "status")) ~= "interval" then
                return
            end

            if event.timer_name == timer_name(context, cycle(context, state)) then
                prepare_shield(context, state)
            end
        end)

        builder:after_handle(function(context, state, event)
            -- Confere a saída antes de iniciar qualquer ação nova.
            if event ~= nil
                and lib.is_slot(context, event, config.stop_trigger) then
                stop(context, state)
                return
            end

            update(context, state)
        end)

        builder:on_load(function(context, state)
            update(context, state)
        end)
    end
return plaza_repeat
