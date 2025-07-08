#!/bin/bash

ARCHIVE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT_DIR="$SCRIPT_DIR/input"
OUTPUT_DIR="$SCRIPT_DIR/output"
GEN_SCRIPT="$SCRIPT_DIR/generate_docs.sh"
TMP_UNPACK_DIR="$SCRIPT_DIR/unpacked_tmp"

if [ -z "$ARCHIVE" ]; then
    echo "❌ Укажите архив проекта в качестве аргумента." >&2
    exit 1
fi

if [ ! -f "$ARCHIVE" ]; then
    echo "❌ Архив $ARCHIVE не найден." >&2
    exit 1
fi

# Распаковка во временную папку
rm -rf "$TMP_UNPACK_DIR"
mkdir -p "$TMP_UNPACK_DIR"
unzip -q "$ARCHIVE" -d "$TMP_UNPACK_DIR"

# Поиск всех .cs файлов
mapfile -t cs_files < <(find "$TMP_UNPACK_DIR" -type f -name "*.cs" | sort)

for full_cs_path in "${cs_files[@]}"; do
    rel_path="${full_cs_path#$TMP_UNPACK_DIR/}"             # относительный путь к файлу
    cs_filename="$(basename "$full_cs_path")"
    cs_basename="${cs_filename%.cs}"
    md_temp_file="$OUTPUT_DIR/$cs_basename.md"
    raw_temp_file="$OUTPUT_DIR/$cs_basename.raw"

    # Целевой путь для md-файла
    md_target_path="$OUTPUT_DIR/${rel_path%.cs}.md"

    if [ -f "$md_target_path" ]; then
        echo "✅ $rel_path — уже задокументирован, пропускаем."
        continue
    fi

    echo "🟡 Обработка: $rel_path"

    # Копируем файл в input/ при необходимости
    if [ ! -f "$INPUT_DIR/$cs_filename" ]; then
        cp "$full_cs_path" "$INPUT_DIR/$cs_filename"
    fi

    # Запуск генерации
    "$GEN_SCRIPT"

    # Проверка результата
    if [ ! -f "$md_temp_file" ]; then
        echo "⚠️ Не удалось найти $md_temp_file после генерации." >&2
        rm -f "$INPUT_DIR/$cs_filename"
        continue
    fi

    # Вставка заголовка
    header="/** \\file $rel_path
 *  \\brief Документация к файлу $cs_filename
 */"

    tmp_file=$(mktemp)
    echo "$header" > "$tmp_file"
    cat "$md_temp_file" >> "$tmp_file"
    mv "$tmp_file" "$md_temp_file"

    # Создание каталога и перемещение в нужную структуру
    target_dir="$(dirname "$md_target_path")"
    mkdir -p "$target_dir"
    mv "$md_temp_file" "$md_target_path"

    # Установка прав доступа
    chmod 777 "$md_target_path"

    echo "📄 Сформирован: $md_target_path (права 777)"

    # Удаление .raw
    rm -f "$raw_temp_file"

    # Очистка input
    rm -f "$INPUT_DIR/$cs_filename"

    echo
done

echo "✅ Обработка завершена. Все новые .cs-файлы задокументированы."
