-- Checkpoints de Adieu. O reinicio nativo restaura o corpo; a campanha restaura o progresso.
local missions = require("missions")
local mission = require(missions.MISSION_JOURNEY)
local Slot = mission.Slot
local keys = require("mission_journey.checkpoint_keys")
local checkpoints = {}
local prefix = "journey.cp."
local definitions = {
    start = {region=24, spawn_set_hash=0x2EA8FB98, step="ghost", music=1,
        encounters={"city_ghosts", "climb", "guardians", "beasts"}},
    climb = {region=24, spawn_set_hash=0x777EB298, step="rally", music=2, area="climb",
        encounters={"climb", "guardians", "beasts"}},
    mountain = {region=24, spawn_set_hash=0xEDE37EC8, step="mountain", music=3, area="mountain",
        encounters={"beasts"}},
}

-- Associa a chegada futura a uma solicitacao de transicao especifica.
function checkpoints.select(context, id, state, options)
    assert(definitions[id], "unknown Adieu checkpoint")
    local request = context:select_state(state, options)
    context:set_variable(prefix .. "pending", id)
    context:set_variable(prefix .. "transition_request", request.value)
    context:clear_variable(prefix .. "transition_accepted")
    context:clear_variable(prefix .. "arrival_seen")
    return request
end

