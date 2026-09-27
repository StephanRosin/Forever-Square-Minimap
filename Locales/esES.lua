local _, ns = ...

-- Also used for Latin American Spanish clients (esMX), see Locale.lua.
local L = {}
ns.Locales.esES = L

L.ADDON_NAME = "Forever Square Minimap"

L.MSG_RESET = "Tamaño restablecido a %d px."
L.MSG_MOVED = "Mapa desplazado: %s px en horizontal, %s px en vertical."
L.MSG_COLUMN = "Columna de botones: %s px en horizontal, %s px en vertical."
L.MSG_POSITIVE = "Los valores positivos van hacia la derecha o hacia arriba."
L.MSG_SIZE = "Tamaño: %d px"
L.MSG_STATUS = "Actualmente %d px. Mantén Ctrl y arrastra la esquina inferior izquierda para cambiar el tamaño."
L.MSG_LAST_PROFILE = "No se puede eliminar el último perfil."

L.GRIP_HINT = "Ctrl + arrastrar con el botón izquierdo: cambiar tamaño"
L.GRIP_CURRENT = "Actual: %d px"
L.DUMP_HINT = "Ctrl+A, Ctrl+C para copiar. Esc cierra."

L.OPT_HINT = "Arrastra para valores aproximados, escribe para valores exactos (confirma con Intro)."
L.OPT_LANGUAGE = "Idioma"
L.LANGUAGE_AUTO = "Idioma del juego"
L.OPT_MAP = "Mapa"
L.OPT_SIZE = "Tamaño"
L.OPT_MOVE_X = "Desplazar en horizontal"
L.OPT_MOVE_Y = "Desplazar en vertical"
L.OPT_BORDER = "Borde"
L.OPT_BORDER_STYLE = "Estilo"
L.BORDER_NONE = "Ninguno"
L.BORDER_FLAT = "Liso"
L.BORDER_GOLD = "Dorado"
L.OPT_BORDER_SIZE = "Grosor"
L.OPT_BORDER_COLOR = "Color (solo liso)"
L.OPT_COLUMN = "Columna de botones"
L.OPT_COLUMN_X = "Horizontal"
L.OPT_COLUMN_Y = "Vertical"
L.OPT_PERF = "FPS y latencia"
L.OPT_PERF_SHOW = "Mostrar"
L.OPT_PROFILE = "Perfil"
L.OPT_PROFILE_ACTIVE = "Perfil activo"
L.OPT_PROFILE_SAVE_AS = "Guardar como..."
L.OPT_PROFILE_DELETE = "Eliminar"
L.POPUP_PROFILE_NAME = "Nombre del nuevo perfil:"
L.POPUP_PROFILE_DELETE = "¿Eliminar de verdad el perfil «%s»?"
