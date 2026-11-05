local addonName, addon = ...
addon = addon or {}

-- Amplia variedad de remates de frase según el estado/ánimo
addon.MOODS = {
    DISCOVERY = {
        "con la mirada atenta a cualquier detalle imprevisto.",
        "con la fascinación de adentrarme en territorio desconocido.",
        "procurando no bajar la guardia en este nuevo paraje.",
        "preguntándome qué secretos esconderá este lugar.",
        "con el entusiasmo renovado ante lo que pueda encontrar.",
        "sintiendo el peso del aire en esta zona insólita.",
        "con la curiosidad a flor de piel.",
        "observando cada rincón antes de dar el siguiente paso.",
        "estudiando los relieves del terreno con cautela.",
        "con la sensación de estar pisando tierra inexplorada.",
        "respirando el ambiente propio de esta nueva región.",
        "manteniendo los sentidos alerta ante cualquier movimiento.",
        "con la impaciencia de descubrir qué hay tras la siguiente colina.",
        "avanzando con paso medido por estas tierras vírgenes.",
        "sorprendido por los paisajes que se abren ante mí.",
        "con el mapa en mente y la mirada en el horizonte.",
        "sintiendo que cada rincón guarda una historia por contar.",
        "preparado para responder ante cualquier peligro inesperado.",
        "maravillado por la atmósfera singular de este paraje.",
        "listo para dejar mi impronta en estas fronteras lejanas."
    },
    REVISIT = {
        "recordando viejas batallas disputadas en estos caminos.",
        "con la tranquilidad de quien ya conoce los peligros del terreno.",
        "pensando en cuánto han cambiado las cosas desde mi última visita.",
        "avanzando con paso firme por un camino ya conocido.",
        "sin entretenerme más de lo estrictamente necesario.",
        "atento a si algún nuevo peligro acecha en la zona.",
        "notando cómo la nostalgia se mezcla con el deber.",
        "reconociendo las referencias del paisaje a cada trecho.",
        "con la certeza de saber exactamente hacia dónde me dirijo.",
        "observando los viejos senderos con familiaridad.",
        "sabiendo de antemano qué criaturas me saldrán al paso.",
        "reviviendo en silencio las primeras jornadas en estas tierras.",
        "sintiendo la comodidad de un terreno que no me guarda secretos.",
        "con la soltura de quien ha recorrido este trayecto mil veces.",
        "comprobando si las sombras de antaño aún habitan el lugar.",
        "moviéndome con agilidad entre los caminos habituales.",
        "sintiendo que el tiempo pasa, pero el peligro permanece.",
        "con la compostura de quien regresa con más experiencia.",
        "repasando en la mente las vivencias de anteriores travesías.",
        "prosiguiendo el viaje por senderos de sobra conocidos."
    },
    DEATH = {
        "con la amarga certeza de que debí ser más prudente.",
        "maldiciendo mi suerte y jurando venganza.",
        "con la lección aprendida a un precio demasiado alto.",
        "sabiendo que la muerte es solo un tropiezo en mi camino.",
        "con el orgullo herido pero la determinación intacta.",
        "asimilando el amargo sabor de la derrota.",
        "prometiendo no cometer el mismo error en el próximo intento.",
        "sintiendo cómo la rabia aviva las ganas de volver a luchar.",
        "guardando un silencio sombrío mientras recupero el aliento.",
        "con la mente centrada en cómo cambiar las tornas a mi favor.",
        "recordando que en Azeroth la confianza se paga cara.",
        "con los puños cerrados y el deseo de revancha ardiendo.",
        "reconociendo la superioridad temporal del rival.",
        "sacudiéndome el polvo del suelo tras un choque fatal.",
        "con la fría promesa de un retorno implacable.",
        "sabiendo que cada caída solo me hace más fuerte.",
        "repasando en mi cabeza el segundo en que todo falló.",
        "con la resolución firme de no dejar esta afrenta sin respuesta.",
        "mirando al frente mientras rehago mis fuerzas.",
        "apretando los dientes ante un final imprevisto."
    },
    GENERAL = {
        "con el ánimo firme y la mente despejada.",
        "con más ironía que paciencia.",
        "con los nervios despiertos y la mano en la empuñadura.",
        "reflexionando sobre los acontecimientos recientes.",
        "procurando no confiarme demasiado.",
        "pensando en el largo camino que aún me aguarda.",
        "observando con recelo las sombras del camino.",
        "ajustando mis pertrechos para lo que esté por venir.",
        "sintiendo el cansancio acumulado en las piernas.",
        "con la templanza que otorga el hábito de viajar.",
        "manteniendo una actitud serena ante la adversidad.",
        "con el pensamiento puesto en el descanso de la próxima posada.",
        "avanzando sin prisa pero sin pausa.",
        "sopesando cada decisión antes de actuar.",
        "con la mente puesta en la siguiente meta.",
        "notando el peso de la armadura sobre los hombros.",
        "con la determinación intacta a pesar de las dificultades.",
        "escuchando el rumor del viento entre la vegetación.",
        "con el espíritu preparado para cualquier eventualidad.",
        "contemplando el horizonte con determinación."
    }
}