function checkpoints.install(program, config)
    local restore = assert(program.restore_checkpoint, "campaign has no checkpoint restore support")
    program.restore_checkpoint = nil
    local function busy(state) return state:variable(prefix .. "phase") ~= nil end
    local function active(state)
        return definitions[state:variable(prefix .. "current")]
    end
    -- O primeiro checkpoint existe desde o inicio, sem depender do evento entered.
    local function initialize(context, state)
        if state:variable(prefix .. "current") == nil then
            context:set_variable(prefix .. "current", "start")
        end
    end
    for _, name in ipairs({"on_start", "on_load"}) do
        local previous = program[name]
        program[name] = function(context, state, event)
            initialize(context, state)
            if previous then return previous(context, state, event) end
        end
    end

    local function confirm_arrival(context, state)
        local pending = state:variable(prefix .. "pending")
        if pending and state:variable(prefix .. "transition_accepted") == true
            and state:variable(prefix .. "arrival_seen") == true then
            context:set_variable(prefix .. "current", pending)
            context:clear_variable(prefix .. "pending")
            context:clear_variable(prefix .. "transition_request")
            context:clear_variable(prefix .. "transition_accepted")
            context:clear_variable(prefix .. "arrival_seen")
        end
    end
    local function resume(context, state)
        local checkpoint = assert(active(state), "missing Adieu checkpoint")
        -- A nova tentativa ja cancelou os timers nativos; rearma os controles Lua.
        for _, key in ipairs(keys) do context:clear_variable(key) end
        context:clear_variable(prefix .. "phase")
        context:clear_variable(prefix .. "request")
        context:clear_variable(prefix .. "release")
        context:clear_variable(prefix .. "pending")
        context:clear_variable(prefix .. "transition_request")
        context:clear_variable(prefix .. "transition_accepted")
        context:clear_variable(prefix .. "alive")
        for _, key in ipairs({"arrival_seen", "countdown_request", "return_request",
            "return_accepted", "return_arrived", "reset_request", "cleanup_request", "cleanup_cursor"}) do
            context:clear_variable(prefix .. key)
        end
        -- Nao permite que a cinematic de abertura seja carregada novamente.
        config.restore_local(context, state, checkpoint)
        restore(context, state, checkpoint)
    end

    -- Enquanto o cliente esta morto/carregando, nenhum evento avanca os encontros.
    -- Lista explicita: o ambiente restrito do Sunrise nao disponibiliza pairs.
    -- Vida da equipe, resultados e chegadas sao tratados separadamente abaixo.
    local callbacks = {
        "on_start", "on_load", "on_event_region_changed",
        "on_event_cinematic_started", "on_event_cinematic_terminated", "on_event_cinematic_skip_requested",
        "on_event_player_trigger", "on_event_trigger_entered",
        "on_event_scene_finished", "on_event_damage_state",
        "on_event_squad_state", "on_event_device_state",
        "on_event_object_interacted", "on_event_ghost_link_state",
        "on_event_object_state", "on_event_entity_died",
    }
    for _, name in ipairs(callbacks) do
        local callback = program[name]
        if type(callback) == "function" then
            local previous = callback
            program[name] = function(context, state, event)
                if busy(state) then return end
                return previous(context, state, event)
            end
        end
    end

    local previous_life = program.on_event_fireteam_state
    program.on_event_fireteam_state = function(context, state, event)
        if busy(state) then
            context:set_variable(prefix .. "alive", (event.alive_count or 0) > 0)
            return
        end
        local wiped = (event.dead_count or 0) > 0 and event.alive_count == 0
            and event.unknown_count == 0
        local checkpoint = active(state)
        if wiped and checkpoint and state:variable("journey.outro.index") == nil then
            -- Esta e a unica solicitacao de host deste callback.
            local request = context:restart_checkpoint {
                region=checkpoint.region, spawn_set_hash=checkpoint.spawn_set_hash,
            }
            context:set_variable(prefix .. "request", request.value)
            context:set_variable(prefix .. "phase", "requested")
            context:set_variable(prefix .. "alive", false)
            return
        end
        if previous_life then previous_life(context, state, event) end
    end

    -- A limpeza usa resultados de entrega, sem atrasos fixos. O retorno e a
    -- recriacao das cenas so comecam depois da ultima solicitacao aceita.
    local function prepare_return(context, state)
        local checkpoint = assert(active(state))
        if config.prepare_return then
            local reset = config.prepare_return(context, state, checkpoint)
            context:set_variable(prefix .. "reset_request", reset.value)
            context:set_variable(prefix .. "phase", "resetting")
        else
            local request = context:select_state({region_index=checkpoint.region}, {
                Slot.O_AUTO_RIFLE, spawn_set_hash=checkpoint.spawn_set_hash,
            })
            context:set_variable(prefix .. "return_request", request.value)
            context:clear_variable(prefix .. "return_accepted")
            context:clear_variable(prefix .. "return_arrived")
            context:set_variable(prefix .. "phase", "returning")
        end
    end
    local function cleanup_next(context, state)
        if config.reset_next then
            local request, cursor = config.reset_next(context, state,
                state:variable(prefix .. "cleanup_cursor") or 1)
            context:set_variable(prefix .. "cleanup_cursor", cursor)
            if request then
                context:set_variable(prefix .. "cleanup_request", request.value)
                context:set_variable(prefix .. "phase", "cleaning")
                return
            end
        end
        context:clear_variable(prefix .. "cleanup_request")
        prepare_return(context, state)
    end

    local previous_result = program.on_event_effect_result
    program.on_event_effect_result = function(context, state, event)
        local request = event.request_key and event.request_key.value
        if request and request == state:variable(prefix .. "transition_request") then
            if event.outcome == "transport_staged" then
                context:set_variable(prefix .. "transition_accepted", true)
                confirm_arrival(context, state)
            else
                context:clear_variable(prefix .. "pending")
                context:clear_variable(prefix .. "transition_request")
            end
        end
        if busy(state) then
            if request == state:variable(prefix .. "cleanup_request") and request ~= nil
                and state:variable(prefix .. "phase") == "cleaning" then
                if event.outcome ~= "transport_staged" then
                    context:set_variable(prefix .. "last_error", "falcon_cleanup_refused")
                    return
                end
                cleanup_next(context, state)
            elseif request == state:variable(prefix .. "request") and request ~= nil
                and state:variable(prefix .. "phase") == "requested" then
                if event.outcome ~= "transport_staged" then
                    context:set_variable(prefix .. "last_error", event.outcome or "refused")
                    context:clear_variable(prefix .. "phase")
                    context:clear_variable(prefix .. "request")
                    return
                end
                -- Publica a contagem somente depois de iniciar a nova tentativa.
                local countdown = context:slot(Slot.HARD_WIPE_GLOBALS):set_darkness_zone {
                    enabled=true, wipe_seconds=3,
                }
                context:set_variable(prefix .. "countdown_request", countdown.value)
                context:set_variable(prefix .. "phase", "countdown_pending")
            elseif request == state:variable(prefix .. "countdown_request") and request ~= nil
                and state:variable(prefix .. "phase") == "countdown_pending" then
                if event.outcome ~= "transport_staged" then
                    context:set_variable(prefix .. "last_error", "countdown_refused")
                    return
                end
                context:set_variable(prefix .. "phase", "countdown")
                context:start_timer("journey.cp.countdown", 3000)
            elseif request == state:variable(prefix .. "reset_request") and request ~= nil
                and state:variable(prefix .. "phase") == "resetting" then
                if event.outcome ~= "transport_staged" then
                    context:set_variable(prefix .. "last_error", "ship_reset_refused")
                    return
                end
                local checkpoint = assert(active(state))
                local returned = context:select_state({region_index=checkpoint.region}, {
                    Slot.O_AUTO_RIFLE, spawn_set_hash=checkpoint.spawn_set_hash,
                })
                context:set_variable(prefix .. "return_request", returned.value)
                context:clear_variable(prefix .. "return_accepted")
                context:clear_variable(prefix .. "return_arrived")
                context:set_variable(prefix .. "phase", "returning")
            elseif request == state:variable(prefix .. "return_request") and request ~= nil then
                if event.outcome ~= "transport_staged" then
                    context:set_variable(prefix .. "last_error", "return_refused")
                    return
                end
                context:set_variable(prefix .. "return_accepted", true)
                if state:variable(prefix .. "return_arrived") == true then resume(context, state) end
            elseif request == state:variable(prefix .. "release") and request ~= nil
                and state:variable(prefix .. "phase") == "releasing" then
                if event.outcome ~= "transport_staged" then
                    context:set_variable(prefix .. "last_error", "release_refused")
                    return
                end
                context:set_variable(prefix .. "phase", "respawning")
            end
            return
        end
        if previous_result then previous_result(context, state, event) end
    end

    local previous_timer = program.on_event_timer_elapsed
    program.on_event_timer_elapsed = function(context, state, event)
        if busy(state) then
            if event.timer_name == "journey.cp.countdown"
                and state:variable(prefix .. "phase") == "countdown" then
                local checkpoint = assert(active(state))
                local release = context:restart_checkpoint {
                    region=checkpoint.region, spawn_set_hash=checkpoint.spawn_set_hash,
                    release_request=state:variable(prefix .. "request"),
                }
                context:set_variable(prefix .. "release", release.value)
                context:set_variable(prefix .. "phase", "releasing")
            end
            return
        end
        if previous_timer then previous_timer(context, state, event) end
    end

    local previous_arrival = program.on_event_client_state_changed
    program.on_event_client_state_changed = function(context, state, event)
        if busy(state) then
            local phase = state:variable(prefix .. "phase")
            if phase == "respawning" and event.spawn_state == 0 then
                -- A tentativa anterior ainda pode ter atores e cenas no cliente.
                context:clear_variable(prefix .. "cleanup_cursor")
                cleanup_next(context, state)
            elseif phase == "returning" and event.entered == true
                and event.held_region_index == active(state).region then
                context:set_variable(prefix .. "return_arrived", true)
                if state:variable(prefix .. "return_accepted") == true then resume(context, state) end
            end
            return
        end
        if event.entered == true and event.held_region_index == 24
            and state:variable("journey.outro.index") == nil then
            -- Mantem a Treva ativa depois de cada carregamento da area jogavel.
            initialize(context, state)
            context:slot(Slot.HARD_WIPE_GLOBALS):set_darkness_zone {enabled=true}
        end
        if previous_arrival then previous_arrival(context, state, event) end
        if event.entered == true and event.held_region_index == 24 then
            local pending = state:variable(prefix .. "pending")
            if pending then
                context:set_variable(prefix .. "arrival_seen", true)
                confirm_arrival(context, state)
            elseif state:variable(prefix .. "current") == nil then
                context:set_variable(prefix .. "current", "start")
            end
        end
    end
    return program
end
return checkpoints
