-- The Farm: reproduz o unico slot de cinematica declarado neste cenario.
-- Este arquivo pertence a scripts/cine_farm_325/, nao a sdk/lua/missions/.
local mission = require("missions.cine_farm_325_80b84a1c")
local lib = require("lib.mission_lib")

local VIDEO = mission.Slot.PF_CINEMATIC_BOOKEND_CINEMATIC
local CINEMATICA = mission.states.STATE_80B84A1C_0000_0001_80B84A1B
local CHEGADA = mission.states.STATE_80B84A1C_0000_0000_80B84A1A
local CHAVE = "farm.cinematica.fase"
local SOLICITADA, REPRODUZINDO, RETORNANDO, CONCLUIDA = 1, 2, 3, 4

-- A regiao atual e confirmada pelo cliente. Uma regiao apenas pendente nao inicia o video.
local function chegou(context, state, event)
    local regiao = event.current_region_index
    if regiao == nil and event.entered == true then
        regiao = event.held_region_index
    end
    local fase = state:variable(CHAVE)
    if regiao == CINEMATICA.region_index and fase == nil then
        context:set_variable(CHAVE, SOLICITADA)
        context:slot(VIDEO):set_cinematic_active{active = true}
    elseif regiao == CHEGADA.region_index and fase == RETORNANDO then
        -- Libera o jogador somente quando o estado de chegada estiver carregado.
        context:hold_spawn{active = false}
        context:set_variable(CHAVE, CONCLUIDA)
        context:complete_mission{}
    end
end

return {
    -- O objeto da cinematica pertence a regiao 1, confirmado nos pacotes instalados.
    initial_state = {region_index = CINEMATICA.region_index},

    on_start = function(context)
        -- Evita criar o corpo do jogador enquanto a cinematica esta carregando.
        context:hold_spawn{active = true}
    end,

    on_load = function(context, state)
        -- Recarregar o script nao solicita o mesmo video novamente.
        if state:variable(CHAVE) ~= CONCLUIDA then
            context:hold_spawn{active = true}
        end
    end,

    on_event_client_state_changed = chegou,

    on_event_cinematic_started = function(context, state, event)
        -- Uma solicitacao aceita ainda nao prova reproducao: aguarda o informe de inicio.
        if lib.is_slot(context, event, VIDEO)
            and state:variable(CHAVE) == SOLICITADA then
            context:set_variable(CHAVE, REPRODUZINDO)
        end
    end,

    on_event_cinematic_terminated = function(context, state, event)
        -- Um inicio recusado tambem pode gerar termino; exige que o video tenha iniciado.
        if not lib.is_slot(context, event, VIDEO)
            or state:variable(CHAVE) ~= REPRODUZINDO then
            return
        end
        -- Para o slot antes de trocar o estado, para nao reiniciar a cinematica.
        context:slot(VIDEO):set_cinematic_active{active = false}
        context:set_variable(CHAVE, RETORNANDO)
        context:select_state(CHEGADA)
    end,

    on_event_cinematic_skip_requested = function(context, state, event)
        -- Pedir para pular nao confirma termino. O informe terminated acima encerra o video.
    end,
}
