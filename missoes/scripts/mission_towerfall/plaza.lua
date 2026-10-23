-- A praça (área 6, região 48): a frota Cabal sobre a Cidade, Zavala em seu abrigo e os três
-- ataques que ele e o jogador repelem, até a saída para o boulevard.
-- Os eventos e seus intervalos seguem as sequências da praça de Homecoming 0.4.0.
local shared = require("mission_towerfall.shared")
local Slot, Squad, TaskGroup, Directive = shared.Slot, shared.Squad, shared.TaskGroup,
    shared.Directive
local scenes, cue = shared.scenes, shared.cue
local unit, line = shared.unit, shared.line

local plaza = {}

plaza.legs = {
    {id = "plaza", state = shared.states.plaza, arm ={
        Slot.PT_SPIRE_TRIGGER, Slot.PT_DEFEND, Slot.PT_ZAVALA_LOOP, Slot.PT_GOTO_BOULEVARD,
    }},
} 
-- Todo esquadrão da praça recebe o objetivo de eliminação antes de ser posicionado. Esse objetivo tem um único grupo de tarefas,
-- então o esquadrão recebe esse grupo ou fica sem nenhum: as duas vítimas que a cena de combate de Zavala elimina
-- aguardam no local onde foram posicionadas.
local OBJECTIVE, GROUP = Slot.OBJ_PLAZA_KILL_CABAL, TaskGroup.OBJ_PLAZA_KILL_CABAL.GROUP_0

--- Um esquadrão associado ao grupo de tarefas, com `count` integrantes por faixa.
local function fighter(squad, source, count)
    return unit(squad, source, GROUP, count)
