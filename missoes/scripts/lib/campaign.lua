-- Sequência de etapas compartilhada pelos rascunhos das missões da campanha.
-- Uma etapa mostra seu objetivo quando a anterior termina. Ela termina pelo próprio gatilho, monitor, abate,
-- vínculo com o Fantasma, interação ou cena e, se nenhuma barreira impedir o avanço do jogador, pelo
-- gatilho ou monitor de qualquer etapa posterior.
local lib = require("lib.mission_lib")
local flow = require("lib.flow")

local campaign = {}

--- Identifica um esquadrão e o slot de tipo 1 que o contém.
--- @param squad Identificação gerada do esquadrão.
--- @param source Identificação gerada do slot do mesmo esquadrão.
--- @param group Grupo de tarefas extraído, opcional, para o objetivo do encontro.
function campaign.unit(squad, source, group)
    return {squad = lib.one(squad, "squad"), source = lib.one(source, "squad slot"), group = group}
end

--- Uma fala e o volume cuja entrada o cliente aguarda para reproduzi-la.
function campaign.line(cue, filter)
    return {cue = lib.one(cue, "dialogue cue"), filter = filter}
end

--- Uma semente do gerador que muda a cada tentativa e nunca chega a zero.
--- O ambiente restrito não tem fonte de aleatoriedade; o número da tentativa controlada pelo host é o único que varia.
--- @param context Contexto da função de retorno.
--- @return Um número inteiro positivo de 31 bits.
function campaign.run_seed(context)
    local attempt = tonumber(context.attempt_generation) or 1
    local seed = attempt % 0x7FFFFFFF
    if seed == 0 then return 1 end
    return seed
end

--- Move cada slot de dispositivo com uma transição.
function campaign.move(context, slots, transition)
    for _, slot in ipairs(slots) do
        context:slot(slot):transition{transition = context.sdk.device_transitions[transition]}
    end
end

-- Uma fala com filtro aguarda no cliente até o jogador entrar no volume do filtro.
local function say(content, context, line)
    context:slot(content.dialogue_sensor):play_dialogue_cue{
        cue = line.cue, filter = line.filter ~= nil and context:slot(line.filter) or nil,
    }
end

local function speak(content, context, holder)
    for _, line in ipairs(holder.lines or {}) do say(content, context, line) end
end

-- Atribua o objetivo antes de posicionar o esquadrão. Se seus dados mudarem depois que os membros existirem,
-- ele informa zero membros vivos por cerca de um segundo, e a coorte interpreta isso como eliminação completa.
local function populate(content, context, encounter)
    for _, unit in ipairs(encounter.squads or {}) do
        if encounter.objective ~= nil then
            context:slot(unit.source):assign_combat_objective{
                objective = context:slot(encounter.objective), task_group = unit.group,
            }
        end
        context:squad(unit.squad):place{}
    end
    speak(content, context, encounter)
    if encounter.on_start ~= nil then encounter.on_start(context) end
end

local function list(value)
    if value == nil then return {} end
    if type(value) == "table" then return value end
    return {value}
end

-- Um objetivo sem ponto de navegação mantém o texto, mas não mostra marcador. Dentro do volume do ponto,
-- o marcador fica oculto. Reenviar o mesmo objetivo move o marcador sem exibir uma notificação.
local function show(content, context, step)
    context:slot(content.directive_sensor):set_directive{
        directive = step.directive,
        navpoint = step.navpoint ~= nil and context:slot(step.navpoint) or nil,
        waypoint = step.waypoint ~= nil and context:slot(step.waypoint) or nil,
    }
end

-- Um gatilho armado informa sua ativação a cada atualização enquanto o jogador permanece dentro; por isso, o primeiro informe
-- o desarma. A variável garante um único desarme mesmo quando vários informes chegam em sequência.
local function armed_key(id)
    return "armed/" .. id
end

local function arm_trigger(context, id)
    context:set_variable(armed_key(id), true)
    context:slot(id):fire_trigger()
end

-- Um monitor de tipo 30 informa a entrada por conta própria e não precisa ser desarmado. Basta um jogador.
local function watch_monitor(context, id)
    context:slot(id):set_occupancy_condition{value = 1}
end

local function disarm_reported(context, state, event)
    local id = event.slot ~= nil and event.slot.id or nil
    if id ~= nil and state:variable(armed_key(id)) == true then
        context:clear_variable(armed_key(id))
        context:slot(id):disarm_trigger()
    end
