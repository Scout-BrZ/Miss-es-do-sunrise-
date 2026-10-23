-- Alterações declarativas no mundo que uma etapa, encontro ou item de sequência pode conter:
--   move     = {to = "<transição do dispositivo>", slots = {slots do tipo 23}, snap = true}
--   objects  = {slots = {slots do tipo 4}, active = false}
--   signal   = {scene = mission.scenes.<NOME>, keys = {chaves de evento}} envia chaves para uma cena ativa
--   stop     = {mission.scenes.<NOME>, ...}                           encerra a geração de cada cena
--   retire   = {Squad.<NOME>, ...}                                    remove os integrantes dos esquadrões
--   interact = {slots = {slots do tipo 4}, active = false, used = false} disponibiliza ou retira uma interação
--   music    = seção, ou {section = seção, enabled = false}          seleciona uma seção musical
--   perform  = {cells = {slots do tipo 2}, sequence = "<SÍMBOLO DA SEQUÊNCIA>"}
--              cria o ator de cada célula reproduzindo essa sequência de sua própria tabela de ações
--   travel   = {cell = slot do tipo 2, path = slot do tipo 58, spawn = false}
--              faz o ator da célula voar pelo trajeto predefinido em seu registro, como a entrada
--              de uma nave de transporte; cria o ator, exceto quando `spawn = false` usa um já existente
--   effect   = {slot = hop-on do tipo 26, filter = filtro do tipo 34, target = objeto do tipo 4,
--               enabled = false, arm = false}
--              aplica o efeito predefinido do hop-on (escudo, perigo ou desvanecimento) ao que
--              o filtro seleciona: todos os jogadores ou o objeto `target`, a menos que `arm = false`
--              preserve a configuração original do filtro. `enabled = false` remove o efeito.
--              Cada chamada usa uma nova revisão.
--   toggle   = {slot = sensor do tipo 32, state = 1, target = slot}
--              ajusta um alternador predefinido; o significado do estado e do alvo depende do conteúdo
-- As ações são executadas nessa ordem, após as cenas da configuração que as contém. A música usa
-- o `music_sensor` da missão. Um ator criado por `perform` não tem objetivo: `assign` pode atribuí-lo após o pouso.
local lib = require("lib.mission_lib")
local common = require("mission_towerfall.campaign.common")

local actions = {name = "actions"}

