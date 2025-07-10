import os
import subprocess
from telegram import Update, InputMediaDocument
from telegram.ext import ApplicationBuilder, CommandHandler, MessageHandler, filters, ContextTypes

from dotenv import load_dotenv
load_dotenv()

TOKEN = os.environ.get("BOT_TOKEN")
if not TOKEN:
    raise RuntimeError("Переменная окружения BOT_TOKEN не задана!")

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Привет! Пришли мне картинку (PNG/JPG), и я пришлю тебе SVG и DST для вышивки.")

async def handle_image(update: Update, context: ContextTypes.DEFAULT_TYPE):
    photo = update.message.photo[-1]
    file = await photo.get_file()
    input_path = f"input_{update.message.from_user.id}.png"
    await file.download_to_drive(input_path)

    svg_path = input_path.replace('.png', '.svg')
    dst_path = input_path.replace('.png', '.dst')

    try:
        # Запускаем пайплайн
        subprocess.run(["./pipeline.sh", input_path, "--keep-svg"], check=True)

        # Готовим файлы для отправки
        media = []
        info = []

        if os.path.exists(svg_path):
            size_svg = os.path.getsize(svg_path)
            media.append(InputMediaDocument(open(svg_path, "rb"), filename=os.path.basename(svg_path)))
            info.append(f"SVG: {os.path.basename(svg_path)} ({size_svg} байт)")
        if os.path.exists(dst_path):
            size_dst = os.path.getsize(dst_path)
            media.append(InputMediaDocument(open(dst_path, "rb"), filename=os.path.basename(dst_path)))
            info.append(f"DST: {os.path.basename(dst_path)} ({size_dst} байт)")

        # Отправляем инфо и файлы одним сообщением
        if media:
            await update.message.reply_text(
                f"Готово!\nПараметры:\n"
                f"Имя пользователя: {update.message.from_user.full_name}\n"
                f"Размер исходного файла: {os.path.getsize(input_path)} байт\n"
                + "\n".join(info)
            )
            await update.message.reply_media_group(media)
        else:
            await update.message.reply_text("Ошибка: не удалось создать файлы SVG/DST.")

    except Exception as e:
        await update.message.reply_text(f"Ошибка при обработке: {e}")
    finally:
        # Удаляем временные файлы
        for f in [input_path, svg_path, dst_path]:
            if os.path.exists(f):
                os.remove(f)

if __name__ == "__main__":
    app = ApplicationBuilder().token(TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(MessageHandler(filters.PHOTO, handle_image))
    app.run_polling()