end
-- Cada esquadrão é posicionado com uma quantidade explícita por faixa, conforme os ajustes da versão 0.4.0.
local VICTIMS = {
    unit(Squad.SQUAD_KILL_CABAL_1, Slot.SQUAD_KILL_CABAL_1, nil, 1),
    unit(Squad.SQUAD_KILL_CABAL_2, Slot.SQUAD_KILL_CABAL_2, nil, 1),
}
-- Os combatentes de cada ataque, usados para contar os integrantes que o cliente cria.
local WAVE_1 = {
    fighter(Squad.SQ_PLAZA_REINFORCE_A_A, Slot.SQ_PLAZA_REINFORCE_A_A, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_START_B, Slot.SQ_PLAZA_REINFORCE_START_B, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_A_B, Slot.SQ_PLAZA_REINFORCE_A_B, 1),
}
local WAVE_2 = {
    fighter(Squad.SQ_PLAZA_REINFORCE_A_D, Slot.SQ_PLAZA_REINFORCE_A_D, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_A_B, Slot.SQ_PLAZA_REINFORCE_A_B, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_A_D_EXTRA, Slot.SQ_PLAZA_REINFORCE_A_D_EXTRA, 3),
    fighter(Squad.SQ_PLAZA_INTERIM_A_A, Slot.SQ_PLAZA_INTERIM_A_A, 2),
}
local WAVE_3 = {
    fighter(Squad.SQ_PLAZA_INTERIM_A_B, Slot.SQ_PLAZA_INTERIM_A_B, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_B_A, Slot.SQ_PLAZA_REINFORCE_B_A, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_A_B, Slot.SQ_PLAZA_REINFORCE_A_B, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_B_B, Slot.SQ_PLAZA_REINFORCE_B_B, 2),
    fighter(Squad.SQ_PLAZA_REINFORCE_B_A_EXTRA, Slot.SQ_PLAZA_REINFORCE_B_A_EXTRA, 2),
}
-- O objetivo com contador já contém o título "Defenda a Torre". Cada ataque é uma etapa que
-- mostra a contagem atual e termina quando sua onda é eliminada; as barreiras das ondas impedem que a saída
-- encerre essas etapas antes da hora.
plaza.steps = {
    -- O objetivo continua sendo "Encontre Zavala", desde a Underwatch. Os slots da praça não aceitam comandos até que
    -- o cliente tenha a região ativa, cerca de quinze segundos após a saída do hangar.
    {id = "goto_plaza", ends = {region = "plaza"}},
    -- A música da praça (seção 11) corresponde à área de ativação logo após a porta, mas o jogador atravessa essa área
    -- antes de o cliente ter a região ativa, momento em que o gatilho poderia ser habilitado. A ativação da região
    -- ocorre aproximadamente no mesmo instante, então a música começa a partir daí, junto com a frota.
    {
        id = "plaza",
        ends = {
            trigger = Slot.PT_DEFEND,

            -- Só aceita a autorização da tentativa atual.
            fallback = function(context, state)
                return state:variable("towerfall.plaza_recovery.defense")
                    == context.attempt_generation
            end,
        },
        sequence = {{after_ms = 2500, music = 11}},
    },
    -- morrem segundo o contador do objetivo, independentemente da causa (o cliente não informa os integrantes de todos
    -- os esquadrões), e as duas vítimas, que não têm grupo de tarefas e por isso não entram nessa contagem, ficam
    -- sem integrantes vivos: Zavala as elimina em sua cena, ou o jogador as mata. Às vezes, o cliente cria
    -- menos Cabais que o solicitado; por isso, após a chegada de todas as cápsulas da onda, a contagem também
    -- aceita a morte de todos os integrantes efetivamente criados.
        {id = "wave1", barrier = true,
        directive = Directive.ASSAULTS_REPELLED,
        progress = {0, 3},
        ends = {
            -- Caminho original: confirmação de término do encontro.
            clear = "wave1",

            -- Alternativa: contador de mortes da primeira onda.
            -- Não exige que as duas vítimas do Zavala desapareçam.
            kills = {
                objective = OBJECTIVE,
                count = 5,
                of = WAVE_1,
            },
        },
    },
    {id = "wave2", barrier = true, directive = Directive.ASSAULTS_REPELLED, progress = {1, 3},
        ends = {clear = "wave2",
            kills = {objective = Slot.OBJ_PLAZA_KILL_CABAL, count = 11, of = WAVE_2,
                settle_ms = 45000, gone = VICTIMS}}},
    {id = "wave3", barrier = true, directive = Directive.ASSAULTS_REPELLED, progress = {2, 3},
        ends = {clear = "wave3",
            kills = {objective = Slot.OBJ_PLAZA_KILL_CABAL, count = 10, of = WAVE_3,
                settle_ms = 45000, gone = VICTIMS}}},
    { id = "repelled",barrier = true,directive = Directive.ASSAULTS_REPELLED,
            progress = {3, 3},
            ends = {sequence = true},
            sequence = {
                {after_ms = 1500, lines = {line(cue.CUE_59)}},
                {spoken = cue.CUE_59, after_ms = 500},
            },
        },
    
    {id = "speaker",
        directive = Directive.LEAVE_THE_PLAZA_AND_FIND_THE_SPEAKER,
        ends = {
            -- Caminho normal: o cliente informa o gatilho de saída.
            trigger = Slot.PT_GOTO_BOULEVARD,

            -- Alternativa: o jogador já entrou no Boulevard.
            region = "boulevard",
        },
    },
}
    -- Controla o ciclo de repetição da defesa da praça
    plaza.repeat_defense = {
        -- Começa somente após as três ondas obrigatórias.
        start_step = "speaker",
        -- Impede novos ciclos quando o jogador aciona a saída.
        stop_trigger = Slot.PT_GOTO_BOULEVARD,

        -- Reforços adicionais: primeira onda, segunda onda, primeira novamente.
        -- A seleção circular usa o tamanho desta lista; WAVE_3 continua obrigatória.
        waves = {WAVE_1, WAVE_2},
        -- Objetivo de combate atribuído aos grupos de reforço.
        objective = OBJECTIVE,

        -- Anuncia a chegada dos reforços.
        reinforcement_cue = cue.CUE_61,
        -- Anuncia o bombardeio antes da chegada dos reforços.
        missile_cue = cue.CUE_60,
        -- Incentiva o avanço após a confirmação do fim da onda.
        advance_cue = cue.CUE_62,

        -- Cenas e objetos usados no bombardeio das repetições.
        bombardment = {
            -- Cena que precisa parar para liberar Zavala.
            combat_scene = scenes.SC_ZAVALA_COMBAT,

            -- Cena em que Zavala se protege com o escudo.
            shield_scene = scenes.SC_ZAVALA_BUNKER_SHIELD_BUNKER,

            -- Vincula a cena ao Zavala que já existe na praça.
            zavala_slot = Slot.SQ_ZAVALA_BANSHEE,

            -- Elementos usados pelo ataque de mísseis da torre.
            missile_object = Slot.O_SPIRE_MISSILE_ATTACK,
            missile_device = Slot.D_SPIRE,

            -- Intervalo usado nas ondas existentes entre parar o combate
            -- e solicitar a cena do escudo.
            prepare_ms = 100,

            -- Duração inicial proposta para o bombardeio: 12 segundos.
            -- Este valor será ajustado após observar a cena no jogo.
            duration_ms = 12000,
},

        -- Espera oito segundos após o término da fala de avanço.
        interval_ms = 3000,
    }
