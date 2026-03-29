# 🧪 Autoresearch Bootstrapper (Laboratorio de IA Portátil)

Convierte tu máquina local en un laboratorio automatizado donde un Agente de Inteligencia Artificial (LLM) optimiza, refactoriza o repara tu código de forma 100% autónoma y segura.

## 💡 ¿Qué es esto?

Normalmente, usar herramientas de IA para programar requiere que estés copiando, pegando y probando el código manualmente. 

El **Autoresearch Bootstrapper** (`init_lab.sh`) es un script "Plug & Play" que automatiza ese proceso aplicando el método científico. Tú le das un código que quieres mejorar, defines cómo evaluar el éxito (un comando de prueba), y te vas a tomar un café. 

El sistema creará un entorno seguro y ejecutará un bucle de intentos (experimentos) donde la IA propone un cambio, el sistema lo prueba en milisegundos y, si el código se rompe, revierte los cambios automáticamente.

## ⚙️ ¿Cómo funciona? (La Arquitectura "Zero Trust")

El script funciona bajo un principio donde **Bash es el Director** y **la IA es el Operario**:

1. **Aislamiento:** El script verifica tus dependencias y crea un entorno virtual de Python (`.aider-env`) y una carpeta de laboratorio (`.lab/`) para no ensuciar tu sistema.
2. **Snapshot de Seguridad:** Usa Git para hacer una copia de seguridad de tu código antes de empezar.
3. **El Bucle Férreo (THINK -> TEST -> REFLECT):**
   - **Bash llama a la IA:** Le pide que haga *un solo cambio* basado en tu objetivo.
   - **Bash evalúa a la IA:** Ejecuta el comando de prueba que tú definiste (ej. `./mi_script.sh --test`).
   - **Decisión:** Si la prueba es exitosa (Exit 0), se guarda el cambio (`KEEP`) y se mide si fue más rápido. Si el código falla, Bash ejecuta un `git reset` inmediato descartando el error (`DISCARD`).
4. **Reporte:** Al finalizar los intentos, te entrega un archivo `results.tsv` con la bitácora de qué funcionó y qué no.

## 🛠️ Requisitos Previos

Necesitas tener instaladas tres herramientas estándar en tu máquina:
* **Git** (Para el control de versiones y rollbacks).
* **Python 3** (Para el entorno virtual del agente orquestador `aider`).
* **Ollama** (Para ejecutar el modelo de IA localmente. Se recomienda tener descargado el modelo ejecutando: `ollama run llama3.1:8`).

## 🚀 Guía de Uso Rápido

### Paso 1: Preparar la carpeta
Clona este repositorio o copia el archivo `init_lab.sh` en la misma carpeta donde tienes el script o código que deseas mejorar.

### Paso 2: Configurar la misión
Abre el archivo `init_lab.sh` con tu editor de texto favorito (Nano, Vim, VSCode) y busca la **ZONA DE CONFIGURACIÓN** en las primeras líneas. Solo necesitas editar estas 5 variables:

```bash
MODELO_LLM="ollama/qwen2.5-coder:7b"      # El modelo que usará la IA
ARCHIVOS_OBJETIVO="mi_script.py"          # El archivo que quieres que la IA mejore
COMANDO_TEST="python3 mi_script.py"       # El comando para probar que el código funciona
OBJETIVO="Haz que el código se ejecute más rápido usando paralelización." # Qué quieres lograr
PRESUPUESTO=10                            # Cuántos intentos le darás a la IA
