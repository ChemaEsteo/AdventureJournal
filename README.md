# 📖 Diario de Aventuras

Addon para World of Warcraft que registra automáticamente las aventuras de tu personaje y las organiza en un diario cronológico, convirtiendo tu actividad dentro del juego en una pequeña crónica de tu recorrido por Azeroth.

El objetivo es conservar un registro de la experiencia de juego: las misiones completadas, los enemigos derrotados, las muertes sufridas y los objetos importantes obtenidos.

Además, incluye herramientas externas para exportar el contenido del diario a un archivo de texto legible, permitiendo conservar y consultar tus aventuras fuera de World of Warcraft.

## ✨ Características

### Registro automático de aventuras

El addon registra diferentes acontecimientos durante tus sesiones de juego:

- **Sesiones de juego:** cada inicio de sesión comienza una nueva jornada en el diario.
- **Misiones:** registro de misiones aceptadas y completadas, identificándolas mediante su ID.
- **Jefes:** registro de los jefes derrotados.
- **Combate:** seguimiento de los acontecimientos relacionados con el combate.
- **Muertes:** registro del enemigo que ha acabado con la vida de tu personaje.
- **Botín:** registro de los objetos de calidad épica y legendaria obtenidos.

### Diario de aventuras integrado

Toda la información se almacena y organiza de forma independiente para cada personaje.

El diario cuenta con una interfaz propia dentro del juego que permite consultar las aventuras registradas, navegar entre sus diferentes entradas y revisar el historial de tus jornadas.

La intención es presentar los acontecimientos como un diario de viaje, en lugar de como un simple listado de eventos técnicos.

### Personalización y acceso

- Comando `/diario` para abrir el diario.
- Atajo de teclado configurable desde las opciones de asignación de teclas de World of Warcraft.
- Persistencia de los datos entre sesiones mediante SavedVariablesPerCharacter.

## 📦 Instalación

1. Descarga o clona este repositorio.
2. Localiza la carpeta de instalación de World of Warcraft.
3. Copia la carpeta `AdventureJournal` dentro del directorio de addons correspondiente.

Para WoW Classic Era, la ruta habitual es:

```text
World of Warcraft/
└── _classic_era_/
    └── Interface/
        └── AddOns/
            └── AdventureJournal/
```

4. Comprueba que los archivos del addon están directamente dentro de `AdventureJournal`, sin carpetas duplicadas.
5. Inicia el juego y comprueba que el addon aparece en la lista de complementos.
6. Actívalo y entra con tu personaje.

Una vez dentro del juego, puedes abrir el diario escribiendo:

```text
/diario
```

También puedes configurar un atajo de teclado desde el menú de asignación de teclas.

## 💾 Almacenamiento de datos

El diario utiliza el sistema de guardado de World of Warcraft.

Los datos se almacenan de manera independiente para cada personaje, evitando mezclar las aventuras de diferentes personajes.

La ubicación habitual de los datos es:

```text
World of Warcraft/
└── WTF/
    └── Account/
        └── CUENTA/
            └── REINO/
                └── PERSONAJE/
                    └── SavedVariables/
                        └── AdventureJournal.lua
```

**Importante:** los datos se guardan al cerrar sesión o salir del juego correctamente. Es recomendable cerrar World of Warcraft antes de realizar una exportación.

## 📄 Exportación del diario fuera del juego

El repositorio incluye dos herramientas adicionales que permiten convertir los datos almacenados por World of Warcraft en un documento de texto mucho más cómodo de consultar.

### `ExportarDiario.bat`

Archivo ejecutable de Windows que automatiza el proceso de exportación.

Sus funciones son:

- Iniciar el proceso de exportación.
- Ejecutar el script de Python.
- Facilitar la selección del archivo de datos del personaje.
- Generar el documento de texto resultante.

No es necesario ejecutar comandos manualmente desde una terminal.

### `ExportarDiario.py`

Script de Python encargado de interpretar los datos guardados por el addon.

Lee el archivo `AdventureJournal.lua`, procesa la información registrada y la transforma en un documento de texto organizado y legible.

### Cómo exportar el diario

1. Cierra World of Warcraft para asegurarte de que los últimos datos están guardados.
2. Localiza los archivos `ExportarDiario.bat` y `ExportarDiario.py` incluidos en el repositorio.
3. Ejecuta `ExportarDiario.bat`.
4. Selecciona el archivo `AdventureJournal.lua` correspondiente al personaje que quieras exportar, cuando se solicite.
5. Espera a que termine el procesamiento.

El resultado será un archivo con el siguiente formato:

```text
Diario_NombreDelPersonaje.txt
```

Este archivo permite conservar tus aventuras fuera del juego, leerlas cómodamente o archivarlas independientemente de World of Warcraft.

**Requisitos:** Windows y Python instalado para ejecutar el script de exportación.

## 📁 Estructura del proyecto

```text
AdventureJournal/
│
├── AdventureJournal.lua
├── AdventureJournal.toc
├── Locales.lua
├── Events.lua
├── Bindings.xml
│
├── ExportarDiario.bat
├── ExportarDiario.py
│
└── README.md
```

| Archivo | Función |
|---|---|
| `AdventureJournal.lua` | Lógica principal del addon y registro de acontecimientos. |
| `AdventureJournal.toc` | Configuración y metadatos del addon. |
| `Bindings.xml` | Definición del atajo de teclado. |
| `Events.lua` | Registro de eventos ingame para el diario. |
| `Locales.lua` | Frases tipo para la generación aleatoria de entradas en el diario. |
| `ExportarDiario.bat` | Automatización de la exportación en Windows. |
| `ExportarDiario.py` | Procesamiento y conversión de los datos a texto. |
| `README.md` | Documentación del proyecto. |

## 🎯 Filosofía del proyecto

Diario de Aventuras nace con una idea sencilla: que las aventuras de nuestros personajes no se pierdan entre sesiones de juego.

World of Warcraft ofrece innumerables historias, encuentros y experiencias, pero muchas de ellas terminan olvidándose con el paso del tiempo.

**Porque cada personaje tiene una historia que merece ser recordada.**
