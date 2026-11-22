# Outpost Control

**Autor**: Monsterfish
**Versión**: 1.0.16

Más control sobre los puestos avanzados europeos y árabes que colocas en el editor de mapas. Cada apartado puede desactivarse en los ajustes.

## El panel del puesto avanzado

Selecciona un puesto avanzado en el editor de mapas. El botón de la parte superior de su panel ahora alterna entre dos páginas. Cada deslizador muestra su valor a la derecha.

- **Atacantes** – qué tropas envía el puesto avanzado, como en el juego base, con tres deslizadores:
  - **Tamaño:** exactamente cuántas tropas tiene cada oleada, desde 0 (sin oleadas) hasta el máximo que el propio juego envía en su tamaño mayor. (Con «Fijar el número exacto de tropas por oleada» desactivado vuelve a ser el deslizador del juego: 6 escalones de tamaños aleatorios.) Sin el módulo, el mapa conserva el tamaño propio del juego más cercano.
  - **Retraso inicial:** cuánto espera antes de la primera oleada (el propio del juego), mostrado en segundos a velocidad normal.
  - **Crecimiento:** cuánto crece cada oleada en porcentaje de la primera oleada por cada nueva oleada. 0 (valor inicial) mantiene todas las oleadas del tamaño de la primera, como en el juego base; 50 añade la mitad de la primera oleada cada vez; 100 añade una primera oleada completa cada vez. Las oleadas dejan de crecer al llegar a 999 tropas. La velocidad con la que llegan las oleadas sigue igual que en el juego: un poco antes tras cada oleada.
- **Defensores** – los mismos ocho botones de tropas con un nuevo cometido, más un deslizador:
  - **Botones de tropas:** qué tropas defienden el puesto avanzado. Si eliges varios, se turnan. Un puesto europeo ofrece arqueros, ballesteros, lanceros, piqueros, maceros, espadachines, caballeros y monjes negros; uno árabe ofrece arqueros árabes, honderos, arqueros a caballo, espadachines árabes, esclavos, asesinos, lanzafuegos y ballesteros. Sin nada seleccionado, el puesto usa arqueros, como en el juego base.
  - **Cantidad:** cuántos guardias custodian el puesto avanzado, de ninguno a 50. Los guardias caídos se reponen de uno en uno; cuanto mayor sea la cantidad, más rápido llegan, de modo que una guarnición completa tarda en reponerse más o menos lo mismo que los 8 guardias del juego (un guardia cada 30 segundos para 8, cada 5 segundos para 50, a velocidad normal).
  - **Posturas:** los soldados de a pie cuerpo a cuerpo (lanceros, piqueros, maceros, espadachines, monjes negros, asesinos) vigilan en postura defensiva y acuden contra los enemigos que se acercan; los esclavos adoptan postura agresiva y cargan contra enemigos más lejanos; los caballeros son agresivos y patrullan a caballo alrededor del puesto, atacando tropas enemigas y cualquier edificio enemigo a menos de 10 casillas; los arqueros a caballo también son agresivos y patrullan alrededor del puesto por seis puntos aleatorios a entre 7 y 15 casillas, uno en cada dirección, desplazados a una casilla libre cercana si estorba un edificio, una muralla o el agua. Los arqueros, ballesteros, honderos y lanzafuegos permanecen quietos disparando igual que los arqueros originales del puesto.
  - **Sobre las murallas:** los guardias a pie suben a las murallas, torres de piedra y casas de la puerta de piedra del propietario a menos de 16 casillas del puesto, si pueden llegar caminando: cada uno va al punto libre con menos guardias alrededor, de modo que se reparten y cubren los huecos de los caídos. Los caballeros y arqueros a caballo se quedan abajo. Funciona en todos los puestos avanzados, incluidos los que no tienen ajustes propios (configurable).

## Tareas de los atacantes

Normalmente toda una oleada hace lo mismo: avanzar y atacar un edificio, cavando el foso de vez en cuando. Con este módulo, cada oleada se divide por tipo de unidad al salir y cada parte recibe una tarea adecuada:

