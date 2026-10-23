-- Executa o script real com substitutos locais para o SDK, sem abrir o jogo.
local state_data, actions = {}, {}
local video = {id = "slot/video"}
local movie_state, arrival_state = {region_index = 1}, {region_index = 0}
package.preload["missions.cine_farm_325_80b84a1c"] = function()
    return {Slot = {PF_CINEMATIC_BOOKEND_CINEMATIC = video}, states = {
        STATE_80B84A1C_0000_0001_80B84A1B = movie_state,
        STATE_80B84A1C_0000_0000_80B84A1A = arrival_state,
    }}
end
package.preload["lib.mission_lib"] = function()
    return {is_slot = function(context, event, slot) return event.slot and event.slot.id == context:slot(slot).id end}
end
local context = {}
function context:set_variable(k,v) state_data[k] = v end
function context:hold_spawn(v) actions.hold = v.active end
function context:complete_mission() actions.complete = (actions.complete or 0) + 1 end
function context:select_state(v) actions.region = v.region_index end
function context:slot(v)
    return {id = v.id, set_cinematic_active = function(_,p)
        if p.active then actions.play = (actions.play or 0) + 1 else actions.stop = (actions.stop or 0) + 1 end
    end}
end
local state = {variable = function(_,k) return state_data[k] end}
local script = dofile(arg[1])
local event = {slot = video}
script.on_start(context, state)
assert(actions.hold and script.initial_state.region_index == 1)
script.on_event_client_state_changed(context, state, {held_region_index = 1})
assert(actions.play == nil) -- informe pendente nao inicia
script.on_event_client_state_changed(context, state, {current_region_index = 1})
assert(actions.play == 1)
script.on_event_cinematic_terminated(context, state, event)
assert(actions.stop == nil and actions.complete == nil) -- inicio recusado nao conclui
script.on_event_cinematic_started(context, state, event)
script.on_load(context, state)
script.on_event_client_state_changed(context, state, {current_region_index = 1})
assert(actions.play == 1) -- recarga e informe duplicado nao repetem
script.on_event_cinematic_skip_requested(context, state, event)
assert(actions.stop == nil)
script.on_event_cinematic_terminated(context, state, event)
assert(actions.stop == 1 and actions.region == 0 and actions.hold)
script.on_event_cinematic_terminated(context, state, event)
assert(actions.stop == 1)
script.on_event_client_state_changed(context, state, {current_region_index = 0})
assert(actions.complete == 1 and actions.hold == false)
script.on_event_client_state_changed(context, state, {current_region_index = 0})
script.on_load(context, state)
assert(actions.complete == 1 and actions.play == 1 and actions.hold == false)
print('OK: chegada confirmada, inicio/fim, duplicatas, recarga, salto e conclusao unica.')
