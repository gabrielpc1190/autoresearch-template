#!/bin/bash
set -e

# ==============================================================================
# ⚙️ ZONA DE CONFIGURACIÓN
# ==============================================================================
MODELO_LLM="ollama/qwen2.5-coder:7b"
ARCHIVOS_OBJETIVO="reycom.sh"
COMANDO_TEST="./reycom.sh client 'Gabriel Paniagua' --quick"
OBJETIVO="Optimizar el tiempo de ejecución del script de MikroTik."
PRESUPUESTO=10
TIMEOUT_S=300   # Tiempo máximo por experimento en segundos (5 min por defecto)
# ==============================================================================

# 1. Validaciones de dependencias
for cmd in git python3; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] ERROR: '$cmd' no está instalado o no está en PATH." >&2
        exit 1
    fi
done

# 2. Entorno virtual (se crea si no existe)
if [ ! -d ".aider-env" ]; then
    echo "[+] Creando entorno virtual .aider-env ..."
    python3 -m venv .aider-env
    .aider-env/bin/pip install --quiet aider-chat
fi
source .aider-env/bin/activate
export OLLAMA_API_BASE="http://localhost:11434"

# Verificar aider después de activar el entorno
if ! command -v aider &>/dev/null; then
    echo "[!] ERROR: 'aider' no está disponible en el entorno virtual." >&2
    exit 1
fi

# 3. Gestión del .gitignore
if ! grep -qxF ".lab/" .gitignore 2>/dev/null; then
    echo ".lab/" >> .gitignore
fi
if ! grep -qxF "run.log" .gitignore 2>/dev/null; then
    echo "run.log" >> .gitignore
fi

# 4. Setup del Laboratorio — Fase 2 (solo si es primera ejecución)
if [ ! -d ".lab" ]; then
    echo "[+] Inicializando laboratorio .lab/ ..."
    mkdir -p .lab/workspace

    cat > .lab/config.md <<EOF
# Lab Config

