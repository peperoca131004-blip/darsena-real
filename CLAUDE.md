# Notas para Claude · Dársena Real

Seguimiento de cuántas viviendas quedan libres en cada fase de la promoción
**Dársena Real** (Cartagena) de Urbincasa: <https://urbincasa.es/es/promocion/darsena-real-1886>.
El usuario habla español: responde en español y con explicaciones sencillas (no es programador).

## Qué hay montado

Hay **dos versiones** de la misma idea:

1. **Página pública en GitHub Pages** (este repositorio, `darsena-real`)
   - Enlace: <https://peperoca131004-blip.github.io/darsena-real/>
   - GitHub Actions (`.github/workflows/actualizar.yml`) lee la web cada día a las 07:15 UTC
     (08:15 invierno / 09:15 verano en Madrid), con `TZ: Europe/Madrid`, ejecutando
     `pwsh ./servidor.ps1 -SoloLeer`, y hace commit de `datos/historial.json` si cambió.
     También se puede lanzar a mano: Actions → *Actualizar disponibilidad* → *Run workflow*.
   - `index.html` es estático: hace `fetch('datos/historial.json')` y lo pinta (KPIs, tarjetas por
     fase con tablas de viviendas libres, gráfico SVG escalonado, registro de cambios).
     Si se abre sin http(s) (desde disco) muestra un aviso en vez de intentar cargar.
   - **Sin el logo de Urbincasa** a propósito, con el aviso "Seguimiento independiente, no es una
     página oficial de Urbincasa", para no suplantar a la marca. La foto lleva "Imagen: urbincasa.es".
     Mantener esto así.

2. **App local** (solo en el portátil original, carpeta `Escritorio\Claude Urbincasa\DarsenaTracker`,
   este repositorio es su subcarpeta `github\`)
   - `Iniciar.bat` arranca `servidor.ps1` (HttpListener en `http://localhost:8787`) y abre el navegador.
   - Panel local `index.html` con logo (`logo.png`) y foto (`foto.jpg`); rutas `/`, `/logo.png`,
     `/foto.jpg`, `/api/estado`, `/api/actualizar`.
   - `Programar-Diario.ps1` registra la tarea de Windows "Darsena Real - lectura diaria" (09:00,
     `servidor.ps1 -SoloLeer`); `-Quitar` la elimina, `-Hora` cambia la hora.
   - `Exportar-Compartible.ps1` exporta CSV a `compartir\` (se usó para un artifact de claude.ai,
     ya no se actualiza; la tarea programada de Claude que lo hacía está desactivada).
   - Su historial (`datos/historial.json`) es independiente del de GitHub.

## Cómo funciona la lectura (`servidor.ps1`)

- PowerShell (5.1 en Windows, `pwsh` en GitHub). En el portátil **no hay Node ni Python**.
- Descarga la página con WebClient en UTF-8 y la analiza con expresiones regulares:
  - Pestañas de fase: `id="tab3dbloqueN"`.
  - Sección de cada fase: `id="bloque3dbloqueN"`, con textos "Viviendas totales:" y "Disponibles:".
  - Viviendas libres: `<area ... data-disponible="1">` con `rel`, `data-referencia`, `data-planta`,
    `data-bedrooms`, `data-bathrooms`, `data-superficie`, `data-planos`, `data-url`.
- La web **no publica precios**.
- Funciones: `Read-Promocion`, `Read-Historial` (relee del disco antes de cada uso), `Save-Historial`,
  `Update-Datos` (solo añade registro si cambian las cifras; anota viviendas "ya no disponible" /
  "nueva disponible"), `Get-Estado`, `Send-Respuesta`.
- Parámetros: `-Puerto 8787`, `-SoloLeer` (una lectura y sale), `-HoraDiaria '09:00'`.
- Si Urbincasa cambia el diseño de su web, lo que fallará son esas regex: revisar el HTML real primero.

## Estado a 16/11/2026

6 fases, 55 libres de 147: Exterior 1 (0/23), Exterior 2 (2/18), Exterior 3 (2/12),
Interior 1 (0/25), Interior 2 (13/30), Exterior 4 (38/39).

## Herramientas en el portátil original

- Git y GitHub CLI portables (sin permisos de administrador):
  `%LOCALAPPDATA%\Programs\git-portable` (MinGit) y `%LOCALAPPDATA%\Programs\gh-portable`.
  Sesión de `gh` ya iniciada (con permiso `workflow`).
- En otro ordenador puede que no estén: usar GitHub Desktop, instalarlos, o trabajar desde claude.ai/code.

## Al hacer cambios

- GitHub Actions hace commits diarios: haz `git pull --rebase` antes de subir nada.
- No toques `datos/historial.json` a mano salvo que el usuario lo pida.
- Si cambias la lectura, cambia `servidor.ps1` aquí y en la app local (son la misma copia).