-- A batalha aérea é configurada como ausente inicialmente, assim como a nave de comando do hangar: seus objetos são instanciados
-- na chegada, e suas naves de transporte são acionadas; caso contrário, ficam inertes. O dispositivo da torre permanece sem alterações
-- até sua chuva de mísseis.
local FLEET = {
    Slot.O_SPIRE, Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_CABAL_SHIP,
    Slot.O_CABAL_CARRIER_L_80B5103A, Slot.O_CABAL_CARRIER_R_80B5103A, Slot.O_CABAL_CARRIER_B,
    Slot.O_CABAL_CARRIER_FAR_A, Slot.O_CABAL_CARRIER_FAR_A_1, Slot.O_CABAL_CARRIER_FAR_A_2,
    Slot.O_CABAL_CARRIER_FAR_B, Slot.O_CABAL_CARRIER_FAR_B_1, Slot.O_CABAL_CARRIER_FAR_B_2,
    Slot.O_CABAL_CARRIER_FAR_C, Slot.O_CABAL_CARRIER_FAR_C_1, Slot.O_CABAL_CARRIER_FAR_C_2,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_0, Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_1,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_2, Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_3,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_4, Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_5,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_6, Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_7,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_LEFT_0,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_LEFT_1,
    Slot.SPECOPS_PLAZA_SHIP_BATTLE_O_DO_SHIP_LEFT_2,
}
local CARRIERS = {
    Slot.D_CABAL_CARRIER_L_80B5103A, Slot.D_CABAL_CARRIER_R_80B5103A, Slot.D_CABAL_CARRIER_B,
    Slot.D_CABAL_CARRIER_FAR_A, Slot.D_CABAL_CARRIER_FAR_A_1, Slot.D_CABAL_CARRIER_FAR_A_2,
    Slot.D_CABAL_CARRIER_FAR_B, Slot.D_CABAL_CARRIER_FAR_B_1, Slot.D_CABAL_CARRIER_FAR_B_2,
    Slot.D_CABAL_CARRIER_FAR_C, Slot.D_CABAL_CARRIER_FAR_C_1, Slot.D_CABAL_CARRIER_FAR_C_2,
}

-- Zavala é um integrante de esquadrão: cada uma de suas cenas vincula sua célula, para atuar sobre esse integrante
-- em vez de criar um personagem próprio. A cena de combate é reproduzida sem chave de evento; a cena do escudo do abrigo
-- assume o controle enquanto suas falas chamam o jogador para dentro.
local ZAVALA = {Slot.SQ_ZAVALA_BANSHEE}
local combat = {scene = scenes.SC_ZAVALA_COMBAT, bind = ZAVALA, keys = {}}
local bunker = {scene = scenes.SC_ZAVALA_BUNKER_SHIELD_BUNKER, bind = ZAVALA}

