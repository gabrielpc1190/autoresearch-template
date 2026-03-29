#!/bin/bash
set -e

# ==============================================================================
# ⚙️ ZONA DE CONFIGURACIÓN
# ==============================================================================
MODELO_LLM="ollama/qwen2.5-coder:7b"
ARCHIVOS_OBJETIVO="reycom.sh"
COMANDO_TEST="./reycom.sh client 'Gabriel Paniagua' --quick"
PRESUPUESTO=10
# ==============================================================================

# 1. Validaciones y Entorno
source .aider-env/bin/activate
export OLLAMA_API_BASE="http://localhost:11434"

# 2. Creación forzada del Laboratorio (Zero Trust sobre el LLM)
echo "[+] Forzando creación de infraestructura .lab/"
mkdir -p .lab
touch .lab/log.md .lab/results.tsv

# 3. Bucle Férreo de Experimentación (Controlado por Bash)
for ITER in $(seq 1 $PRESUPUESTO); do
    echo "==================================================================="
    echo "🧪 INICIANDO EXPERIMENTO $ITER / $PRESUPUESTO"
    echo "==================================================================="
    
    # FASE A: THINK & EDIT (Delegado a Aider)
    aider \
      --model "$MODELO_LLM" \
      --file $ARCHIVOS_OBJETIVO .lab/log.md \
      --read researcher.md \
      --no-show-model-warnings \
      --yes-always \
      --message "Iteración $ITER.
      OBJETIVO: Optimizar el tiempo de ejecución del script.
      REGLA 1: Modifica reycom.sh usando código real, no alucines acciones.
      REGLA 2: Escribe en .lab/log.md qué intentaste hacer.
      Haz una sola modificación y termina tu turno."

    # FASE B: TEST & REFLECT (Controlado por Bash)
    echo "[+] Evaluando el experimento $ITER empíricamente..."
    
    START_TIME=$(date +%s%N)
    # Ejecutamos silenciando la salida para no ensuciar la consola, solo queremos el exit code
    if eval "$COMANDO_TEST" > /dev/null 2>&1; then
        END_TIME=$(date +%s%N)
        DURATION=$(( (END_TIME - START_TIME) / 1000000 ))
        
        echo "[√] ÉXITO: El script no se rompió. Latencia: ${DURATION}ms"
        echo "$ITER|KEEP|${DURATION}ms" >> .lab/results.tsv
    else
        echo "[X] FALLO: El experimento rompió el script. Ejecutando Rollback."
        git reset --hard HEAD~1
        echo "$ITER|DISCARD|ERROR" >> .lab/results.tsv
    fi
    
    echo "Experimento $ITER finalizado. Pausa de 2 segundos para enfriamiento de GPU..."
    sleep 2
done

echo "[√] Bucle Autónomo Finalizado. Revisa .lab/results.tsv"