end

-- O vínculo e o registro de interação registram seus objetos antes do objetivo. Um registro ainda não
-- utilizado mostra uma instrução genérica; sem esse registro, o cliente nunca informa o uso.
local function begin(content, step)
    return function(context)
        local ends = step.ends or {}
        if ends.ghost_link ~= nil then
            context:slot(ends.ghost_link):set_ghost_link{active = true}
        end
        local interact = ends.interact
        if ends.collect ~= nil then
            interact = ends.collect.slot
        end
        if interact ~= nil then
            context:slot(interact):set_interactable_object{used = false}
        end
        if step.scene ~= nil then context:scene(step.scene):activate{} end
        if step.directive ~= nil then show(content, context, step) end
        speak(content, context, step)
        -- Armar novamente faz o gatilho informar a presença de um jogador que já está dentro do volume.
        if step.revisit then
            for _, trigger in ipairs(list(ends.trigger)) do arm_trigger(context, trigger) end
        end
        if step.on_start ~= nil then step.on_start(context) end
    end
end

local SLOT_PREFIX = "slot/"

-- O identificador de um slot segue slot/<tag do objeto>/...; o marcador exige que seu objeto esteja registrado no cliente.
local function object_of(slot)
    if string.sub(slot, 1, #SLOT_PREFIX) ~= SLOT_PREFIX then return nil end
    return string.sub(slot, #SLOT_PREFIX + 1, #SLOT_PREFIX + 8)
end

-- Um grupo de fluxo comporta até 64 condições; repetir um fato não acrescenta outra condição.
local GROUP = 64

local function any_of(options)
    local seen, unique = {}, {}
    for _, option in ipairs(options) do
        local key = type(option) == "table" and option.fact or nil
        if key == nil or not seen[key] then
            if key ~= nil then seen[key] = true end
            unique[#unique + 1] = option
        end
    end
    while #unique > GROUP do
        local folded = {}
        for start = 1, #unique, GROUP do
            local part = {}
            for index = start, math.min(start + GROUP - 1, #unique) do
                part[#part + 1] = unique[index]
            end
            folded[#folded + 1] = {any = part}
        end
        unique = folded
    end
    if #unique == 0 then return nil end
    return {any = unique}
end

local function check(content)
    lib.one(content.key, "campaign key")
    lib.one(content.directive_sensor, "directive sensor")
    assert(#lib.one(content.legs, "campaign legs") > 0, "a campaign needs a leg")
    assert(#lib.one(content.steps, "campaign steps") > 0, "a campaign needs a step")
    local armed, watched = {}, {}
    for _, leg in ipairs(content.legs) do
        lib.one(leg.state, lib.one(leg.id, "leg id") .. " state")
        for _, trigger in ipairs(leg.arm or {}) do armed[trigger] = leg.id end
        for _, monitor in ipairs(leg.watch or {}) do watched[monitor] = leg.id end
    end
    for _, step in ipairs(content.steps) do
        lib.one(step.id, "step id")
        if step.lines ~= nil then lib.one(content.dialogue_sensor, "dialogue sensor") end
        for _, trigger in ipairs(list((step.ends or {}).trigger)) do
            assert(armed[trigger], step.id .. " ends on a trigger no leg arms")
        end
        for _, monitor in ipairs(list((step.ends or {}).monitor)) do
            assert(watched[monitor], step.id .. " ends on a monitor no leg watches")
        end
        local collect = (step.ends or {}).collect
        if collect ~= nil then
            lib.one(collect.slot, step.id .. " collection slot")
            assert(type(collect.definition_hash) == "number"
                and collect.definition_hash > 0
                and collect.definition_hash <= 0xFFFFFFFF
                and collect.definition_hash % 1 == 0,
                step.id .. " collection definition_hash must be a positive u32")
            assert(collect.on_success == nil or type(collect.on_success) == "function",
                step.id .. " collection on_success must be a function")
        end
        local hurt = (step.ends or {}).health
        if hurt ~= nil then
            lib.one(hurt.slot, step.id .. " health slot")
            assert(type(hurt.at) == "number" and hurt.at >= 0 and hurt.at <= 1,
                step.id .. " health fraction must be between zero and one")
        end
    end
    for index, cut in ipairs(content.intro or {}) do
        lib.one(cut.state, "intro " .. index .. " state")
        lib.one(cut.cinematic, "intro " .. index .. " cinematic")
    end
    local step_ids = {arrival = true}
    for _, step in ipairs(content.steps) do step_ids[step.id] = true end
    for _, encounter in ipairs(content.encounters or {}) do
        lib.one(encounter.id, "encounter id")
        assert(step_ids[encounter.after or "arrival"], encounter.id .. " waits on an unknown step")
        if encounter.trigger ~= nil then
            assert(armed[encounter.trigger], encounter.id .. " waits on a trigger no leg arms")
        end
        if encounter.monitor ~= nil then
            assert(watched[encounter.monitor], encounter.id .. " waits on a monitor no leg watches")
        end
    end
end

--- Monta a tabela da missão a partir de uma declaração de conteúdo.
--- @param content Tabela com key, sensors, legs e suas listas de gatilhos e monitores, steps e
--- encounters,
--- uma lista intro opcional de cenas {state, cinematic} reproduzidas antes do primeiro trecho e um
--- spawn_set opcional que identifica os pontos de chegada usados pelo cliente para filtrar o surgimento do jogador.
--- @return A tabela carregada pelo ambiente de execução: initial_state, on_start, on_load e os tratadores de eventos.
function campaign.new(content)
    check(content)
    local legs, steps = content.legs, content.steps
    local first = legs[1]
    local intro = content.intro or {}
    local outro = content.outro or {}
    -- O encerramento aguarda cada estado e o término da cinematic correspondente.
    local function start_outro(context, state, region)
        if content.native_outro then return end
        local index = state:variable(content.key .. ".outro.index")
        local cut = index and outro[index]
        if content.outro_confirm_arrival then
            if not cut or cut.state.region_index ~= region then return end
            context:set_variable(content.key .. ".outro.arrived_index", index)
            if state:variable(content.key .. ".outro.accepted_index") ~= index then return end
        end
        if cut and cut.state.region_index == region
            and state:variable(content.key .. ".outro.playing") ~= true
            and state:variable(content.key .. ".outro.requested") ~= true then
            if content.outro_confirm_started then
                context:set_variable(content.key .. ".outro.requested", true)
                local request = context:slot(cut.cinematic):set_cinematic_active{active = true}
                context:set_variable(content.key .. ".outro.cinematic_request", request.value)
            else
                context:set_variable(content.key .. ".outro.playing", true)
                context:slot(cut.cinematic):set_cinematic_active{active = true}
            end
        end
    end
    -- Guarda a solicitacao exata; o resultado confirma que o host selecionou o estado.
    local function select_outro(context, index)
        local cut = outro[index]
        if content.outro_confirm_arrival then
            -- Uma resposta atrasada do video anterior nao libera o proximo.
            for _, suffix in ipairs({"arrived_index", "accepted_index", "requested",
                "transport_staged", "cinematic_request", "last_error"}) do
                context:clear_variable(content.key .. ".outro." .. suffix)
            end
        end
        -- Uma cinematic usa sua chegada propria, sem herdar o ponto jogavel do checkpoint.
        local options = cut.spawn_set_hash and {spawn_set_hash=cut.spawn_set_hash} or nil
        local request = context:select_state(cut.state, options)
        context:set_variable(content.key .. ".outro.state_request", request.value)
    end
    local function accept_outro_state(context, state, event)
        if content.native_outro then
            local key=state:variable(content.key .. ".outro.native_request")
            if key and event.request_key and event.request_key.value==key then
                context:clear_variable(content.key .. ".outro.native_request")
                if event.outcome~="transport_staged" then
                    context:set_variable(content.key .. ".outro.last_error", event.outcome or "refused")
                end
            end
            return
        end
        local activation = state:variable(content.key .. ".outro.cinematic_request")
        if activation ~= nil and event.request_key ~= nil
            and event.request_key.value == activation then
            context:clear_variable(content.key .. ".outro.cinematic_request")
            if event.outcome ~= "transport_staged" then
                context:set_variable(content.key .. ".outro.last_error", event.outcome or "refused")
                context:clear_variable(content.key .. ".outro.requested")
            else
                context:set_variable(content.key .. ".outro.transport_staged", true)
            end
            return
        end
        local request = state:variable(content.key .. ".outro.state_request")
        if request == nil or event.request_key == nil
            or event.request_key.value ~= request then return end
        context:clear_variable(content.key .. ".outro.state_request")
        if event.outcome ~= "transport_staged" then
            context:set_variable(content.key .. ".outro.last_error", event.outcome or "refused")
            return
        end
        local index = state:variable(content.key .. ".outro.index")
        local cut = index and outro[index]
        if cut then
            if content.outro_confirm_arrival then
                context:set_variable(content.key .. ".outro.accepted_index", index)
                -- Entrega ao host nao confirma que o cliente carregou a regiao.
                if state:variable(content.key .. ".outro.arrived_index") == index then
                    start_outro(context, state, cut.state.region_index)
                end
                return
            end
            -- Uma regiao somente de cinematic pode nao emitir entered antes de reproduzir.
            -- Usa a confirmacao do host, mantendo a protecao contra ativacao duplicada.
            start_outro(context, state, cut.state.region_index)
        end
    end
    local function end_outro(context, state, event)
        local index = state:variable(content.key .. ".outro.index")
        local cut = index and outro[index]
        if not cut or state:variable(content.key .. ".outro.playing") ~= true
            or not lib.is_slot(context, event, cut.cinematic) then return end
        context:slot(cut.cinematic):set_cinematic_active{active = false}
        context:set_variable(content.key .. ".outro.playing", false)
        context:clear_variable(content.key .. ".outro.transport_staged")
        context:clear_variable(content.key .. ".outro.cinematic_request")
        context:set_variable(content.key .. ".outro.index", index + 1)
        if outro[index + 1] then
            select_outro(context, index + 1)
        else
            -- Só conclui a missão depois da última cinematic terminar ou ser pulada.
            context:hold_spawn{active = false}
            context:complete_mission{}
        end
    end
    local facts, trigger_fact, graph = {}, {}, nil

    -- Cada cena de abertura é executada em seu próprio estado, na ordem da lista, antes do primeiro trecho.
    local PLAYING, ENDED = 1, 2
    local function intro_key(index)
        return content.key .. ".intro." .. index
    end
    local function intro_done(state)
        return #intro == 0 or state:variable(intro_key(#intro)) == ENDED
    end

    -- O cliente faz o jogador surgir ao receber a resposta de chegada. O informe do trecho da região e os informes vazios chegam
    -- enquanto ele ainda está carregando. Uma mudança após uma cena pode não voltar a bloquear o surgimento; nesse caso,
    -- o informe da região também conta.
    facts[#facts + 1] = {id = "arrival", observe = function(_, state, event)
        local region = first.state.region_index
        if event.entered == true and event.held_region_index == region then return true end
        return #intro > 0 and intro_done(state) and event.region_index == region
    end}
    for _, leg in ipairs(legs) do
        local region = leg.state.region_index
        facts[#facts + 1] = {id = "leg." .. leg.id, observe = function(_, _, event)
            return event.region_index == region
                or (event.entered == true and event.held_region_index == region)
        end}
    end
    local function watch(trigger)
        if trigger_fact[trigger] == nil then
            local id = "t" .. (#facts + 1)
            trigger_fact[trigger] = id
            facts[#facts + 1] = {id = id, observe = function(context, _, event)
                return lib.is_slot(context, event, trigger)
            end}
        end
        return flow.fact(trigger_fact[trigger])
    end
    -- Um volume revisitado já foi atravessado antes; seu informe só conta quando a etapa está ativa.
    local function fresh(step, number)
        return flow.fact(step.id .. ".t" .. number)
    end
    for _, step in ipairs(steps) do
        local ends = step.ends or {}
        for number, trigger in ipairs(list(ends.trigger)) do
            if step.revisit then
                facts[#facts + 1] = {id = step.id .. ".t" .. number,
                    observe = function(context, state, event)
                        return graph:started(context, state, step.id)
                            and lib.is_slot(context, event, trigger)
                    end}
            else
                watch(trigger)
            end
        end
        for _, monitor in ipairs(list(ends.monitor)) do watch(monitor) end
        if ends.ghost_link ~= nil then
            local link, started = ends.ghost_link, step.id .. ".scan"
            facts[#facts + 1] = {id = started, observe = function(context, state, event)
                return graph:started(context, state, step.id) and lib.is_slot(context, event, link)
                    and event.active == true and (event.progress or 0) > 0
            end}
            facts[#facts + 1] = {id = step.id .. ".scanned",
                observe = function(context, state, event)
                    return graph:fact(context, state, started)
                        and lib.is_slot(context, event, link) and event.active == false
                end}
        end
        for number, object in ipairs(ends.destroyed or {}) do
            facts[#facts + 1] = {id = step.id .. ".gone" .. number,
                observe = function(context, state, event)
                    return graph:started(context, state, step.id)
                        and lib.is_slot(context, event, object) and event.present == false
                end}
        end
        if ends.interact ~= nil then
            local object = ends.interact
            facts[#facts + 1] = {id = step.id .. ".used", observe = function(context, state, event)
                return graph:started(context, state, step.id)
                    and lib.is_slot(context, event, object)
            end}
        end
        if ends.collect ~= nil then
            local request_key = content.key .. ".collect." .. step.id .. ".request"
            facts[#facts + 1] = {
                id = step.id .. ".collected",
                observe = function(context, state, event)
                    local request = state:variable(request_key)
                    return graph:started(context, state, step.id)
                        and request ~= nil and event.request_key ~= nil
                        and event.request_key.value == request
                        and event.effect == "inventory.collect_weapon"
                        and event.outcome == "transport_staged"
                end,
            }
        end
        -- O Sense de tipo 2 contém a vida do combatente como uma fração; assim, a condição de passagem de fase dispensa uma
        -- leitura direta do cliente. Um valor de vida desconhecido é informado abaixo de zero e nunca encerra uma etapa.
        if ends.health ~= nil then
            local target, at = ends.health.slot, ends.health.at
            facts[#facts + 1] = {id = step.id .. ".hurt", observe = function(context, state, event)
                return graph:started(context, state, step.id)
                    and lib.is_slot(context, event, target)
                    and type(event.health) == "number" and event.health >= 0
                    and event.health <= at
            end}
        end
        -- Uma cena pode já ter sido reproduzida; só conta um informe recebido após o início de sua etapa.
        if ends.scene ~= nil then
            local scene = ends.scene
            facts[#facts + 1] = {id = step.id .. ".played",
                observe = function(context, state, event)
                return graph:started(context, state, step.id)
                    and lib.is_slot(context, event, scene)
            end}
        end
    end
    -- Os encontros ficam em um segundo grafo para que cada grafo respeite os limites de etapas e fatos.
    local encounter_facts, encounter_fact, encounter_graph = {}, {}, nil
    for _, encounter in ipairs(content.encounters or {}) do
        local source = encounter.trigger or encounter.monitor
        if source ~= nil and encounter_fact[source] == nil then
            local id = "t" .. (#encounter_facts + 1)
            encounter_fact[source] = id
            encounter_facts[#encounter_facts + 1] = {id = id, observe = function(context, _, event)
                return lib.is_slot(context, event, source)
            end}
        end
    end

    local placed = {}
    for _, encounter in ipairs(content.encounters or {}) do placed[encounter.id] = encounter end
    local function cleared(ids)
        local squads = {}
        for _, id in ipairs(ids) do
            for _, unit in ipairs(lib.one(placed[id], "encounter " .. id).squads) do
                squads[#squads + 1] = unit.squad
            end
        end
        return function(context) return context:cohort{squads = squads}.cleared end
    end

    local function own_end(step)
        local ends, options = step.ends or {}, {}
        for number, trigger in ipairs(list(ends.trigger)) do
            options[#options + 1] = step.revisit and fresh(step, number) or watch(trigger)
        end
        for _, monitor in ipairs(list(ends.monitor)) do options[#options + 1] = watch(monitor) end
        if ends.region ~= nil then options[#options + 1] = flow.fact("leg." .. ends.region) end
        if ends.clear ~= nil then options[#options + 1] = cleared(list(ends.clear)) end
        if ends.ghost_link ~= nil then options[#options + 1] = flow.fact(step.id .. ".scanned") end
        if ends.interact ~= nil then options[#options + 1] = flow.fact(step.id .. ".used") end
        if ends.collect ~= nil then options[#options + 1] = flow.fact(step.id .. ".collected") end
        if ends.scene ~= nil then options[#options + 1] = flow.fact(step.id .. ".played") end
        if ends.health ~= nil then options[#options + 1] = flow.fact(step.id .. ".hurt") end
        if ends.destroyed ~= nil then
            local all = {}
            for number = 1, #ends.destroyed do
                all[number] = flow.fact(step.id .. ".gone" .. number)
            end
            options[#options + 1] = {all = all}
        end
        return options
    end

    local chain = {{id = "arrival", await = flow.fact("arrival")}}
    local previous = "arrival"
    for index, step in ipairs(steps) do
        local options = own_end(step)
        if not step.barrier then
            for later = index + 1, #steps do
                local ends = steps[later].ends or {}
                for _, trigger in ipairs(steps[later].revisit and {} or list(ends.trigger)) do
                    options[#options + 1] = watch(trigger)
                end
                for _, monitor in ipairs(list(ends.monitor)) do
                    options[#options + 1] = watch(monitor)
                end
                if ends.region ~= nil then
                    options[#options + 1] = flow.fact("leg." .. ends.region)
                end
            end
        end
        -- Uma etapa sem condição de término termina imediatamente; a próxima começa junto com ela.
        local await = any_of(options)
        chain[#chain + 1] = {id = step.id, after = {previous}, run = begin(content, step),
            await = await}
        previous = step.id
    end
    -- Os fatos de gatilhos ficam registrados; se um gatilho disparar antes da hora, o encontro será posicionado quando sua etapa começar.
    local placements = {}
    for _, encounter in ipairs(content.encounters or {}) do
        local after = encounter.after or "arrival"
        local source = encounter.trigger or encounter.monitor
        -- A etapa de chegada aguarda desde o início; por isso, a chegada precisa realmente ter ocorrido.
        local function begun(context, state)
            if after == "arrival" then return graph:fact(context, state, "arrival") end
            return graph:started(context, state, after)
        end
        local when = function(context, state)
            return begun(context, state) and (source == nil
                or encounter_graph:fact(context, state, encounter_fact[source]))
        end
        placements[#placements + 1] = {id = encounter.id, when = when, run = function(context)
            populate(content, context, encounter)
        end}
    end
    -- A missão concluída não mostra objetivo nem marcador no mapa.
    chain[#chain + 1] = {id = "done", after = {previous}, run = function(context, state)
        if content.finish ~= nil then content.finish(context) end
        context:slot(content.directive_sensor):clear_directives()
        if content.native_outro then
            context:set_variable(content.key .. ".outro.index", 1)
            context:set_variable(content.key .. ".outro.native_requested", true)
            local request=context:begin_adieu_ending{}
            context:set_variable(content.key .. ".outro.native_request", request.value)
        elseif #outro > 0 then
            context:set_variable(content.key .. ".outro.index", 1)
            context:set_variable(content.key .. ".outro.playing", false)
            context:hold_spawn{active = true}
            select_outro(context, 1)
        else
            context:complete_mission{}
        end
    end}

    graph = flow.new{key = content.key, facts = facts, steps = chain}
    if #placements > 0 then
        encounter_graph = flow.new{key = content.key .. ".enc", facts = encounter_facts,
            steps = placements}
    end

    -- Um gatilho só envia informes depois que o host o arma; armar também registra seu objeto. Por isso, cada
    -- trecho arma seus gatilhos quando o jogador chega até ele.
    local function arm(context, region)
        local objects = {}
        for _, leg in ipairs(legs) do
            if leg.state.region_index == region then
                for _, trigger in ipairs(leg.arm or {}) do
                    arm_trigger(context, trigger)
                    objects[object_of(trigger) or trigger] = true
                end
                for _, monitor in ipairs(leg.watch or {}) do
                    watch_monitor(context, monitor)
                    objects[object_of(monitor) or monitor] = true
                end
            end
        end
        return objects
    end
    local function active(context, state)
        for index, step in ipairs(steps) do
            local following = steps[index + 1] ~= nil and steps[index + 1].id or "done"
            if graph:started(context, state, step.id)
                and not graph:started(context, state, following) then
                return step
            end
        end
        return nil
    end
    -- O grafo de etapas é processado primeiro; o posicionamento consulta quais etapas já começaram.
    local function handle(context, state, event, interaction_completed)
        local completed_collections = {}
        for index, step in ipairs(steps) do
            local collect = (step.ends or {}).collect
            if collect ~= nil then
                local request_key = content.key .. ".collect." .. step.id .. ".request"
                local pending = state:variable(request_key)
                if pending ~= nil and event.request_key ~= nil
                    and event.request_key.value == pending
                    and event.effect == "inventory.collect_weapon" then
                    if event.outcome == "transport_staged" then
                        completed_collections[#completed_collections + 1] = request_key
                        if collect.on_success ~= nil then
                            collect.on_success(context, state, event)
                        end
                    else
                        context:clear_variable(request_key)
                    end
                end

                local next_step = steps[index + 1]
                local step_is_current = graph:started(context, state, step.id)
                    and (next_step == nil or not graph:started(context, state, next_step.id))
                -- Mudanças de estado do objeto não devem entregar a arma.
                -- A coleta só começa quando recebemos a interação concluída.
                if interaction_completed == true
                    and step_is_current
                    and pending == nil
                    and lib.is_slot(context, event, collect.slot) then
                    local request = context:collect_weapon {
                        slot = collect.slot,
                        definition_hash = collect.definition_hash,
                    }
                    context:set_variable(request_key, request.value)
                end
            end
        end
        graph:handle(context, state, event)
        if encounter_graph ~= nil then encounter_graph:handle(context, state, event) end
        for _, request_key in ipairs(completed_collections) do
            context:clear_variable(request_key)
        end
    end
    local function advance(context, state)
        graph:advance(context, state)
        if encounter_graph ~= nil then encounter_graph:advance(context, state) end
    end
    -- Um objetivo enviado antes do registro do objeto de seu marcador fica sem marcador. Por isso, o objetivo ainda
    -- exibido é reenviado quando a nova região registra esse objeto.
    local function enter(context, state, event, region)
        local before = active(context, state)
        local objects = arm(context, region)
        handle(context, state, event)
        if before == nil or before.directive == nil or active(context, state) ~= before then
            return
        end
        local marker = before.navpoint or before.waypoint
        if marker ~= nil and objects[object_of(marker)] then show(content, context, before) end
    end
    -- Um objeto interativo surge com a configuração inicial de seu grupo; por isso, é omitido até que sua etapa envie o registro correspondente.
    local omit = {}
    for _, id in ipairs(content.omit or {}) do omit[#omit + 1] = id end
    for _, step in ipairs(steps) do
        local ends = step.ends or {}
        local object = ends.interact
        if ends.collect ~= nil then object = ends.collect.slot end
        if object ~= nil then omit[#omit + 1] = object end
    end
    -- O cliente mantém a região da cena; portanto, só falta solicitar seu início.
    local function start_intro(context, state, region)
        for index, cut in ipairs(intro) do
            if cut.state.region_index == region and state:variable(intro_key(index)) == nil then
                context:set_variable(intro_key(index), PLAYING)
                context:slot(cut.cinematic):set_cinematic_active{active = true}
            end
        end
    end
    -- O cliente posiciona o jogador na última posição de seu corpo; assim, um corpo criado na região de uma cena
    -- acaba dentro da geometria do primeiro trecho. Bloquear o surgimento até o fim da última cena garante
    -- que não haja corpo para reposicionar; a chegada escolhe seu próprio ponto, como no início da missão.
    local function select_after(context, index)
        if index < #intro then
            context:select_state(intro[index + 1].state)
        else
            context:select_state(first.state, omit)
            context:hold_spawn{active = false}
        end
    end
    local function end_intro(context, state, index)
        if state:variable(intro_key(index)) == ENDED then return end
        context:set_variable(intro_key(index), ENDED)
        -- Interrompa a cena antes da mudança de estado; caso contrário, o componente reconstruído a reproduzirá novamente.
        context:slot(intro[index].cinematic):set_cinematic_active{active = false}
        select_after(context, index)
    end

    -- Encerra a cena em reprodução identificada pelo slot informado.
    local function end_reported_intro(context, state, event)
        for index, cut in ipairs(intro) do
            if state:variable(intro_key(index)) == PLAYING
                and lib.is_slot(context, event, cut.cinematic) then
                end_intro(context, state, index)
            end
        end
    end

    return {
        -- Usado somente pelo controlador de checkpoints que envolve esta campanha.
        restore_checkpoint = content.checkpoint_support and function(context, state, checkpoint)
            graph:resume_from(context, state, checkpoint.step)
            graph:seed_fact(context, "arrival")
            if encounter_graph then
                encounter_graph:resume_encounters(context, state, checkpoint.encounters)
            end
            for _, step in ipairs(steps) do
                context:clear_variable(content.key .. ".collect." .. step.id .. ".request")
            end
            arm(context, checkpoint.region)
            advance(context, state)
        end or nil,
        initial_state = {
            region_index = (#intro > 0 and intro[1].state or first.state).region_index,
            spawn_set_hash = content.spawn_set,
            omit = omit,
        },
        on_start = function(context, state)
            if #intro > 0 then context:hold_spawn{active = true} end
            advance(context, state)
        end,
        -- Uma reconexão do script ocorre com o jogador no mundo; uma cena ainda marcada como em reprodução é encerrada, sem ser repetida.
        on_load = function(context, state)
            for index in ipairs(intro) do
                if state:variable(intro_key(index)) == PLAYING then
                    end_intro(context, state, index)
                end
            end
            if #intro > 0 and intro_done(state) and not graph:fact(context, state, "arrival") then
                context:select_state(first.state, omit)
            end
            advance(context, state)
        end,
        on_event_region_changed = function(context, state, event)
            -- No modo confirmado, somente entered/current do cliente autoriza o video.
            if not content.outro_confirm_arrival then
                start_outro(context, state, event.region_index)
            end
            start_intro(context, state, event.region_index)
            enter(context, state, event, event.region_index)
        end,
        -- Somente a resposta de chegada alimenta o grafo. Um informe de trecho pendente identifica uma região que o
        -- cliente ainda não carregou.
        on_event_client_state_changed = function(context, state, event)
            -- current_region_index e a confirmacao nativa da regiao carregada.
            -- entered e publicado por outro caminho e pode nao acompanhar esse informe.
            if content.outro_confirm_arrival and event.current_region_index ~= nil then
                start_outro(context, state, event.current_region_index)
            end
            if event.entered == true then
                if not content.outro_confirm_arrival then
                    start_outro(context, state, event.held_region_index)
                end
                start_intro(context, state, event.held_region_index)
                enter(context, state, event, event.held_region_index)
            end
        end,
        -- O término e a recusa de início chegam aqui; a solicitação para pular tem seu próprio tipo de evento. Ambos encerram a
        -- cena; caso contrário, uma introdução pulada nunca libera o surgimento bloqueado do jogador.
        on_event_cinematic_started = function(context, state, event)
            if content.native_outro
                and state:variable(content.key .. ".outro.native_requested") == true then
                for index, cut in ipairs(outro) do
                    if lib.is_slot(context,event,cut.cinematic) then
                        context:set_variable(content.key .. ".outro.index",index)
                        context:set_variable(content.key .. ".outro.native_started",index)
                    end
                end
                return
            end
            if not content.outro_confirm_started then return end
            local index = state:variable(content.key .. ".outro.index")
            local cut = index and outro[index]
            if cut and state:variable(content.key .. ".outro.requested") == true
                and lib.is_slot(context, event, cut.cinematic) then
                context:set_variable(content.key .. ".outro.playing", true)
                context:clear_variable(content.key .. ".outro.requested")
                context:clear_variable(content.key .. ".outro.last_error")
            end
        end,
        on_event_cinematic_terminated = function(context, state, event)
            if content.native_outro
                and state:variable(content.key .. ".outro.native_requested") == true then
                local last=outro[#outro]
                if last and state:variable(content.key .. ".outro.native_started")==#outro
                    and state:variable(content.key .. ".outro.native_completed")~=true
                    and lib.is_slot(context,event,last.cinematic) then
                    context:set_variable(content.key .. ".outro.native_completed",true)
                    context:hold_spawn{active=false}
                    context:complete_mission{}
                end
                return
            end
            end_outro(context, state, event)
            end_reported_intro(context, state, event)
        end,
        on_event_cinematic_skip_requested = function(context, state, event)
            if content.native_outro
                and state:variable(content.key .. ".outro.native_requested") == true then return end
            -- Pedir para pular nao e a confirmacao de termino do video.
            if not content.outro_wait_terminated then
                end_outro(context, state, event)
            end
            end_reported_intro(context, state, event)
        end,
        on_event_player_trigger = function(context, state, event)
            disarm_reported(context, state, event)
            handle(context, state, event)
        end,
        -- Um monitor acompanhado envia seus informes aqui, e não pelo evento de gatilho do jogador.
        on_event_trigger_entered = handle,
        on_event_scene_finished = handle,
        on_event_damage_state = handle,
        on_event_squad_state = handle,
        on_event_device_state = handle,
        on_event_object_interacted = function(context, state, event) handle(context, state, event, true)
        end,
        on_event_effect_result = function(context, state, event)
            accept_outro_state(context, state, event)
            handle(context, state, event)
        end,
        on_event_ghost_link_state = handle,
        on_event_object_state = handle,
    }
end

return campaign
  
