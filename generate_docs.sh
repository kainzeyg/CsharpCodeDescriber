#!/bin/bash

MODEL="deepseek-coder-6.7b-instruct.Q4_K_M.gguf"
INPUT_DIR="./input"
OUTPUT_DIR="./output"

[ ! -d "$INPUT_DIR" ] && { echo "Ошибка: папка $INPUT_DIR не найдена" >&2; exit 1; }
cs_files=("$INPUT_DIR"/*.cs)
[ ${#cs_files[@]} -eq 0 ] && { echo "Ошибка: нет .cs файлов в $INPUT_DIR" >&2; exit 1; }
mkdir -p "$OUTPUT_DIR"

for INPUT_FILE in "${cs_files[@]}"; do
    FILENAME=$(basename "$INPUT_FILE")
    BASENAME="${FILENAME%.cs}"
    OUTPUT_FILE="$OUTPUT_DIR/$BASENAME.md"
    RAW_LOG="$OUTPUT_DIR/$BASENAME.raw"

    echo "Обработка: $FILENAME -> ${BASENAME}.md"

    CODE_CONTENT=$(head -n 250 "$INPUT_FILE")
    CODE_LENGTH=${#CODE_CONTENT}

    TOKEN_LENGTH=$((CODE_LENGTH + 200))
    MAX_TOKENS=1200
    [ $TOKEN_LENGTH -gt $MAX_TOKENS ] && TOKEN_LENGTH=$MAX_TOKENS

    PROMPT=$(cat <<EOF
Ниже представлен C#-код. Сгенерируй подробную документацию в формате Markdown, строго по структуре:

# Название класса
## Назначение
## Конструктор
## Методы
## Пример
## Примечание

Описание должно начинаться строго с заголовка '# Название класса'. Не включай исходный код и текст этого задания. Не добавляй тесты, чек-листы, интерфейсы, анализ кода, никаких 'дополнительно' и т. п.
Ответ должен завершиться после раздела '## Примечание'.

Код:

$CODE_CONTENT

Документация:
EOF
)

    echo "Длина кода: $CODE_LENGTH символов, установлено -n $TOKEN_LENGTH"

    RAW_OUTPUT=$(docker run --rm \
        -v "$(pwd)/models:/models" \
        -v "$(pwd)/output:/output" \
        ghcr.io/ggml-org/llama.cpp:full \
        --run \
        -m "/models/$MODEL" \
        -p "$PROMPT" \
        -n $TOKEN_LENGTH \
        --temp 0.4)

    echo "$RAW_OUTPUT" > "$RAW_LOG"
    echo "Raw сохранён в: $RAW_LOG"

    PROMPT_LENGTH=${#PROMPT}
    TRIMMED_OUTPUT="${RAW_OUTPUT:$PROMPT_LENGTH}"

    FINAL=$(echo "$TRIMMED_OUTPUT" | awk '
        BEGIN { found_note = 0; cut = 0 }
        {
            if (cut == 1) next
            if ($0 ~ /^##[[:space:]]*Примечание/) { found_note = 1 }
            else if (found_note && ($0 ~ /^```/ || $0 ~ /^"""/ || $0 ~ /^---/ || $0 ~ /^***/ || $0 ~ /^\*\//)) { cut = 1; next }
            print
        }
    ')

    echo "$FINAL" > "$OUTPUT_FILE"
    echo "Документация создана: $OUTPUT_FILE"
done

echo "Готово! Документация в: $OUTPUT_DIR"
