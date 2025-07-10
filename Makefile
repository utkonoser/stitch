# Makefile для пайплайна конвертации изображений в формат вышивки

.PHONY: help install-deps install-macos install-ubuntu install-centos install-fedora install-arch install-brew install-apt install-dnf install-yum install-pacman test clean

# Цвета для вывода
GREEN = \033[0;32m
YELLOW = \033[1;33m
RED = \033[0;31m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Определение ОС
UNAME_S := $(shell uname -s)
DISTRO := $(shell if [ -f /etc/os-release ]; then grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"'; fi)

help: ## Показать справку
	@echo "$(BLUE)Пайплайн конвертации изображений в формат вышивки$(NC)"
	@echo ""
	@echo "$(GREEN)Доступные команды:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Примеры использования:$(NC)"
	@echo "  make install-deps    # Установить зависимости"
	@echo "  make test            # Протестировать пайплайн"
	@echo "  ./pipeline.sh pictures/rabbit.png  # Запустить конвертацию"

install-deps: ## Установить зависимости (автоопределение ОС)
	@echo "$(BLUE)Определяем операционную систему...$(NC)"
ifeq ($(UNAME_S),Darwin)
	@echo "$(GREEN)Обнаружена macOS$(NC)"
	$(MAKE) install-macos
else ifeq ($(UNAME_S),Linux)
	@echo "$(GREEN)Обнаружен Linux$(NC)"
	@echo "$(BLUE)Определяем дистрибутив...$(NC)"
ifeq ($(DISTRO),ubuntu)
	$(MAKE) install-ubuntu
else ifeq ($(DISTRO),debian)
	$(MAKE) install-ubuntu
else ifeq ($(DISTRO),centos)
	$(MAKE) install-centos
else ifeq ($(DISTRO),fedora)
	$(MAKE) install-fedora
else ifeq ($(DISTRO),arch)
	$(MAKE) install-arch
else
	@echo "$(RED)Неизвестный дистрибутив Linux: $(DISTRO)$(NC)"
	@echo "$(YELLOW)Попробуйте установить вручную:$(NC)"
	@echo "  Ubuntu/Debian: sudo apt-get install potrace imagemagick"
	@echo "  CentOS/RHEL: sudo yum install potrace ImageMagick"
	@echo "  Fedora: sudo dnf install potrace ImageMagick"
	@echo "  Arch: sudo pacman -S potrace imagemagick"
endif
else
	@echo "$(RED)Неподдерживаемая операционная система: $(UNAME_S)$(NC)"
	@echo "$(YELLOW)Установите зависимости вручную:$(NC)"
	@echo "  macOS: brew install potrace imagemagick"
	@echo "  Ubuntu/Debian: sudo apt-get install potrace imagemagick"
	@echo "  CentOS/RHEL: sudo yum install potrace ImageMagick"
	@echo "  Fedora: sudo dnf install potrace ImageMagick"
	@echo "  Arch: sudo pacman -S potrace imagemagick"
endif

install-macos: ## Установить зависимости на macOS
	@echo "$(BLUE)Устанавливаем зависимости на macOS...$(NC)"
	@if ! command -v brew &> /dev/null; then \
		echo "$(RED)Homebrew не установлен. Установите его с https://brew.sh$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Устанавливаем potrace...$(NC)"
	@brew install potrace
	@echo "$(GREEN)Устанавливаем imagemagick...$(NC)"
	@brew install imagemagick
	@echo "$(GREEN)Зависимости установлены!$(NC)"

install-ubuntu: ## Установить зависимости на Ubuntu/Debian
	@echo "$(BLUE)Устанавливаем зависимости на Ubuntu/Debian...$(NC)"
	@echo "$(GREEN)Обновляем список пакетов...$(NC)"
	@sudo apt-get update
	@echo "$(GREEN)Устанавливаем potrace...$(NC)"
	@sudo apt-get install -y potrace
	@echo "$(GREEN)Устанавливаем imagemagick...$(NC)"
	@sudo apt-get install -y imagemagick
	@echo "$(GREEN)Зависимости установлены!$(NC)"

install-centos: ## Установить зависимости на CentOS/RHEL
	@echo "$(BLUE)Устанавливаем зависимости на CentOS/RHEL...$(NC)"
	@echo "$(GREEN)Устанавливаем potrace...$(NC)"
	@sudo yum install -y potrace
	@echo "$(GREEN)Устанавливаем ImageMagick...$(NC)"
	@sudo yum install -y ImageMagick
	@echo "$(GREEN)Зависимости установлены!$(NC)"

install-fedora: ## Установить зависимости на Fedora
	@echo "$(BLUE)Устанавливаем зависимости на Fedora...$(NC)"
	@echo "$(GREEN)Устанавливаем potrace...$(NC)"
	@sudo dnf install -y potrace
	@echo "$(GREEN)Устанавливаем ImageMagick...$(NC)"
	@sudo dnf install -y ImageMagick
	@echo "$(GREEN)Зависимости установлены!$(NC)"

install-arch: ## Установить зависимости на Arch Linux
	@echo "$(BLUE)Устанавливаем зависимости на Arch Linux...$(NC)"
	@echo "$(GREEN)Устанавливаем potrace...$(NC)"
	@sudo pacman -S --noconfirm potrace
	@echo "$(GREEN)Устанавливаем imagemagick...$(NC)"
	@sudo pacman -S --noconfirm imagemagick
	@echo "$(GREEN)Зависимости установлены!$(NC)"

check-deps: ## Проверить установленные зависимости
	@echo "$(BLUE)Проверяем зависимости...$(NC)"
	@if command -v potrace &> /dev/null; then \
		echo "$(GREEN)✓ potrace установлен$(NC)"; \
	else \
		echo "$(RED)✗ potrace не найден$(NC)"; \
		exit 1; \
	fi
	@if command -v convert &> /dev/null; then \
		echo "$(GREEN)✓ imagemagick (convert) установлен$(NC)"; \
	else \
		echo "$(RED)✗ imagemagick (convert) не найден$(NC)"; \
		exit 1; \
	fi
	@if command -v vpype &> /dev/null; then \
		echo "$(GREEN)✓ vpype установлен$(NC)"; \
	else \
		echo "$(YELLOW)⚠ vpype не найден. Активируйте виртуальное окружение:$(NC)"; \
		echo "  source venv_pipeline/bin/activate"; \
	fi
	@echo "$(GREEN)Все зависимости проверены!$(NC)"

test: check-deps ## Протестировать пайплайн
	@echo "$(BLUE)Тестируем пайплайн...$(NC)"
	@if [ ! -f "pictures/rabbit.png" ]; then \
		echo "$(RED)Тестовый файл pictures/rabbit.png не найден$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Запускаем тестовую конвертацию...$(NC)"
	@./pipeline.sh pictures/rabbit.png
	@if [ -f "pictures/rabbit.dst" ]; then \
		echo "$(GREEN)✓ Тест успешен! Создан файл pictures/rabbit.dst$(NC)"; \
	else \
		echo "$(RED)✗ Тест не удался$(NC)"; \
		exit 1; \
	fi

setup-python: ## Настроить Python окружение
	@echo "$(BLUE)Настраиваем Python окружение...$(NC)"
	@if [ ! -d "venv_pipeline" ]; then \
		echo "$(GREEN)Создаем виртуальное окружение...$(NC)"; \
		python3.11 -m venv venv_pipeline; \
	fi
	@echo "$(GREEN)Активируем виртуальное окружение...$(NC)"
	@source venv_pipeline/bin/activate && pip install vpype vpype-embroidery
	@echo "$(GREEN)Python окружение настроено!$(NC)"
	@echo "$(YELLOW)Не забудьте активировать окружение:$(NC)"
	@echo "  source venv_pipeline/bin/activate"

setup: install-deps setup-python ## Полная настройка проекта
	@echo "$(GREEN)Проект полностью настроен!$(NC)"
	@echo "$(YELLOW)Для запуска пайплайна:$(NC)"
	@echo "  source venv_pipeline/bin/activate"
	@echo "  ./pipeline.sh pictures/rabbit.png"

clean: ## Очистить временные файлы
	@echo "$(BLUE)Очищаем временные файлы...$(NC)"
	@find . -name "*.pbm" -delete
	@find . -name "*.svg" -delete
	@find . -name "*.dst" -delete
	@echo "$(GREEN)Временные файлы удалены!$(NC)"

install-brew: ## Установить Homebrew (macOS)
	@echo "$(BLUE)Устанавливаем Homebrew...$(NC)"
	@/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	@echo "$(GREEN)Homebrew установлен!$(NC)"

install-apt: ## Установить apt (Ubuntu/Debian)
	@echo "$(BLUE)Обновляем apt...$(NC)"
	@sudo apt-get update
	@echo "$(GREEN)apt обновлен!$(NC)"

install-dnf: ## Установить dnf (Fedora)
	@echo "$(BLUE)Обновляем dnf...$(NC)"
	@sudo dnf update -y
	@echo "$(GREEN)dnf обновлен!$(NC)"

install-yum: ## Установить yum (CentOS/RHEL)
	@echo "$(BLUE)Обновляем yum...$(NC)"
	@sudo yum update -y
	@echo "$(GREEN)yum обновлен!$(NC)"

install-pacman: ## Установить pacman (Arch)
	@echo "$(BLUE)Обновляем pacman...$(NC)"
	@sudo pacman -Syu --noconfirm
	@echo "$(GREEN)pacman обновлен!$(NC)" 