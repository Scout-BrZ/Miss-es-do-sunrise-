-- Auxiliar de limpeza: o chamador escolhe os nomes que nao serao mais lidos.
-- Nao percorre todas as variaveis nem decide sozinho quais dados sao dispensaveis.
local variables = {}

-- Referencia de consumo para diagnostico; nao bloqueia a limpeza preventiva.
local CLEANUP_THRESHOLD = 400

function variables.should_cleanup(context)
    return context:variable_count() >= CLEANUP_THRESHOLD
end

-- Remove somente nomes comprovadamente descartaveis, mesmo abaixo de 400.
-- should_cleanup permanece disponivel para diagnosticar o consumo geral.
function variables.cleanup(context, disposable_names)
    local removed = 0

    for _, name in ipairs(disposable_names) do
        -- A DLL libera a entrada de verdade. Gravar false ou zero nao liberaria.
        -- Um nome inexistente retorna false, inclusive em ciclos pulados.
        if context:clear_variable(name) then
            removed = removed + 1
        end
    end

    -- removed conta entradas existentes; true indica que a lista foi processada,
    -- mesmo quando todos os nomes ja estavam ausentes.
    return removed, true
end

return variables
