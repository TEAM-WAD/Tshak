import os
from pyrogram import Client, filters
from pytgcalls import PyTgCalls
from pytgcalls import StreamType
from pytgcalls.types.input_stream import AudioPiped
import yt_dlp

# البيانات تُسحب من السيرفر
api_id = int(os.environ.get("API_ID", 30357243))
api_hash = os.environ.get("API_HASH", "9782c26101c502f026721b8e7993786c")
bot_token = os.environ.get("BOT_TOKEN", "8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo")

app = Client("MusicBot", api_id=api_id, api_hash=api_hash, bot_token=bot_token)
pytgcalls = PyTgCalls(app)

@app.on_message(filters.command("play"))
async def play(client, message):
    query = message.text.split(" ", 1)[1]
    ydl_opts = {'format': 'bestaudio', 'quiet': True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        video = ydl.extract_info(f"ytsearch:{query}", download=False)['entries'][0]
        url = video['url']
        
    await pytgcalls.join_group_call(
        message.chat.id,
        AudioPiped(url),
        stream_type=StreamType().pulse_stream
    )
    await message.reply(f"🎶 جاري تشغيل: {video['title']}")

pytgcalls.run()
