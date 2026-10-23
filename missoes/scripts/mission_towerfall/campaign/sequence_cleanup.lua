-- Compacta sequencias concluidas sem permitir que suas acoes sejam repetidas.
-- Substitui o detalhamento de uma sequencia por um registro retired da tentativa.
-- Nao limpa o grafo principal da missao, objetivos ou checkpoints gerais.
local cleanup = {}

-- graph e o controlador original; definition descreve suas chaves exatas;
-- eligible confirma que a missao alcancou a etapa configurada para compactacao.
function cleanup.wrap(graph, definition, eligible)
    local prefix = "flow." .. definition.key
    local retired_key = definition.key .. ".retired"
    -- Estes tres estados pertencem apenas a sequencia encapsulada.
    -- Os prefixos seguem o formato usado por lib/flow.lua; nao sao buscas globais.
    local names = {
        prefix .. ".state.owner",
        prefix .. ".state.canceled",
        prefix .. ".state.checkpoint",
    }
    for _, fact in ipairs(definition.facts or {}) do
        -- Fatos registram eventos/esperas ja satisfeitos pela sequencia concluida.
        names[#names + 1] = prefix .. ".fact." .. fact.id
    end
    for _, step in ipairs(definition.steps) do
        -- Passos registram acoes e esperas individuais, dispensaveis apos o fim.
        names[#names + 1] = prefix .. ".step." .. step.id
    end

    local function retired(context, state)
        -- Reload na mesma tentativa preserva a conclusao. Em outra tentativa,
        -- o marcador antigo nao vale e o grafo original volta a cuidar do reinicio.
        return state:variable(retired_key) == context.attempt_generation
    end

    local function compact(context, state)
        -- A verificacao repetida e inofensiva; nunca compacta uma sequencia parcial.
        if retired(context, state) then return true end
        if not eligible(context, state) or not graph:finished(context, state) then
            return false
        end
        -- Libera primeiro os registros detalhados, para nao exigir uma vaga extra.
        -- Tudo ocorre na transacao do callback: falhas nao devem confirmar apenas
        -- metade da troca entre registros detalhados e o marcador de conclusao.
        for _, name in ipairs(names) do context:clear_variable(name) end
        context:set_variable(retired_key, context.attempt_generation)
        return true
    end

    local wrapper = {}
    function wrapper:handle(context, state, event)
        -- Eventos atrasados nao chegam ao grafo depois que ele foi compactado.
        if compact(context, state) then return true end
        local result = graph:handle(context, state, event)
        -- O evento pode ter acabado de concluir a sequencia.
        compact(context, state)
        return result
    end
    function wrapper:advance(context, state)
        -- Aplica a mesma regra quando a campanha avanca sem receber um evento.
        if compact(context, state) then return true end
        local result = graph:advance(context, state)
        compact(context, state)
        return result
    end
    function wrapper:finished(context, state)
        -- Mantem verdadeira a dependencia de quem espera esta sequencia terminar.
        return retired(context, state) or graph:finished(context, state)
    end
    function wrapper:started(context, state, id)
        -- Uma sequencia inteiramente concluida ja iniciou todos os seus passos.
        return retired(context, state) or graph:started(context, state, id)
    end
    return wrapper
end

return cleanup