function addon.GetRandomMood(category)
    local list = addon.MOODS[category] or addon.MOODS.GENERAL
    return list[math.random(1, #list)]
end

-- Función auxiliar para obtener una variante segura según el tamaño de la tabla
local function GetVariant(seed, list)
    if not list or #list == 0 then return 1 end
    return ((seed or 1) % #list) + 1
end

function addon.ComposeEntry(entry)
    local place = entry.place or "algún lugar"
    local subject = entry.text or "algo inesperado"
    local mood = entry.contextualTone or addon.GetRandomMood("GENERAL")
    local seed = entry.seed or math.random(1, 100)

    -- 1. CAMBIO DE ZONAS (Único evento con encabezado rojo)
    if entry.type == "DISCOVERY" or entry.type == "REVISIT" then
        local isFirstTime = (entry.type == "DISCOVERY")
        local method = entry.travelMethod or "ON_FOOT"
        
        local headers = {
            HEARTHSTONE = { "Regreso en Piedra del Hogar: " .. subject, "Retorno Mágico a " .. subject },
            TELEPORT = { "Teletransporte a " .. subject, "Llegada Portal: " .. subject },
            TAXI = { "Vuelo hacia " .. subject, "Desembarco Aéreo en " .. subject },
            ON_FOOT = { 
                isFirstTime and ("Llegada a " .. subject) or ("Regreso a " .. subject), 
                isFirstTime and ("Nuevos Horizontes: " .. subject) or ("Viejos Caminos en " .. subject),
                "Explorando " .. subject 
            }
        }

        local bodies = {
            HEARTHSTONE = string.format("Invoqué el poder de mi piedra del hogar para regresar a %s. %s", subject, mood),
            TELEPORT = string.format("Crucé un umbral mágico que me canalizó directamente hasta %s. %s", subject, mood),
            TAXI = string.format("Aterricé en %s tras completar la travesía en grifo/mantícora. %s", subject, mood),
            ON_FOOT = isFirstTime 
                and string.format("Descubrí por primera vez la región de %s a pie de camino. %s", subject, mood)
                or string.format("Volví a recorrer a pie las tierras de %s. %s", subject, mood)
        }

        local categoryHeaders = headers[method] or headers.ON_FOOT
        local chosenHeader = categoryHeaders[math.random(1, #categoryHeaders)]
        local chosenBody = bodies[method] or bodies.ON_FOOT

        return chosenHeader, chosenBody
    end

    -- 2. EVENTOS PRINCIPALES (Sin encabezado rojo)
    if entry.type == "QUEST" then
        local bodies = {
            string.format("En %s cumplí finalmente con lo acordado al finalizar «%s». %s", place, subject, mood),
            string.format("La jornada dio sus frutos en %s tras dar por terminada la tarea «%s». %s", place, subject, mood),
            string.format("Dejé atrás la misión «%s» completada con éxito mientras recorría %s. %s", subject, place, mood),
            string.format("Al fin concluyó el encargo «%s» en %s. %s", subject, place, mood),
            string.format("Cerré el asunto de «%s» mientras permanecía en %s. %s", subject, place, mood),
            string.format("Los habitantes de %s mostraron su agradecimiento tras completar «%s». %s", place, subject, mood),
            string.format("Puse fin a las complicaciones de «%s» durante mi paso por %s. %s", subject, place, mood),
            string.format("Cumplí hasta el último detalle del encargo «%s» en tierras de %s. %s", subject, place, mood),
            string.format("Tras no pocos esfuerzos en %s, logré rematar la misión «%s». %s", place, subject, mood),
            string.format("Entregué el trabajo de «%s» antes de proseguir el camino por %s. %s", subject, place, mood),
            string.format("El deber me reclamó en %s y respondí completando «%s». %s", place, subject, mood),
            string.format("Una preocupación menos en %s tras solventar «%s». %s", place, subject, mood),
            string.format("Satisfecho por haber culminado «%s» con éxito en %s. %s", subject, place, mood),
            string.format("La promesa hecha en %s quedó saldada al resolver «%s». %s", place, subject, mood),
            string.format("Dejé resuelta la encomienda «%s» mientras exploraba %s. %s", subject, place, mood),
            string.format("El esfuerzo invertido en «%s» valió la pena al recorrer %s. %s", subject, place, mood),
            string.format("Se dio por concluido el compromiso con «%s» en %s. %s", subject, place, mood),
            string.format("Un nuevo logro anotado en mi haber tras finalizar «%s» en %s. %s", subject, place, mood),
            string.format("Tras superar varios contratiempos en %s, di por finalizada la misión «%s». %s", place, subject, mood),
            string.format("Anoté la resolución de «%s» en mi cuaderno de viaje mientras permanecía en %s. %s", subject, place, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]

elseif entry.type == "QUEST_ACCEPT" then
        local npc = entry.npc or "un habitante de la zona"
        local bodies = {
            string.format("Acepté el encargo «%s» de manos de %s mientras me encontraba en %s. %s", subject, npc, place, mood),
            string.format("Me comprometí con %s a llevar a cabo la misión «%s» en %s. %s", npc, subject, place, mood),
            string.format("Escuché la petición de %s en %s y asumí la encomienda «%s». %s", npc, place, subject, mood),
            string.format("Anoté en mis tareas pendientes la petición «%s» tras hablar con %s en %s. %s", subject, npc, place, mood),
            string.format("Un nuevo objetivo fijado en %s: %s me encomendó la misión «%s». %s", place, npc, subject, mood),
            string.format("Atendí a %s en %s y acepté hacerme cargo de «%s». %s", npc, place, subject, mood),
            string.format("Me puse a disposición de %s para cumplir con «%s» en tierras de %s. %s", npc, subject, place, mood),
            string.format("Sumé una nueva responsabilidad tras aceptar la propuesta de %s sobre «%s» en %s. %s", npc, subject, place, mood),
            string.format("Comencé las indagaciones para el asunto «%s» por petición de %s en %s. %s", subject, npc, place, mood),
            string.format("Acepté la encomienda de %s respecto a «%s» mientras exploraba %s. %s", npc, subject, place, mood),
            string.format("Tomé el encargo «%s» que me ofreció %s en %s con intención de resolverlo pronto. %s", subject, npc, place, mood),
            string.format("El camino me llevó ante %s en %s, donde acepté la misión «%s». %s", npc, place, subject, mood),
            string.format("Me ofrecí a prestar ayuda a %s con «%s» durante mi estancia en %s. %s", npc, subject, place, mood),
            string.format("Anoté los detalles indicados por %s para la misión «%s» en %s. %s", npc, subject, place, mood),
            string.format("Recibí las instrucciones de %s para la tarea «%s» en %s. %s", npc, subject, place, mood),
            string.format("Firmé el compromiso con %s para resolver «%s» en %s. %s", npc, subject, place, mood),
            string.format("Un nuevo cometido requiere mi atención en %s tras hablar con %s: «%s». %s", place, npc, subject, mood),
            string.format("Acepté la petición de %s sobre «%s» en %s sin dudarlo. %s", npc, subject, place, mood),
            string.format("Inicié la tarea «%s» a petición de %s mientras recorría %s. %s", subject, npc, place, mood),
            string.format("Prometí a %s ocuparme del asunto «%s» durante mi paso por %s. %s", npc, subject, place, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "BOSS" then
        local bodies = {
            string.format("En %s me enfrenté a %s. La lucha fue encarnizada y, cuando el polvo se asentó, continuaba en pie. %s", place, subject, mood),
            string.format("El temible %s sucumbió ante mi fuerza en %s. %s", subject, place, mood),
            string.format("Una encarnizada contienda en %s acabó con la caída de %s. %s", place, subject, mood),
            string.format("Logré doblegar a %s en las tierras de %s. %s", subject, place, mood),
            string.format("La amenaza que representaba %s en %s quedó neutralizada tras un combate implacable. %s", subject, place, mood),
            string.format("No hubo piedad en %s: %s mordió el polvo tras un enfrentamiento brutal. %s", place, subject, mood),
            string.format("Desafié al poderoso %s en %s y salí victorioso contra todo pronóstico. %s", subject, place, mood),
            string.format("El suelo de %s se estremeció durante la batalla contra %s, pero mi determinación no cedió. %s", place, subject, mood),
            string.format("Cobré la cabeza de %s tras una prueba de fuerza y temple en %s. %s", subject, place, mood),
            string.format("Ni toda la ferocidad de %s bastó para salvarle de la derrota en %s. %s", subject, place, mood),
            string.format("Puse fin al reinado de terror de %s mientras exploraba %s. %s", subject, place, mood),
            string.format("El enfrentamiento contra %s en %s exigió hasta el último de mis recursos, pero la victoria fue mía. %s", subject, place, mood),
            string.format("Tras un cruce de golpes legendario en %s, %s acabó rindiendo el aliento. %s", place, subject, mood),
            string.format("Añadí la derrota de %s a mi historial de grandes gestas en %s. %s", subject, place, mood),
            string.format("Se entonarán canciones sobre la caída de %s en %s. %s", subject, place, mood),
            string.format("Vencí a %s en su propio territorio dentro de %s. %s", subject, place, mood),
            string.format("El destino de %s quedó sellado en %s tras una sangrienta escaramuza. %s", subject, place, mood),
            string.format("Superé el desafío mortífero que suponía %s en las profundidades de %s. %s", subject, place, mood),
            string.format("La bestia conocida como %s sucumbió al fin en %s. %s", subject, place, mood),
            string.format("Dejé el cadáver de %s atrás en %s y proseguí mi camino. %s", subject, place, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "DEATH" then
        local killer = entry.killer or "un enemigo despiadado"
        local bodies = {
            string.format("La aventura se detuvo bruscamente en %s. Sucumbí ante %s; %s", place, killer, mood),
            string.format("Mis fuerzas fallaron en %s frente a %s. %s", place, killer, mood),
            string.format("El camino se tiñó de peligro en %s cuando %s me superó en combate. %s", place, killer, mood),
            string.format("Caí derrotado por %s en %s. Regresaré para saldar esta cuenta. %s", killer, place, mood),
            string.format("Un descuido en %s le valió a %s la oportunidad de acabarme. %s", place, killer, mood),
            string.format("La muerte me alcanzó en %s a manos de %s. %s", place, killer, mood),
            string.format("Mordí el polvo en %s tras un fatal choque contra %s. %s", place, killer, mood),
            string.format("El cruce de armas en %s concluyó en tragedia a favor de %s. %s", place, killer, mood),
            string.format("Fui rebasado por el poder de %s en pleno %s. %s", killer, place, mood),
            string.format("Las sombras se cerraron sobre mí en %s cuando %s asestó el golpe definitivo. %s", place, killer, mood),
            string.format("Un trágico desenlace me esperaba en %s: %s acabó con mi vida. %s", place, killer, mood),
            string.format("El combate contra %s en %s sobrepasó mis defensas. %s", killer, place, mood),
            string.format("Apreté los dientes al caer en %s tras la embestida de %s. %s", place, killer, mood),
            string.format("La fría caricia de la derrota me envolvió en %s a causa de %s. %s", place, killer, mood),
            string.format("Pagué con mi vida un exceso de confianza en %s frente a %s. %s", place, killer, mood),
            string.format("El destino me fue adverso en %s al cruzarme en el camino de %s. %s", place, killer, mood),
            string.format("Mi viaje se interrumpió momentáneamente en %s tras la victoria de %s. %s", place, killer, mood),
            string.format("No pude contener la ferocidad de %s en %s. %s", killer, place, mood),
            string.format("Sucumbí en el terreno hostil de %s, abatido por %s. %s", place, killer, mood),
            string.format("Mi aliento se apagó en %s frente a %s, pero volveré a ponerme en pie. %s", place, killer, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "LOOT" then
        local bodies = {
            string.format("La fortuna se dejó notar en %s: me hice con %s. %s", place, subject, mood),
            string.format("Entre los restos hallados en %s encontré un valioso botín: %s. %s", place, subject, mood),
            string.format("Un hallazgo notable en %s: %s ha pasado a mi posesión. %s", place, subject, mood),
            string.format("El camino recompensó mis esfuerzos en %s con %s. %s", place, subject, mood),
            string.format("Añadí a mis pertrechos %s tras explorar %s. %s", subject, place, mood),
            string.format("Las tierras de %s me regalaron un descubrimiento interesante: %s. %s", place, subject, mood),
            string.format("La suerte estuvo de mi lado en %s al conseguir %s. %s", place, subject, mood),
            string.format("Rebuscando entre lo encontrado en %s, di con %s. %s", place, subject, mood),
            string.format("Un merecido premio a la tenacidad en %s: %s. %s", place, subject, mood),
            string.format("No todos los días se encuentra algo como %s recorriendo %s. %s", subject, place, mood),
            string.format("Mi paciencia en %s dio frutos al reclamar %s. %s", place, subject, mood),
            string.format("Guardé con cuidado %s en mi mochila mientras permanecía en %s. %s", subject, place, mood),
            string.format("El azar me sonrió en %s al toparme con %s. %s", place, subject, mood),
            string.format("Un útil objeto se suma a mi inventario en %s: %s. %s", place, subject, mood),
            string.format("Registré la zona de %s y no me fui con las manos vacías; obtuve %s. %s", place, subject, mood),
            string.format("El botín cobrado en %s incluyó %s. %s", place, subject, mood),
            string.format("Incluso en los rincones más oscuros de %s se hallan tesoros como %s. %s", place, subject, mood),
            string.format("Aumenté mis recursos en %s tras hacerme con %s. %s", place, subject, mood),
            string.format("Un valioso hallazgo en %s que sin duda me servirá más adelante: %s. %s", place, subject, mood),
            string.format("Comprobé con satisfacción el hallazgo de %s durante mi estancia en %s. %s", subject, place, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "LEVEL_UP" then
        local bodies = {
            string.format("Alcancé el nivel %s mientras exploraba %s. Me siento con mayor fortaleza. %s", subject, place, mood),
            string.format("Sopló un viento de renovación en %s: ¡he ascendido al nivel %s! %s", place, subject, mood),
            string.format("El esfuerzo y las batallas libradas en %s dieron su fruto al alcanzar el nivel %s. %s", place, subject, mood),
            string.format("Un nuevo hito en mi camino por %s al llegar al nivel %s. %s", place, subject, mood),
            string.format("Sentí cómo mi poder crecía en %s; ahora ostento el nivel %s. %s", place, subject, mood),
            string.format("Las vivencias acumuladas en %s me han llevado hasta el nivel %s. %s", place, subject, mood),
            string.format("Di un paso más en mi desarrollo personal en %s al alcanzar el nivel %s. %s", place, subject, mood),
            string.format("Mi dominio y destreza aumentaron en %s al subir al nivel %s. %s", place, subject, mood),
            string.format("Un destello de energía me envolvió en %s: ya soy nivel %s. %s", place, subject, mood),
            string.format("Con el nivel %s recién adquirido en %s, me preparo para mayores retos. %s", subject, place, mood),
            string.format("La experiencia obtenida en %s se tradujo en el nivel %s. %s", place, subject, mood),
            string.format("Forjé una mayor resistencia durante mi estancia en %s al llegar al nivel %s. %s", place, subject, mood),
            string.format("Superé mis propios límites en %s y alcancé el nivel %s. %s", place, subject, mood),
            string.format("Anoté con orgullo mi ascenso al nivel %s mientras recorría %s. %s", subject, place, mood),
            string.format("Cada combate en %s me acerca a la maestría; ¡ahora soy nivel %s! %s", place, subject, mood),
            string.format("El camino en %s me ha curtido lo suficiente como para ascender al nivel %s. %s", place, subject, mood),
            string.format("Siento la sangre hervir de determinación en %s tras lograr el nivel %s. %s", place, subject, mood),
            string.format("Un avance significativo en mis facultades tras alcanzar el nivel %s en %s. %s", subject, place, mood),
            string.format("El constante aprendizaje en %s dio sus frutos al subir al nivel %s. %s", place, subject, mood),
            string.format("Renové mis votos de aventura en %s tras coronar el nivel %s. %s", place, subject, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    -- 3. EVENTOS SECUNDARIOS
    elseif entry.type == "MOUNT" then
        local bodies = {
            string.format("He obtenido una nueva montura (%s). Mis desplazamientos en %s serán mucho más veloces.", subject, place),
            string.format("Añadí a %s a mis establos mientras me hallaba en %s. Ahorraré mucho tiempo en el camino.", subject, place),
            string.format("Sume a mi colección la montura %s durante mi estancia en %s.", subject, place),
            string.format("Un nuevo e imponente compañero de viaje: %s. Recomponer el camino por %s será más ágil.", subject, place),
            string.format("A partir de hoy recorreré los parajes de %s a lomos de %s.", place, subject),
            string.format("Conseguí la montura %s en %s. Una adición notable para las largas travesías.", subject, place),
            string.format("El viaje por %s resultará más llevadero tras hacerme con %s.", place, subject),
            string.format("Estrené a mi nueva montura (%s) abriendo paso por los caminos de %s.", subject, place),
            string.format("Adquirí a %s para mis desplazamientos. Recorrer %s ya no será tan fatigoso.", subject, place),
            string.format("Aumenté mi movilidad en %s tras asegurar el uso de %s.", place, subject)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "FLIGHT_POINT" then
        local bodies = {
            string.format("Habilité una nueva conexión con el maestro de vuelo en %s.", place),
            string.format("Descubrí la ruta de vuelo de %s. Un punto clave para replegarme o viajar rápidamente.", place),
            string.format("Establecí contacto con el encargado de los grifos/mantícoras en %s.", place),
            string.format("Añadí el puesto de aviación de %s a mi mapa de rutas aéreas.", place),
            string.format("Aseguré una nueva parada de transporte aéreo al hablar con el maestro de vuelo en %s.", place),
            string.format("Las alas del servicio de transporte en %s quedan a mi entera disposición desde hoy.", place),
            string.format("Registré las coordenadas de vuelo de %s para agilizar futuros desplazamientos.", place),
            string.format("Un enlace aéreo fundamental desbloqueado en la zona de %s.", place),
            string.format("Marcé la posición del maestro de vuelo en %s para volver cuando la necesidad apriete.", place),
            string.format("Facilité mis próximos trayectos al sintonizar la ruta de transporte en %s.", place)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "GUILD" then
        local bodies = {
            string.format("He pasado a formar parte oficialmente de la hermandad «%s».", subject),
            string.format("Uní mis fuerzas a las de la hermandad «%s» para afrontar mayores desafíos.", subject),
            string.format("Acepte la invitación de «%s» y ahora comparto estandarte con sus miembros.", subject),
            string.format("Sello mi lealtad con la hermandad «%s». La aventura en solitario da paso al trabajo en equipo.", subject),
            string.format("Me sumé a las filas de «%s» con la intención de defender su nombre y sus colores.", subject),
            string.format("Un nuevo capítulo comienza tras incorporarme a las filas de «%s».", subject),
            string.format("Caminaremos bajo la misma bandera: pasé a integrar la hermandad «%s».", subject),
            string.format("Encontré cobijo y camaradería entre los integrantes de «%s».", subject),
            string.format("Firmé mi compromiso de hermandad con «%s».", subject),
            string.format("Formalicé mi ingreso en «%s», dispuesto a aportar mi grano de arena a la causa.", subject)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "ACHIEVEMENT" then
        local bodies = {
            string.format("Completé con éxito el logro «%s» mientras exploraba %s.", subject, place),
            string.format("Anoté una proeza en mi expediente tras conseguir el logro «%s» en %s.", subject, place),
            string.format("Un hito personal alcanzado en %s: «%s».", place, subject),
            string.format("Mis hazañas en %s fueron reconocidas al desbloquear el logro «%s».", place, subject),
            string.format("Se registró la proeza «%s» durante mi periplo por %s.", subject, place),
            string.format("Sumé a mi registro el logro «%s» tras los acontecimientos en %s.", subject, place),
            string.format("La constancia en %s tuvo recompensa en forma del logro «%s».", place, subject),
            string.format("Inscribí el logro «%s» en la memoria de mis viajes por %s.", subject, place),
            string.format("Superé los requisitos de la proeza «%s» estando en %s.", subject, place),
            string.format("Un motivo más de orgullo en mi trayectoria: he culminado «%s» en %s.", subject, place)
        }
        return nil, bodies[GetVariant(seed, bodies)]

    elseif entry.type == "NPC" then
        local bodies = {
            string.format("En %s crucé unas palabras con %s. %s", place, subject, mood),
            string.format("Durante mi paso por %s mantuve una breve conversación con %s. %s", place, subject, mood),
            string.format("Me detuve a charlar con %s en las inmediaciones de %s. %s", subject, place, mood),
            string.format("Escuché atentamente lo que %s tenía que decir en %s. %s", subject, place, mood),
            string.format("Un encuentro curioso en %s: entablé contacto con %s. %s", place, subject, mood),
            string.format("Intercambié noticias sobre los caminos con %s en %s. %s", subject, place, mood),
            string.format("Consulté ciertos detalles con %s mientras permanecía en %s. %s", subject, place, mood),
            string.format("En pleno %s me crucé con %s, quien me ofreció su particular punto de vista. %s", place, subject, mood),
            string.format("Compartí unos minutos de charla con %s en %s antes de proseguir. %s", subject, place, mood),
            string.format("Aproveché mi estancia en %s para hablar con %s. %s", place, subject, mood),
            string.format("Recibí valiosos consejos de %s al encontrarme en %s. %s", subject, place, mood),
            string.format("Coincidí con %s en la zona de %s. %s", subject, place, mood),
            string.format("Intercambié un saludo cordial con %s durante mi trayecto por %s. %s", subject, place, mood),
            string.format("El camino en %s me llevó hasta %s, con quien conversé un rato. %s", place, subject, mood),
            string.format("Escuché los rumores que circulaban de boca de %s en %s. %s", subject, place, mood),
            string.format("Establecí conversación con %s mientras recorría %s. %s", subject, place, mood),
            string.format("Anoté las palabras de %s tras encontrármelo en %s. %s", subject, place, mood),
            string.format("Un momento de respiro en %s charlando con %s. %s", place, subject, mood),
            string.format("Crucé opiniones sobre el estado de la región con %s en %s. %s", subject, place, mood),
            string.format("Dejé constancia de mi encuentro con %s en las tierras de %s. %s", subject, place, mood)
        }
        return nil, bodies[GetVariant(seed, bodies)]
    end

    return nil, subject
end