-- Ciclo dos falcões de Adieu, seguindo as condições do controlador do Dawn.
local missions = require("missions")
local mission = require(missions.MISSION_JOURNEY)
local Slot = mission.Slot
local lib = require("lib.mission_lib")
local falcons = {}
local prefix = "journey.dawn_falcons."
local definitions = {
    {id="climb1", area="climb", object=Slot.O_FALCON_CLIMB_1,
     scene=mission.Scene.SC_FALCON_CLIMB_1, trigger=Slot.PT_FALCON_CLIMB, key=0x159DFE1B},
    {id="climb2", area="climb", object=Slot.O_FALCON_CLIMB_2,
     scene=mission.Scene.SC_FALCON_CLIMB_2, trigger=Slot.PT_FOLLOW_FALCON, key=0xF849C1B2},
    {id="falcon1", area="mountain", object=Slot.O_FALCON_1,
     scene=mission.Scene.SC_FALCON_1, trigger=Slot.PT_FALCON_1, key=0x159DFE1B},
    {id="falcon3", area="mountain", object=Slot.O_FALCON_3,
     scene=mission.Scene.SC_FALCON_3, trigger=Slot.PT_FALCON_3, key=0x159DFE1B},
    {id="falcon4", area="mountain", object=Slot.O_FALCON_4,
     scene=mission.Scene.SC_FALCON_4, trigger=Slot.PT_FALCON_4, key=0xF849C1B2},
}
local function key(f, field) return prefix .. f.id .. "." .. field end

function falcons.prepare(context, state, area)
    context:set_variable(prefix .. "area", area)
    for _, f in ipairs(definitions) do
        if f.area == area and state:variable(key(f,"prepared")) ~= true
            and state:variable(key(f,"retired")) ~= true then
            -- Só solicita os objetos após a confirmação de chegada à área.
            context:set_variable(key(f,"prepared"), true)
            context:activate_objects{slots={f.object}, active=true}
        end
    end
end

function falcons.poll(context, state)
    for _, f in ipairs(definitions) do
        if state:variable(prefix .. "area") == f.area
            and state:variable(key(f,"retired")) ~= true then
            if state:variable(key(f,"ready")) == true
                and state:variable(key(f,"activated")) ~= true then
                context:scene(f.scene):activate{}
                context:set_variable(key(f,"activated"), true)
            end
            local allowed = true
            if f.id == "climb2" then
                allowed = state:variable(prefix .. "climb_cleared") == true
            elseif f.id == "falcon4" then
                allowed = state:variable(prefix .. "canyon") == true
            end
            if allowed and state:variable(key(f,"seen")) == true
                and state:variable(key(f,"activated")) == true
                and state:variable(key(f,"sent")) ~= true then
                -- Somente a chave específica do Dawn, uma vez por tentativa.
                context:scene(f.scene):send_event{key=f.key}
                context:set_variable(key(f,"sent"), true)
            end
        end
    end
end

function falcons.on_object_state(context, state, event)
    for _, f in ipairs(definitions) do
        if state:variable(prefix .. "area") == f.area
            and state:variable(key(f,"prepared")) == true
            and state:variable(key(f,"retired")) ~= true
            and lib.is_slot(context,event,f.object) then
            -- Usa a presença e a geração reportadas pelo cliente; não um timer.
            context:set_variable(key(f,"ready"),
                event.present == true and type(event.generation)=="number" and event.generation > 0)
        end
    end
    falcons.poll(context,state)
end

function falcons.on_trigger(context, state, event)
    for _, f in ipairs(definitions) do
        if state:variable(prefix .. "area") == f.area
            and lib.is_slot(context,event,f.trigger) then
            context:set_variable(key(f,"seen"),true)
        end
    end
    if state:variable(prefix .. "area") == "mountain"
        and lib.is_slot(context,event,Slot.PT_GOTO_HAW) then
        context:set_variable(prefix .. "canyon",true)
    end
    falcons.poll(context,state)
end

function falcons.on_arrival(context,state,event)
    if event.entered ~= true or event.held_region_index ~= 24 then return end
    local area=state:variable(prefix .. "pending_area")
    if area == nil then return end
    context:clear_variable(prefix .. "pending_area")
    falcons.prepare(context,state,area)
    if area == "mountain" and state:variable(prefix .. "cue28_requested") ~= true then
        context:slot(Slot.M_DIALOG_SENSOR_80B5E02A):play_dialogue_cue{
            cue=mission.DialogueCue.M_DIALOG_SENSOR_80B5E02A.CUE_28,
        }
        context:set_variable(prefix .. "cue28_requested",true)
    end
end

function falcons.expect_arrival(context,area)
    context:set_variable(prefix .. "pending_area",area)
end

function falcons.update_combat(context,state,climb_units,bowl_units)
    -- O primeiro esquadrão de cada lista é o ator da cena; o Dawn conta os outros 12.
    local function cleared(units)
        local squads={}
        for i=2,#units do squads[#squads+1]=units[i].squad end
        return #squads > 0 and context:cohort{squads=squads}.cleared == true
    end
    if state:variable(prefix .. "climb_started") == true and cleared(climb_units) then
        context:set_variable(prefix .. "climb_cleared",true)
    end
    if bowl_units and state:variable(prefix .. "bowl_started") == true and cleared(bowl_units) then
        context:set_variable(prefix .. "canyon",true)
    end
    falcons.poll(context,state)
end

-- Executa uma etapa por vez; checkpoints aguarda a entrega antes de pedir a proxima.
-- Nao limpa as flags aqui: elas ainda identificam os atores da tentativa anterior.
function falcons.reset_next(context, state, cursor)
    cursor = cursor or 1
    while cursor <= #definitions * 2 do
        local index = math.floor((cursor - 1) / 2) + 1
        local stopping = cursor % 2 == 1
        local f = definitions[index]
        cursor = cursor + 1
        if state:variable(key(f,"prepared")) == true
            and state:variable(key(f,"retired")) ~= true then
            if stopping then
                if state:variable(key(f,"activated")) == true then
                    return context:scene(f.scene):stop{}, cursor
                end
            else
                -- activate_objects retorna uma lista, mesmo para um unico objeto.
                -- Como esta etapa possui apenas um slot, deve haver uma unica chave.
                local requests = context:activate_objects{slots={f.object}, active=false}
                assert(#requests == 1, "falcon cleanup expected one object request")
                return requests[1], cursor
            end
        end
    end
    return nil, cursor
end

function falcons.retire(context,state,area)
    for _, f in ipairs(definitions) do
        if (area == nil or f.area == area)
            and state:variable(key(f,"prepared")) == true
            and state:variable(key(f,"retired")) ~= true then
            if state:variable(key(f,"activated")) == true then
                context:scene(f.scene):stop{}
            end
            context:activate_objects{slots={f.object},active=false}
            context:set_variable(key(f,"retired"),true)
            context:clear_variable(key(f,"ready"))
            context:clear_variable(key(f,"seen"))
        end
    end
    if area == nil or state:variable(prefix .. "area") == area then
        context:clear_variable(prefix .. "area")
    end
end
return falcons