- **Objective:** $OBJETIVO
- **Files in scope:** $ARCHIVOS_OBJETIVO
- **Run command:** $COMANDO_TEST
- **Model:** $MODELO_LLM
- **Budget:** $PRESUPUESTO experiments
- **Timeout per experiment:** ${TIMEOUT_S}s
- **Primary metric:** execution time in ms (lower is better)
- **Baseline:** TBD (experiment #0)
- **Best:** TBD
EOF

    # Encabezado TSV con todas las columnas requeridas por researcher.md
    printf "experiment\tbranch\tparent\tcommit\tmetric\tstatus\tduration_s\tdescription\n" > .lab/results.tsv
    touch .lab/log.md .lab/parking-lot.md

    BRANCH_INIT=$(git rev-parse --abbrev-ref HEAD)
    cat > .lab/branches.md <<EOF
| Branch | Forked from | Status | Experiments | Best metric | Notes |
|--------|-------------|--------|-------------|-------------|-------|
| $BRANCH_INIT | HEAD | active | 0 | TBD | initial branch |
EOF

    echo "[+] Laboratorio inicializado en .lab/"
fi

BRANCH=$(git rev-parse --abbrev-ref HEAD)

# 5. Experimento #0: Baseline (sin cambios — una sola vez)
if ! grep -qP "^0\t" .lab/results.tsv 2>/dev/null; then
    echo "[+] Midiendo baseline (experimento #0, sin cambios)..."
    BASELINE_COMMIT=$(git rev-parse --short HEAD)
    BASELINE_START=$(date +%s%N)

    if timeout "$TIMEOUT_S" bash -c "$COMANDO_TEST" > run.log 2>&1; then
        BASELINE_END=$(date +%s%N)
        BASELINE_MS=$(( (BASELINE_END - BASELINE_START) / 1000000 ))
        BASELINE_S=$(awk "BEGIN{printf \"%.3f\", $BASELINE_MS/1000}")

        printf "0\t%s\t-\t%s\t%sms\tkeep\t%s\tbaseline\n" \
            "$BRANCH" "$BASELINE_COMMIT" "$BASELINE_MS" "$BASELINE_S" >> .lab/results.tsv

        {
            echo ""
            echo "## Experiment 0 — Baseline"
            echo "Branch: $BRANCH / Type: real / Parent: - / Hypothesis: baseline measurement"
            echo "Result: ${BASELINE_MS}ms / Duration: ${BASELINE_S}s / Status: keep"
        } >> .lab/log.md

        # Actualizar config.md con valores reales del baseline
        sed -i "s/- \*\*Baseline:\*\* TBD.*/- **Baseline:** ${BASELINE_MS}ms/" .lab/config.md
        sed -i "s/- \*\*Best:\*\* TBD.*/- **Best:** ${BASELINE_MS}ms/" .lab/config.md

        echo "[√] Baseline: ${BASELINE_MS}ms"
    else
        printf "0\t%s\t-\t%s\tERROR\tcrash\t0\tbaseline failed — verifica COMANDO_TEST\n" \
            "$BRANCH" "$BASELINE_COMMIT" >> .lab/results.tsv
        echo "[!] ADVERTENCIA: El baseline falló. Verifica COMANDO_TEST antes de continuar." >&2
    fi
fi

# 6. Bucle Férreo de Experimentación: THINK → TEST → REFLECT (Karpathy Autoresearch)
for ITER in $(seq 1 $PRESUPUESTO); do
    PARENT_ITER=$((ITER - 1))

    echo "==================================================================="
    echo "🧪 EXPERIMENTO $ITER / $PRESUPUESTO"
    echo "==================================================================="

    # FASE A: THINK & EDIT (Delegado a Aider)
    aider \
      --model "$MODELO_LLM" \
      --file "$ARCHIVOS_OBJETIVO" ".lab/log.md" \
      --read "researcher.md" "Karpathy Rules.md" \
      --no-show-model-warnings \
      --yes-always \
      --message "Iteración $ITER / $PRESUPUESTO.

OBJETIVO: $OBJETIVO

REGLA 1 (Simplicity First): Haz UNA sola modificación a $ARCHIVOS_OBJETIVO usando código real y concreto. No alucines acciones.
REGLA 2 (Surgical Changes): Toca solo lo necesario. No refactorices código que no está roto.
REGLA 3 (Log): Registra en .lab/log.md con el formato exacto:
  ## Experiment $ITER — <título descriptivo>
  Branch: $BRANCH / Type: real / Parent: #$PARENT_ITER / Hypothesis: <hipótesis de una línea>
  Changes: <qué modificaste> / Insight: <observación>
REGLA 4 (No commit): NO hagas git commit. El script orquestador maneja el control de versiones."

    # Verificar si Aider realizó cambios
    if git diff --quiet HEAD -- "$ARCHIVOS_OBJETIVO"; then
        echo "[~] Aider no realizó cambios en $ARCHIVOS_OBJETIVO. Registrando como thought."
        printf "%d\t%s\t%d\t%s\t-\tthought\t0\tno changes made\n" \
            "$ITER" "$BRANCH" "$PARENT_ITER" "$(git rev-parse --short HEAD)" >> .lab/results.tsv
        continue
    fi

    # FASE B: COMMIT ANTES DE EJECUTAR (regla crítica de Karpathy Autoresearch)
    # Cada experimento queda registrado en git antes de medirse.
    # Los keeps permanecen en el branch; los discards se revierten con reset --hard HEAD~1
    # pero su SHA queda en results.tsv para poder hacer fork desde él.
    git add "$ARCHIVOS_OBJETIVO" ".lab/log.md"
    git commit -m "experiment #$ITER: hypothesis by aider

Branch: $BRANCH
Parent: #$PARENT_ITER
Hypothesis: LLM-proposed change for: $OBJETIVO"

    COMMIT_SHA=$(git rev-parse --short HEAD)

    # FASE C: TEST — Bash como árbitro objetivo
    echo "[+] Evaluando experimento $ITER empíricamente..."
    START_TIME=$(date +%s%N)

    if timeout "$TIMEOUT_S" bash -c "$COMANDO_TEST" > run.log 2>&1; then
        END_TIME=$(date +%s%N)
        DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        DURATION_S=$(awk "BEGIN{printf \"%.3f\", $DURATION_MS/1000}")

        echo "[√] ÉXITO: Latencia: ${DURATION_MS}ms — KEEP"
        printf "%d\t%s\t%d\t%s\t%sms\tkeep\t%s\tLLM iteration\n" \
            "$ITER" "$BRANCH" "$PARENT_ITER" "$COMMIT_SHA" "$DURATION_MS" "$DURATION_S" >> .lab/results.tsv

        # Añadir resultado medido al log (sin modificar lo que escribió aider)
        echo "Result: ${DURATION_MS}ms / Duration: ${DURATION_S}s / Status: keep" >> .lab/log.md
    else
        END_TIME=$(date +%s%N)
        DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))
        DURATION_S=$(awk "BEGIN{printf \"%.3f\", $DURATION_MS/1000}")

        echo "[X] FALLO: El experimento rompió el script — DISCARD + Rollback"
        printf "%d\t%s\t%d\t%s\t0\tdiscard\t%s\ttest failed — rolled back\n" \
            "$ITER" "$BRANCH" "$PARENT_ITER" "$COMMIT_SHA" "$DURATION_S" >> .lab/results.tsv

        # Añadir resultado medido al log (sin modificar lo que escribió aider)
        echo "Result: FAIL / Duration: ${DURATION_S}s / Status: discard" >> .lab/log.md

        # El commit desaparece del branch pero su SHA queda en results.tsv
        git reset --hard HEAD~1
    fi

    echo "[+] Experimento $ITER finalizado. Pausa de 2 segundos..."
    sleep 2
done

echo ""
echo "[√] Bucle Autónomo Finalizado."
echo ""
echo "=== RESUMEN DE EXPERIMENTOS ==="
column -t -s $'\t' .lab/results.tsv
echo ""
echo "Historial completo en .lab/results.tsv | Log detallado en .lab/log.md"
