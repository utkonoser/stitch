#!/bin/bash

# Пайплайн конвертации PNG → SVG → DST
set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    echo "Пайплайн конвертации PNG → SVG → DST"
    echo ""
    echo "Использование: $0 [опции] <входной_файл.png>"
    echo ""
    echo "Опции:"
    echo "  -o, --output FILE     Выходной DST файл (по умолчанию: <входной>.dst)"
    echo "  --keep-svg            Сохранить промежуточный SVG файл"
    echo "  --contour-step N      Шаг дискретизации path (по умолчанию: 10.0)"
    echo "  --contour-width N     Ширина контура в стежках (по умолчанию: 1)"
    echo "  -h, --help            Показать эту справку"
    echo ""
    echo "Примеры:"
    echo "  $0 image.png"
    echo "  $0 image.png --contour-step 5.0"
    echo "  $0 image.png --fill-type parallel --fill-spacing 3.0"
}

# Парсинг аргументов
INPUT_FILE=""
OUTPUT_FILE=""
KEEP_SVG=false
FILL_TYPE="none"
FILL_SPACING=2.0
CONTOUR_STEP=10.0
CONTOUR_WIDTH=1

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --keep-svg)
            KEEP_SVG=true
            shift
            ;;
        --fill-type)
            FILL_TYPE="$2"
            shift 2
            ;;
        --fill-spacing)
            FILL_SPACING="$2"
            shift 2
            ;;
        --contour-step)
            CONTOUR_STEP="$2"
            shift 2
            ;;
        --contour-width)
            CONTOUR_WIDTH="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -* )
            print_error "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
        * )
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            else
                print_error "Слишком много аргументов"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
    
    # Не забываем сдвигать аргументы, если не было shift выше
    if [[ "$1" != -* && -n "$1" ]]; then
        shift
    fi

done

# Проверяем входной файл
if [[ -z "$INPUT_FILE" ]]; then
    print_error "Не указан входной файл"
    show_help
    exit 1
fi
if [[ ! -f "$INPUT_FILE" ]]; then
    print_error "Входной файл не найден: $INPUT_FILE"
    exit 1
fi

# Определяем выходной файл если не указан
if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="${INPUT_FILE%.*}.dst"
fi
SVG_FILE="${INPUT_FILE%.*}.svg"
PBM_FILE="${INPUT_FILE%.*}.pbm"

print_info "ПАЙПЛАЙН КОНВЕРТАЦИИ PNG → SVG → DST"
print_info "=================================================="

# Проверяем наличие vpype
if ! command -v vpype &> /dev/null; then
    print_error "vpype не найден. Убедитесь, что он установлен и активировано виртуальное окружение"
    exit 1
fi

# Шаг 1: PNG/JPG/BMP/TIFF → PBM (для potrace)
print_info "Шаг 1: Конвертируем $INPUT_FILE в PBM..."
if magick "$INPUT_FILE" "$PBM_FILE"; then
    print_success "PBM файл создан: $PBM_FILE"
else
    print_error "Ошибка при создании PBM файла"
    exit 1
fi

print_info "Шаг 2: Трассируем PBM в SVG через potrace..."
if potrace "$PBM_FILE" -s -o "$SVG_FILE"; then
    print_success "SVG файл создан: $SVG_FILE"
else
    print_error "Ошибка при трассировке PBM в SVG"
    exit 1
fi

rm "$PBM_FILE"

# Проверяем параметры заливки
if [[ "$FILL_TYPE" != "none" && "$FILL_TYPE" != "parallel" ]]; then
    print_error "Неверный тип заливки: $FILL_TYPE. Допустимые значения: none, parallel"
    exit 1
fi

# Шаг 3: SVG → DST (через svg_to_dst.py)
print_info "Шаг 3: Конвертируем $SVG_FILE в DST..."
print_info "Тип заливки: $FILL_TYPE, расстояние: $FILL_SPACING, ширина контура: $CONTOUR_WIDTH"

# Переходим в директорию svg_to_dst и запускаем конвертер
cd svg_to_dst
if python3 svg_to_dst.py --svg-file "../$SVG_FILE" --contour-step "$CONTOUR_STEP" --contour-width "$CONTOUR_WIDTH"; then
    print_success "DST файл создан"
    # Перемещаем DST файл в нужное место
    DST_TEMP_FILE="$(basename "$SVG_FILE" .svg).dst"
    if [[ -f "$DST_TEMP_FILE" ]]; then
        mv "$DST_TEMP_FILE" "../$OUTPUT_FILE"
        print_success "DST файл перемещён: $OUTPUT_FILE"
    else
        print_error "DST файл не найден: $DST_TEMP_FILE"
        cd ..
        exit 1
    fi
else
    print_error "Ошибка при создании DST файла"
    cd ..
    exit 1
fi
cd ..

if [[ ! -f "$OUTPUT_FILE" ]]; then
    print_error "DST файл не создан: $OUTPUT_FILE"
    exit 1
fi

INPUT_SIZE=$(stat -f%z "$INPUT_FILE" 2>/dev/null || stat -c%s "$INPUT_FILE" 2>/dev/null || echo "неизвестно")
SVG_SIZE=$(stat -f%z "$SVG_FILE" 2>/dev/null || stat -c%s "$SVG_FILE" 2>/dev/null || echo "неизвестно")
DST_SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null || echo "неизвестно")

print_info "=================================================="
print_info "РЕЗУЛЬТАТ КОНВЕРТАЦИИ:"
print_info "Входной файл: $INPUT_FILE ($INPUT_SIZE байт)"
print_info "SVG файл: $SVG_FILE ($SVG_SIZE байт)"
print_info "DST файл: $OUTPUT_FILE ($DST_SIZE байт)"

if [[ "$KEEP_SVG" == false ]]; then
    print_info "Удаляем промежуточный SVG файл..."
    rm -f "$SVG_FILE"
else
    print_info "Промежуточный SVG файл сохранен: $SVG_FILE"
fi

print_success "=================================================="
print_success "🎉 Конвертация завершена успешно!"
print_success "Файл вышивки готов: $OUTPUT_FILE" 