local function slots(value, where)
    assert(type(value) == "table" and #value > 0, where .. " needs a nonempty slot list")
    for index = 1, #value do lib.one(value[index], where .. " slot " .. index) end
end

local function scene(value, where)
    assert(type(value) == "table" and type(value.id) == "string",
        where .. " must name a mission.scenes entry")
end

-- Um sensor de música comporta 128 seções.
local MUSIC_SECTIONS = 128

-- `music = 8` é uma abreviação de `music = {section = 8}`.
local function music_of(value)
    if type(value) == "table" then return value end
    return {section = value}
end

function actions.check(content)
    for _, place in ipairs(common.holders(content)) do
        local holder, where = place.holder, place.where
        if holder.move ~= nil then
            assert(type(holder.move.to) == "string", where .. " move needs a transition name")
            slots(holder.move.slots, where .. " move")
            assert(holder.move.snap == nil or type(holder.move.snap) == "boolean",
                where .. " move snap must be a boolean")
        end
        if holder.objects ~= nil then
            slots(holder.objects.slots, where .. " objects")
            assert(holder.objects.active == nil or type(holder.objects.active) == "boolean",
                where .. " objects active must be a boolean")
        end
        if holder.signal ~= nil then
            scene(holder.signal.scene, where .. " signal")
            local keys = holder.signal.keys
            assert(type(keys) == "table" and #keys > 0, where .. " signal needs keys")
            for number = 1, #keys do
                assert(math.type(keys[number]) == "integer" and keys[number] > 0,
                    where .. " signal key " .. number .. " must be a positive integer")
            end
        end
        if holder.stop ~= nil then
            assert(type(holder.stop) == "table" and #holder.stop > 0, where .. " stop needs scenes")
            for number = 1, #holder.stop do scene(holder.stop[number], where .. " stop") end
        end
        if holder.retire ~= nil then slots(holder.retire, where .. " retire") end
        if holder.interact ~= nil then
            slots(holder.interact.slots, where .. " interact")
            assert(holder.interact.active == nil or type(holder.interact.active) == "boolean",
                where .. " interact active must be a boolean")
            assert(holder.interact.used == nil or type(holder.interact.used) == "boolean",
                where .. " interact used must be a boolean")
        end
        if holder.perform ~= nil then
            slots(holder.perform.cells, where .. " perform")
            assert(type(holder.perform.sequence) == "string",
                where .. " perform needs a sequence symbol")
        end
        if holder.travel ~= nil then
            lib.one(holder.travel.cell, where .. " travel cell")
            lib.one(holder.travel.path, where .. " travel path")
            assert(holder.travel.spawn == nil or type(holder.travel.spawn) == "boolean",
                where .. " travel spawn must be a boolean")
        end
        if holder.effect ~= nil then
            lib.one(holder.effect.slot, where .. " effect slot")
            assert(holder.effect.enabled == nil or type(holder.effect.enabled) == "boolean",
                where .. " effect enabled must be a boolean")
            assert(holder.effect.arm == nil or type(holder.effect.arm) == "boolean",
                where .. " effect arm must be a boolean")
            if holder.effect.target ~= nil then lib.one(holder.effect.target, where .. " effect target") end
            if holder.effect.enabled ~= false then
                lib.one(holder.effect.filter, where .. " effect filter")
            end
        end
        if holder.toggle ~= nil then
            lib.one(holder.toggle.slot, where .. " toggle slot")
            assert(holder.toggle.state == nil or (math.type(holder.toggle.state) == "integer"
                and holder.toggle.state >= -1 and holder.toggle.state <= 2),
                where .. " toggle state must be an integer from -1 to 2")
            if holder.toggle.target ~= nil then lib.one(holder.toggle.target, where .. " toggle target") end
        end
        if holder.music ~= nil then
            lib.one(content.music_sensor, "music sensor")
            local music = music_of(holder.music)
            assert(math.type(music.section) == "integer" and music.section >= 0
                and music.section < MUSIC_SECTIONS,
                where .. " music section must be an integer below " .. MUSIC_SECTIONS)
            assert(music.enabled == nil or type(music.enabled) == "boolean",
                where .. " music enabled must be a boolean")
        end
    end
end

function actions.declare(content, builder)
    builder:action("move", function(context, _, _, move)
        local transition = context.sdk.device_transitions[move.to]
        for _, slot in ipairs(move.slots) do
            context:slot(slot):transition{transition = transition, snap = move.snap}
        end
    end)
    builder:action("objects", function(context, _, _, objects)
        context:activate_objects{slots = objects.slots, active = objects.active}
    end)
    builder:action("signal", function(context, _, _, signal)
        local target = context:scene(signal.scene.id)
        for _, key in ipairs(signal.keys) do target:send_event{key = key} end
    end)
    builder:action("stop", function(context, _, _, list)
        for _, target in ipairs(list) do context:scene(target.id):stop{} end
    end)
    -- Um esquadrão não possui uma chamada retire: reposicioná-lo com todas as quantidades zeradas remove seus integrantes.
    builder:action("retire", function(context, _, _, list)
        for _, id in ipairs(list) do
            local squad = context:squad(id)
            local counts = squad:counts()
            for lane = 1, counts.count do counts:set(lane, 0) end
            squad:place{counts = counts, mode = context.sdk.squad_modes.replace}
        end
    end)
    -- O registro de interação é enviado como usado por padrão, pois um registro ainda não usado exibe uma indicação genérica.
    -- `used = false` o envia como ainda não usado, para um objeto cuja interação pode ser repetida.
    builder:action("interact", function(context, _, _, interact)
        local active = interact.active ~= false
        local used = active and interact.used ~= false
        for _, slot in ipairs(interact.slots) do
            context:slot(slot):set_interactable_object{active = active, used = used}
        end
    end)
    -- A sequência é buscada pelo símbolo na tabela do próprio ator, sem precisar escrever sua chave diretamente.
    builder:action("perform", function(context, _, _, perform)
        for _, cell in ipairs(perform.cells) do
            local actor = context:slot(cell)
            local sequence = lib.one(actor:sequences()[perform.sequence],
                "actor sequence " .. perform.sequence)
            actor:run_atoms{spawn = true, atoms = {{kind = "sequence", value = sequence.key}}}
        end
    end)
    builder:action("travel", function(context, _, _, travel)
        context:slot(travel.cell):play_actor_path{
            path = context:slot(travel.path), spawn = travel.spawn ~= false}
    end)
    -- O filtro seleciona os jogadores; uma nova revisão reaplica o efeito, então cada chamada usa
    -- a revisão seguinte, armazenada por hop-on em uma variável da missão.
    builder:action("effect", function(context, state, _, effect)
        local key = content.key .. ".effect." .. effect.slot
        local revision = (state:variable(key) or 0) + 1
        context:set_variable(key, revision)
        local enabled = effect.enabled ~= false
        if enabled and effect.arm ~= false then
            if effect.target ~= nil then
                context:slot(effect.filter):set_object_filter{target = context:slot(effect.target)}
            else
                context:slot(effect.filter):set_object_filter{players = true}
            end
        end
        context:slot(effect.slot):set_mission_effect{
            filter = enabled and context:slot(effect.filter) or nil,
            enabled = enabled, revision = revision}
    end)
    builder:action("toggle", function(context, _, _, toggle)
        context:slot(toggle.slot):set_toggle{state = toggle.state or 1,
            target = toggle.target ~= nil and context:slot(toggle.target) or nil}
    end)
    builder:action("music", function(context, _, _, value)
        local music = music_of(value)
        context:slot(content.music_sensor):set_music_section{
            section = music.section, enabled = music.enabled}
    end)
end

return actions
