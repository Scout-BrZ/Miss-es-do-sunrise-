-- Sequência de etapas compartilhada pelos rascunhos das missões da campanha.
-- Uma missão é uma declaração de conteúdo. Cada módulo em mission_towerfall/campaign/ cuida de alguns de seus campos
-- e constrói sua parte do programa; campaign.new reúne esses módulos na ordem da lista.
local lib = require("lib.mission_lib")
local builder = require("mission_towerfall.campaign.builder")

local campaign = {}
--- Identifica um esquadrão e o slot do tipo 1 que o contém.
--- @param squad Identificador gerado do esquadrão.
--- @param source Identificador gerado do slot correspondente ao mesmo esquadrão.
--- @param group Grupo de tarefas extraído, opcional, para o objetivo do encontro.
--- @param count Quantidade opcional de integrantes posicionados em cada faixa, em vez do padrão do pacote.
function campaign.unit(squad, source, group, count)
    return {squad = lib.one(squad, "squad"), source = lib.one(source, "squad slot"), group = group,
        count = count}
end

--- Uma fala e a área de ativação que o cliente aguarda o jogador alcançar para reproduzi-la.
function campaign.line(cue, filter)
    return {cue = lib.one(cue, "dialogue cue"), filter = filter}
end

--- Uma semente de geração que muda a cada tentativa e nunca é zero.
--- O ambiente isolado não tem fonte de aleatoriedade, então o número da tentativa mantido pelo host é o único valor variável.
--- @param context Contexto da função de retorno (callback).
--- @return Um número inteiro positivo de 31 bits.
function campaign.run_seed(context)
    local attempt = tonumber(context.attempt_generation) or 1
    local seed = attempt % 0x7FFFFFFF
    if seed == 0 then return 1 end
    return seed
end

--- Move cada slot de dispositivo usando a transição indicada.
function campaign.move(context, slots, transition)
    for _, slot in ipairs(slots) do
        context:slot(slot):transition{transition = context.sdk.device_transitions[transition]}
    end
end

--- Módulos que compõem cada missão da campanha, na ordem de execução de check, declare e build.
campaign.capabilities = {
    require("mission_towerfall.campaign.intro"),
    require("mission_towerfall.campaign.core"),
    require("mission_towerfall.campaign.encounters"),
    require("mission_towerfall.campaign.pathing"),
    require("mission_towerfall.campaign.scenes"),
    require("mission_towerfall.campaign.actions"),
    require("mission_towerfall.campaign.sequence"),
    require("mission_towerfall.campaign.cutscenes"),
    require("mission_towerfall.campaign.checkpoints"),
    require("mission_towerfall.campaign.dialogue"),
    require("mission_towerfall.campaign.kills"),
    require("mission_towerfall.campaign.devices"),
    require("mission_towerfall.campaign.plaza_repeat"),
    require("mission_towerfall.campaign.plaza_rearm"),


}
--- Constrói a tabela da missão a partir de uma declaração de conteúdo.
--- @param content Tabela com key, sensores, trechos com suas listas de gatilhos e monitores, etapas e
--- encontros; uma lista opcional intro de cenas {state, cinematic} reproduzidas antes do primeiro
--- trecho; um spawn_set opcional que identifica os pontos de início usados pelo cliente para filtrar o surgimento do jogador; e um
--- debug_start opcional que inicia a missão em uma etapa posterior (veja mission_towerfall/campaign/debug.lua). O cabeçalho de cada
--- módulo lista os demais campos que ele lê.
--- @return A tabela carregada pelo ambiente de execução: initial_state, on_start, on_load e funções de tratamento de eventos.
function campaign.new(content)
    return builder.assemble(require("mission_towerfall.campaign.debug").apply(content), campaign.capabilities)
end

return campaign

