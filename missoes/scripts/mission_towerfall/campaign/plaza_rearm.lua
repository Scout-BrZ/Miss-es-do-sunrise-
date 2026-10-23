-- Recupera os misseis e, depois de oito segundos, a defesa e a primeira onda.
-- Depende do fallback de spire em plaza.lua e do suporte em encounters.lua.
local recovery = {name = "plaza_rearm"}

function recovery.build(content, builder)
    local core = builder:need("core")
    local encounters = builder:need("encounters")

    -- Consulta a regiao declarada pela missao, sem fixar seu numero.
    local plaza_region
    for _, leg in ipairs(content.legs or {}) do
        if leg.id == "plaza" then
            plaza_region = leg.state.region_index
            break
        end
    end
    if plaza_region == nil then return end

    -- Chaves fixas evitam acumular variaveis entre tentativas.
    -- Este prefixo corresponde ao usado pelo fallback em plaza.lua.
    local prefix = "towerfall.plaza_recovery."
    local owner_key = prefix .. "attempt"
    local region_key = prefix .. "region"
    local status_key = prefix .. "status"
    local request_key = prefix .. "request"
    -- Controla a recuperação da defesa usando chaves fixas.
    local defense_key = prefix .. "defense"
    local defense_status_key = prefix .. "defense_status"

    local function defense_timer_name(context)
        return prefix .. "defense_timer."
            .. tostring(context.attempt_generation)
    end

    -- Cada temporizador pertence a uma tentativa especifica.
    local function timer_name(context)
        return prefix .. "timer." .. tostring(context.attempt_generation)
    end

    local function reset_attempt(context, state)
        local owner = state:variable(owner_key)
        if owner == context.attempt_generation then return end
        if owner ~= nil then
            context:cancel_timer(prefix .. "timer." .. tostring(owner))
        end
        -- Cancela o temporizador da defesa da tentativa anterior.
        if owner ~= nil then
            context:cancel_timer(
                prefix .. "defense_timer." .. tostring(owner))
        end
        context:set_variable(defense_key, false)
        context:set_variable(defense_status_key, "idle")
        context:set_variable(owner_key, context.attempt_generation)
        context:set_variable(region_key, -1)
        context:set_variable(request_key, false)
        context:set_variable(status_key, "idle")
    end

    -- Exige a regiao correta, a etapa ativa e o encontro ainda nao iniciado.
    local function eligible(context, state)
        return state:variable(region_key) == plaza_region
            and core.graph():started(context, state, "plaza")
            and not core.finished(context, state, "plaza")
            and not encounters.placed(context, state, "spire")
    end

    local function update(context, state)
        reset_attempt(context, state)
        local status = state:variable(status_key)
        if eligible(context, state) then
            if status == "idle" then
                context:start_timer(timer_name(context), 5000)
                context:set_variable(status_key, "waiting")
            end
        elseif status == "waiting" then
            -- Cancela se sair da regiao, avancar ou receber o inicio normal.
            -- Nao agenda uma segunda recuperacao na mesma tentativa.
            context:cancel_timer(timer_name(context))
            context:set_variable(status_key, "canceled")
        end
    end

    -- Somente eventos de regiao confirmam onde o jogador esta.
    -- Um indice presente em outro evento nao deve substituir essa informacao.
    builder:on("on_event_region_changed", function(context, state, event)
        reset_attempt(context, state)
        if event.region_index ~= nil then
            context:set_variable(region_key, event.region_index)
        end
        update(context, state)
    end)
    builder:on("on_event_client_state_changed", function(context, state, event)
        -- Ignora regioes pendentes que o cliente ainda nao confirmou.
        if event.entered ~= true or event.held_region_index == nil then return end
        reset_attempt(context, state)
        context:set_variable(region_key, event.held_region_index)
        update(context, state)
    end)

    builder:on("on_event_timer_elapsed", function(context, state, event)
        -- Ignora temporizadores de outra tentativa ou ja cancelados.
        if event.timer_name ~= timer_name(context) then return end
        if state:variable(owner_key) ~= context.attempt_generation then return end
        if state:variable(status_key) ~= "waiting" then return end
        if not eligible(context, state) then
            context:set_variable(status_key, "canceled")
            return
        end

        -- Autoriza o encontro original, sem duplicar suas acoes neste modulo.
        context:set_variable(request_key, context.attempt_generation)
        context:set_variable(status_key, "fallback_requested")
        builder:advance(context, state)

        -- A autorizacao vale apenas nesta avaliacao. O grafo guarda o inicio
        -- do encontro e impede repeti-lo quando o cliente responder atrasado.
        context:set_variable(request_key, false)
        if encounters.placed(context, state, "spire") then
            context:set_variable(status_key, "fallback_started")
        else
            context:set_variable(status_key, "fallback_not_started")
        end
    end)

    -- Reinicializa o controle quando a tentativa muda e acompanha os grafos.
    -- Diagnosticos: idle = inativo; waiting = aguardando; canceled = cancelado;
    -- fallback_requested = solicitado; fallback_started = encontro iniciado;
    -- fallback_not_started = encontro nao iniciado.
    -- Encontro iniciado no Lua nao confirma que o cliente exibiu a animacao.
    builder:on_start(reset_attempt)
    builder:on_load(reset_attempt)
     -- Aguarda mais oito segundos depois da recuperação dos mísseis.
    -- Este caminho é por tempo: não mede a distância até Zavala.
    builder:after_handle(function(context, state)
        if state:variable(owner_key) ~= context.attempt_generation then
            return
        end

        local active = state:variable(region_key) == plaza_region
            and core.graph():started(context, state, "plaza")
            and not core.finished(context, state, "wave1")

        local status = state:variable(defense_status_key)

        if not active then
            if status == "waiting" then
                context:cancel_timer(defense_timer_name(context))
                context:set_variable(defense_status_key, "canceled")
            end
            -- Não deixa uma autorização pendente fora da região.
            context:set_variable(defense_key, false)
            return
        end

        if status == "idle"
            and state:variable(status_key) == "fallback_started"
            and not encounters.placed(context, state, "wave1") then
            context:start_timer(defense_timer_name(context), 8000)
            context:set_variable(defense_status_key, "waiting")
        elseif status == "waiting"
            and encounters.placed(context, state, "wave1") then
            context:cancel_timer(defense_timer_name(context))
            context:set_variable(defense_status_key, "normal_started")
        end
    end)

    builder:on("on_event_timer_elapsed", function(context, state, event)
        if event.timer_name ~= defense_timer_name(context) then return end
        if state:variable(owner_key) ~= context.attempt_generation then
            return
        end
        if state:variable(defense_status_key) ~= "waiting" then return end

        -- Confere novamente as condições quando o prazo termina.
        if state:variable(region_key) ~= plaza_region
            or not core.graph():started(context, state, "plaza")
            or core.finished(context, state, "wave1")
            or not encounters.placed(context, state, "spire") then
            context:set_variable(defense_status_key, "canceled")
            return
        end

        if encounters.placed(context, state, "wave1") then
            context:set_variable(defense_status_key, "normal_started")
            return
        end

        -- O grafo principal libera a defesa; o grafo de encontros
        -- inicia a sequência original da primeira onda uma única vez.
        context:set_variable(defense_key, context.attempt_generation)
        builder:advance(context, state)
        context:set_variable(defense_key, false)

        if encounters.placed(context, state, "wave1") then
            context:set_variable(defense_status_key, "fallback_started")
        else
            context:set_variable(defense_status_key, "fallback_not_started")
        end
    end)
    builder:after_handle(update)
end

return recovery
