# Dársena Real · disponibilidad de viviendas

Página que muestra cuántas viviendas quedan libres en cada fase del residencial Dársena Real (Cartagena).
GitHub lee cada día la web de la promoción y publica los datos con GitHub Pages.

Seguimiento independiente: no es una página oficial de Urbincasa.

## Contenido

| Archivo | Para qué sirve |
|---|---|
| `index.html` | La página que se publica |
| `foto.jpg` | Foto de cabecera (fuente: urbincasa.es) |
| `servidor.ps1` | Lee la web de la promoción y guarda `datos/historial.json` |
| `datos/historial.json` | Lecturas guardadas (lo actualiza GitHub cada día) |
| `.github/workflows/actualizar.yml` | Programa la lectura diaria |

## Cómo publicarlo (sin instalar nada)

1. **Crea una cuenta** en <https://github.com> si no tienes.
2. **Crea un repositorio:** botón **+** (arriba a la derecha) → **New repository**.
   - Nombre: `darsena-real`
   - Marca **Public** (GitHub Pages gratis lo necesita).
   - Pulsa **Create repository**.
3. **Sube los archivos:** en el repositorio vacío, pulsa el enlace **uploading an existing file**.
   Arrastra desde el Explorador de Windows: `index.html`, `foto.jpg`, `servidor.ps1`, `LEEME.md` y la carpeta `datos`.
   Abajo, pulsa **Commit changes**.
4. **Crea el archivo de la tarea diaria** (las carpetas que empiezan por punto a veces no se suben arrastrando):
   **Add file** → **Create new file**. En el nombre escribe exactamente `.github/workflows/actualizar.yml`,
   pega el contenido del archivo `.github\workflows\actualizar.yml` de esta carpeta (ábrelo con el Bloc de notas)
   y pulsa **Commit changes**.
5. **Permite que la tarea guarde datos:** **Settings** → **Actions** → **General** → al final,
   en *Workflow permissions*, elige **Read and write permissions** → **Save**.
6. **Activa la página:** **Settings** → **Pages** → en *Source* elige **Deploy from a branch**,
   rama **main** y carpeta **/ (root)** → **Save**.
7. **Haz la primera lectura:** pestaña **Actions** → **Actualizar disponibilidad** → **Run workflow** → **Run workflow**.
   En un minuto debería salir con un círculo verde.

A los pocos minutos tu enlace estará en **Settings → Pages**. Será algo así:
`https://TU-USUARIO.github.io/darsena-real/`

## Después

- Se actualiza solo cada día a las 08:15 (09:15 en horario de verano). Tu ordenador puede estar apagado.
- Para una lectura al momento: **Actions** → **Actualizar disponibilidad** → **Run workflow**.
- Si un día falla la lectura (por ejemplo, si la web de Urbincasa cambia su diseño), GitHub te avisa por correo
  y la página sigue mostrando la última lectura buena.
- GitHub pausa las tareas programadas de repositorios sin actividad durante 60 días. Como esta tarea guarda
  datos cada día, eso no debería pasar; si pasara, en **Actions** aparece un botón para reactivarla.
