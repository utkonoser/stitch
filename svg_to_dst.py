import glob
import sys
import argparse
import os
from pyembroidery import *
from svgelements import *
import math

def offset_point(p1, p2, distance):
    """Смещает точку p1 относительно p2 на расстояние distance перпендикулярно линии p1-p2"""
    dx = p2[0] - p1[0]
    dy = p2[1] - p1[1]
    length = math.hypot(dx, dy)
    if length == 0:
        return (p1[0], p1[1])
    # Перпендикулярный вектор
    ox = -dy / length * distance
    oy = dx / length * distance
    return (p1[0] + ox, p1[1] + oy)

def offset_polyline(points, offset):
    """Строит смещённую копию ломаной линии (polyline) на заданное расстояние offset"""
    if len(points) < 2:
        return points[:]
    offset_points = []
    for i in range(len(points)):
        if i == 0:
            p = offset_point(points[i], points[i+1], offset)
        elif i == len(points)-1:
            p = offset_point(points[i], points[i-1], offset)
        else:
            p1 = offset_point(points[i], points[i-1], offset)
            p2 = offset_point(points[i], points[i+1], offset)
            # Среднее между двумя смещениями
            p = ((p1[0]+p2[0])/2, (p1[1]+p2[1])/2)
        offset_points.append(p)
    return offset_points

def process_element(element, pattern, fill_type="none", fill_spacing=2.0, contour_step=10.0, contour_width=1):
    """Рекурсивно обрабатывает элемент SVG"""
    if isinstance(element, Group):
        print(f"    Обрабатываем группу с {len(element)} элементами")
        for child in element:
            process_element(child, pattern, fill_type, fill_spacing, contour_step, contour_width)
    elif isinstance(element, Shape):
        element = Path(element)
        process_path(element, pattern, fill_type, fill_spacing, contour_step, contour_width)
    elif isinstance(element, Path):
        process_path(element, pattern, fill_type, fill_spacing, contour_step, contour_width)
    else:
        print(f"    Неизвестный тип элемента: {type(element).__name__}")

def process_path(path, pattern, fill_type="none", fill_spacing=2.0, contour_step=10.0, contour_width=1):
    """Обрабатывает Path элемент"""
    subpaths = list(path.as_subpaths())
    print(f"    Найдено подпутей: {len(subpaths)}")
    
    for j, subpath in enumerate(subpaths):
        subpath = Path(subpath)
        print(f"      Подпуть {j+1}: длина={subpath.length()}, замкнут={subpath.closed}")
        
        # Проверяем, замкнут ли контур и нужна ли заливка
        # Удаляем код заливки
        # Добавляем контур (обводку)
        distance = subpath.length(error=1e7, min_depth=4)
        if distance > 0:
            segments = int(distance / contour_step)
            if segments > 0:
                base_points = [subpath.point(i / float(segments)) for i in range(int(segments)+1)]
                base_points = [(p.x, p.y) for p in base_points if p is not None]
                if len(base_points) > 1:
                    if len(base_points) > 2 or (len(base_points) == 2 and abs(base_points[1][0] - base_points[0][0]) + abs(base_points[1][1] - base_points[0][1]) > 1):
                        # Рисуем несколько параллельных линий
                        if contour_width <= 1:
                            pattern.add_block(base_points, subpath.stroke)
                            print(f"      Добавлен контур с {len(base_points)} точками (ширина 1)")
                        else:
                            step = 1.0  # шаг между линиями (можно сделать параметром)
                            n_lines = int(contour_width)
                            offsets = [((i - (n_lines-1)/2) * step) for i in range(n_lines)]
                            for k, offset in enumerate(offsets):
                                offset_pts = offset_polyline(base_points, offset)
                                pattern.add_block(offset_pts, subpath.stroke)
                            print(f"      Добавлено {n_lines} параллельных контуров (ширина {contour_width})")

def process_svg_file(svg_file, fill_type="none", fill_spacing=2.0, contour_step=10.0, contour_width=1):
    """Обрабатывает SVG файл с выбранным типом заливки"""
    pattern = EmbPattern()
    
    print(f"Обрабатываем SVG файл: {svg_file}")
    print(f"Тип заливки: {fill_type}, расстояние: {fill_spacing}, шаг дискретизации: {contour_step}, ширина: {contour_width}")
    
    try:
        # Пробуем без масштабирования сначала
        elements = list(SVG.parse(svg_file))
        print(f"Найдено элементов в SVG: {len(elements)}")
        
        for i, element in enumerate(elements):
            print(f"Обрабатываем элемент {i+1}: {type(element).__name__}")
            process_element(element, pattern, fill_type, fill_spacing, contour_step, contour_width)
        
        print(f"Всего блоков в паттерне: {len(pattern)}")
        if len(pattern) == 0:
            print("ПРЕДУПРЕЖДЕНИЕ: Паттерн не содержит стежков!")
            
    except Exception as e:
        print(f"Ошибка при обработке SVG: {e}")
        import traceback
        traceback.print_exc()
        raise
    
    return pattern

def main():
    parser = argparse.ArgumentParser(description='Конвертер SVG в DST без поддержки заливки')
    # Удаляем fill-type и fill-spacing
    parser.add_argument('--contour-step', type=float, default=2.0, help='Шаг дискретизации path (по умолчанию: 2.0)')
    parser.add_argument('--contour-width', type=int, default=1, help='Ширина линии (количество параллельных линий, по умолчанию: 1)')
    parser.add_argument('--svg-file', help='Конкретный SVG файл для обработки')
    
    args = parser.parse_args()
    
    if args.svg_file:
        # Обрабатываем конкретный файл
        if not args.svg_file.endswith('.svg'):
            print("Ошибка: файл должен иметь расширение .svg")
            sys.exit(1)
        
        pattern = process_svg_file(args.svg_file, 'none', 2.0, args.contour_step, args.contour_width)
        
        # Проверяем, что паттерн не пустой
        if len(pattern) == 0:
            print("ОШИБКА: Не удалось создать стежки из SVG!")
            sys.exit(1)
        
        # Создаём файл только с именем, без пути
        svg_filename = os.path.basename(args.svg_file)
        output_file = svg_filename.replace('.svg', '.dst')
        PyEmbroidery.write(pattern, output_file)
        print(f"Создан файл: {output_file}")
        print(f"Размер файла: {os.path.getsize(output_file)} байт")
    else:
        # Обрабатываем все SVG файлы в текущей директории
        for svg_file in glob.glob("*.svg"):
            pattern = process_svg_file(svg_file, 'none', 2.0, args.contour_step, args.contour_width)
            output_file = svg_file.replace('.svg', '.dst')
            PyEmbroidery.write(pattern, output_file)
            print(f"Создан файл: {output_file}")

if __name__ == "__main__":
    main()