plaza.encounters = {
    -- A frota e Zavala são posicionados assim que a região fica ativa: o jogador entra na área de ativação da porta da praça
    -- antes de o cliente ativar a região e habilitar esse gatilho.
    -- Zavala é vinculado à sua célula, e sua cena usa apenas a terceira chave de evento.
    {id = "fleet", after = "plaza",
        objects = {slots = FLEET},
        move = {to = "open", slots = CARRIERS},
        scenes = {{scene = scenes.SC_ZAVALA, bind = ZAVALA,
            keys = {scenes.SC_ZAVALA.event_keys[3]}}}},
    -- A chuva de mísseis da torre ocorre na área de ativação mais interna da praça, a primeira informada
    -- após a ativação da região. O escudo de encenação de Zavala também é reproduzido aqui: dura seis segundos e
    -- deve desaparecer antes de o jogador alcançar o abrigo.
    {id = "spire", after = "plaza", trigger = Slot.PT_SPIRE_TRIGGER,
            -- Recuperacao autorizada somente para a tentativa atual.
        fallback = function(context, state)
            return state:variable("towerfall.plaza_recovery.request")
                == context.attempt_generation
        end,
        objects = {slots = {Slot.O_SPIRE_MISSILE_ATTACK}},
        move = {to = "open", slots = {Slot.D_SPIRE}},
        scenes = {{scene = scenes.SC_FAKE_SHIELD}}},
    -- Pontos de referência dos esquadrões, do abrigo (Zavala em y = 30) para fora: as vítimas e START_B ficam
    -- à frente dele; A_A, entre eles; A_B, na parte central ao fundo; A_D e a família B_A, ao fundo à direita; B_B, ao fundo
    -- à esquerda. Uma cápsula corresponde a um posicionamento de esquadrão; `count` é sua quantidade de Cabais.
    -- Primeiro ataque: três cápsulas próximas ao abrigo, sete Cabais no total, incluindo as vítimas de Zavala
    -- e os dois esquadrões contra os quais sua cena de combate dispara (A_A, A_B).
    {id = "wave1", after = "wave1", trigger = Slot.PT_ZAVALA_LOOP,
    -- Usa a sequência original da onda quando a recuperação autorizar.
        fallback = function(context, state)
            return state:variable("towerfall.plaza_recovery.defense")
                == context.attempt_generation
        end,
        sequence = {
            {after_ms = 2000, stop = {scenes.SC_ZAVALA},
                place = {objective = OBJECTIVE, squads = {VICTIMS[1], VICTIMS[2]}}},
            {after_ms = 2500, place = {objective = OBJECTIVE, squads = {
                fighter(Squad.SQ_PLAZA_REINFORCE_A_A, Slot.SQ_PLAZA_REINFORCE_A_A, 2)}}},
            {after_ms = 2500, place = {objective = OBJECTIVE, squads = {
                fighter(Squad.SQ_PLAZA_REINFORCE_START_B, Slot.SQ_PLAZA_REINFORCE_START_B, 2),
                fighter(Squad.SQ_PLAZA_REINFORCE_A_B, Slot.SQ_PLAZA_REINFORCE_A_B, 1)}}},
            {after_ms = 2200, scenes = {combat}},
        }},
    -- Segundo ataque: a cápsula ao fundo aterrissa dois segundos após o início do intervalo; Zavala recua para
    -- seu escudo durante os mísseis, e a onda chega em ritmo constante: duas cápsulas ao fundo, uma
    -- bem à frente do abrigo (suas vítimas), uma na extremidade distante e mais uma alguns segundos depois.
    {id = "wave2", after = "wave2", lines = {line(cue.CUE_52)}, sequence = {
        {after_ms = 2000, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_REINFORCE_A_D, Slot.SQ_PLAZA_REINFORCE_A_D, 2)}}},
        -- As cenas de uma configuração são reproduzidas antes de suas ações: a cena de combate é interrompida em um item separado
        -- para que a cena do abrigo encontre Zavala disponível.
        {after_ms = 7000, stop = {scenes.SC_ZAVALA_COMBAT}},
        {after_ms = 100, scenes = {bunker}},
        {after_ms = 2300, lines = {line(cue.CUE_53)}},
        {after_ms = 12000, lines = {line(cue.CUE_51)},
            stop = {scenes.SC_ZAVALA_BUNKER_SHIELD_BUNKER},
            place = {objective = OBJECTIVE, squads = {
                fighter(Squad.SQ_PLAZA_REINFORCE_A_D, Slot.SQ_PLAZA_REINFORCE_A_D, 2)}}},
        -- O ambiente de execução rejeita A_C por não ser executável; por isso, a cápsula da parte central ao fundo usa A_B novamente.
        {after_ms = 2500, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_REINFORCE_A_B, Slot.SQ_PLAZA_REINFORCE_A_B, 2)}}},
        {after_ms = 2500, place = {objective = OBJECTIVE, squads = {VICTIMS[1], VICTIMS[2]}}},
        {after_ms = 3000, scenes = {combat}},
        {after_ms = 1000, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_REINFORCE_A_D_EXTRA, Slot.SQ_PLAZA_REINFORCE_A_D_EXTRA, 3)}}},
        {after_ms = 3000, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_INTERIM_A_A, Slot.SQ_PLAZA_INTERIM_A_A, 2)}}},
    }},
    -- Terceiro ataque: a cápsula do intervalo na extremidade distante, o escudo novamente e depois cinco cápsulas no
    -- mesmo ritmo: fundo à direita, meio, bem à frente (as vítimas), fundo distante à esquerda e fundo à direita novamente.
    {id = "wave3", after = "wave3", sequence = {
        {after_ms = 500, lines = {line(cue.CUE_55)}, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_INTERIM_A_B, Slot.SQ_PLAZA_INTERIM_A_B, 2)}}},
        {after_ms = 8000, stop = {scenes.SC_ZAVALA_COMBAT}},
        {after_ms = 100, scenes = {bunker}},
        {after_ms = 2900, lines = {line(cue.CUE_57)}},
        {after_ms = 11000, lines = {line(cue.CUE_54)},
            stop = {scenes.SC_ZAVALA_BUNKER_SHIELD_BUNKER},
            place = {objective = OBJECTIVE, squads = {
                fighter(Squad.SQ_PLAZA_REINFORCE_B_A, Slot.SQ_PLAZA_REINFORCE_B_A, 2)}}},
        {after_ms = 2500, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_REINFORCE_A_B, Slot.SQ_PLAZA_REINFORCE_A_B, 2)}}},
        {after_ms = 2500, place = {objective = OBJECTIVE, squads = {VICTIMS[1], VICTIMS[2]}}},
        {after_ms = 3000, scenes = {combat}},
        {after_ms = 1000, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_REINFORCE_B_B, Slot.SQ_PLAZA_REINFORCE_B_B, 2)}}},
        {after_ms = 2500, place = {objective = OBJECTIVE, squads = {
            fighter(Squad.SQ_PLAZA_REINFORCE_B_A_EXTRA, Slot.SQ_PLAZA_REINFORCE_B_A_EXTRA, 2)}}},
    }},
    -- Adiciona dialogo na transição do cenario
        {id = "boulevard_dialogue",
        after = "speaker",
        trigger = Slot.PT_GOTO_BOULEVARD,

        -- Usa a confirmação de entrada no Boulevard se o gatilho falhar.
        -- O encontro continua dependendo do início da etapa speaker.
        fallback = function(context, state)
            return state:variable("flow.towerfall.fact.leg.boulevard") == true
        end,

        -- Mantém a fala original da saída.
        lines = {line(cue.CUE_63)},
    },


}

return plaza