| Unidad | Primera tarea (porcentaje predeterminado) | El resto |
| --- | --- | --- |
| Esclavos | rellenar el foso (50%) | quemar y destruir edificios |
| Lanceros | rellenar el foso (50%) | golpear murallas y puertas |
| Maceros | rellenar el foso (30%) | destruir edificios |
| Espadachines | golpear murallas y puertas (60%) | destruir edificios |
| Espadachines árabes | golpear murallas y puertas (50%) | destruir edificios |
| Caballeros | dar caza al Señor (40%) | rodear el castillo a caballo |
| Arqueros, arqueros árabes | rellenar el foso (30%) | avanzar y disparar a las tropas que encuentren |
| Honderos | rodear el castillo a pie (30%) | avanzar y disparar a las tropas que encuentren |
| Arqueros a caballo | rodear el castillo a caballo (100%) | avanzar y disparar a las tropas que encuentren |
| Lanzafuegos | quemar edificios (60%) | avanzar y quemar a las tropas que encuentren |

Rodear el castillo significa dar vueltas a buena distancia y acabar con los trabajadores y tropas que haya fuera de las murallas. Los caballeros solo van a por el Señor cuando pueden alcanzarlo; de lo contrario, también rodean el castillo. Un grupo al que no le quede nada que hacer (el foso ya está relleno, no hay murallas de por medio) ataca como habría hecho toda la oleada. Todos los porcentajes pueden cambiarse en los ajustes.

## Máquinas de asedio en camino

Las catapultas y balistas de fuego de un puesto avanzado marchan hacia el castillo que atacan y se detienen para disparar en cuanto algo enemigo entra en su alcance, igual que tus propias máquinas de asedio con un objetivo:

- **Catapultas** (y trabuquetes o mangoneles, si los puestos de un mapa los envían) disparan al edificio enemigo más cercano a su alcance, y luego al siguiente.
- **Balistas de fuego** disparan primero a tropas y trabajadores enemigos a su alcance, y después a edificios.

El propio juego decide si algo está a tiro usando el alcance de cada máquina (el que fije Rebalancer, si lo usas), exactamente igual que para una máquina del jugador. Solo apuntan a enemigos: jugadores de otro equipo distinto al del propietario del puesto, nunca aliados y nunca edificios neutrales ni animales. Un grupo de asedio se detiene mientras alguna de sus máquinas tenga algo a tiro, así que nunca pasan de largo ante un objetivo; cuando ya no queda nada al alcance, retoman la marcha.

## Siguiente rival

Cada tropa enviada por un puesto avanzado va a por un jugador enemigo. Cuando ese jugador es derrotado (su Señor muere), la tropa elige al siguiente rival del mismo modo que el juego elige el primero —el enemigo más cercano cuyo Señor siga con vida— en lugar de quedarse parada. Las máquinas de asedio siguen disparando a cualquier enemigo a su alcance y, al destruir un objetivo, pasan al siguiente disponible.

## Los puestos avanzados refuerzan a la IA (desactivado por defecto)

Con esta opción activada, una oleada que sale de un puesto avanzado de la IA se une al ejército de ataque de esa IA en lugar de atacar por su cuenta. Cada unidad entra en el grupo que el propio juego usaría para ella: arqueros, ballesteros, honderos, arqueros a caballo y lanzafuegos a las tropas de apoyo, y el resto al ejército principal. Esperan al próximo ataque de la IA, luchan en él y cuentan para el ejército que la IA espera reunir antes de atacar. Las máquinas de asedio se quedan con el puesto y disparan a lo que alcancen.

## Partidas guardadas y mapas

Lo que configuras para cada puesto avanzado se guarda en el mapa y en las partidas guardadas (mediante el módulo Map Extensions). Si se juega sin este módulo, el mapa sigue funcionando: el puesto conserva el número de guardias configurado (al menos uno, como arqueros) y sus oleadas mantienen el tamaño propio del juego sin crecer.
