-- Homecoming (Retorno ao Lar). Um arquivo por região, na ordem em que o jogador passa por elas;
-- cada um retorna seus trechos, etapas, encontros e objetos omitidos pelas configurações iniciais. shared.lua define os elementos compartilhados.

local campaign = require("mission_towerfall.campaign")
local shared = require("mission_towerfall.shared")

local bubbles = {
    require("mission_towerfall.underwatch"),
    require("mission_towerfall.military"),
    require("mission_towerfall.plaza"),
    require("mission_towerfall.boulevard"),
    require("mission_towerfall.sky_battle"),
}

local legs, steps, encounters, omit = {}, {}, {}, {}
local repeat_defense
local function append(target, source)
    for _, value in ipairs(source or {}) do target[#target + 1] = value end
end
for _, bubble in ipairs(bubbles) do
    append(legs, bubble.legs)
    append(steps, bubble.steps)
    append(encounters, bubble.encounters)
    append(omit, bubble.omit)

    if bubble.repeat_defense ~= nil then
        repeat_defense = bubble.repeat_defense
    end

end

-- Apenas para desenvolvimento: inicia a missão em uma região posterior, considerando as etapas anteriores como já realizadas.
-- Defina como nil para jogar a missão inteira.
local DEBUG_START = nil

return campaign.new{
    key = "towerfall",
    -- Ao iniciar landing em sky_battle, compacta sequencias anteriores ja concluidas.
    -- Cada uma troca seus registros detalhados por um marcador retired da tentativa.
    -- Preserva a progressao principal e sequencias em andamento; nao apaga tudo.
    -- Retirar esta opcao desativa a compactacao para novas execucoes. Nao restaura
    -- registros ja removidos de uma sessao existente: teste mudancas em missao nova.
    compact_sequences_at = "landing",
    debug_start = DEBUG_START,
    directive_sensor = shared.directive_sensor,
    dialogue_sensor = shared.dialogue_sensor,
    music_sensor = shared.music_sensor,
    -- O Guardião chega voando sobre a Cidade logo após o vídeo de abertura da atividade anterior.
    intro = {{state = shared.states.opening, cinematic = shared.Slot.PREFAB_HRO_CINEMATIC}},
    legs = legs,
    steps = steps,
    encounters = encounters,
    omit = omit,
    repeat_defense = repeat_defense,
}
