from pyrogram import Client, filters
from pytgcalls import PyTgCalls, idle
from pytgcalls.types import AudioPiped
import yt_dlp

# بياناتك (يُفضل استخدام Variables في السيرفر)
app = Client("MusicBot", api_id=30357243, api_hash="9782c26101c502f026721b8e7993786c", bot_token="8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo")
call = PyTgCalls(app)

@app.on_message(filters.command("play"))
async def play(client, message):
    if len(message.command) < 2:
        await message.reply("أرسل اسم الأغنية بعد الأمر، مثال: /play لتنساني")
        return
    
    query = message.text.split(" ", 1)[1]
    
    # البحث في يوتيوب
    ydl_opts = {'format': 'bestaudio', 'quiet': True}
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        video = ydl.extract_info(f"ytsearch:{query}", download=False)['entries'][0]
        url = video['url']
        
    await call.join_group_call(message.chat.id, AudioPiped(url))
    await message.reply(f"🎶 جاري تشغيل: {video['title']}")

app.start()
call.start()
idle()
