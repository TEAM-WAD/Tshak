from pyrogram import Client, filters
from pytgcalls import GroupCallFactory

app = Client("MyBot", api_id=30357243, api_hash="9782c26101c502f026721b8e7993786c", bot_token="8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo")

group_call = GroupCallFactory(app).get_file_group_call()

@app.on_message(filters.command("play"))
async def play(client, message):
    # 1. الانضمام للمكالمة
    try:
        await group_call.join(message.chat.id)
    except:
        pass

    # 2. تحديد الملف الصوتي
    audio_url = "https://download.samplelib.com/mp3/sample.mp3"
    
    if message.reply_to_message and message.reply_to_message.audio:
        file_path = await message.reply_to_message.download()
        # الطريقة الوحيدة للإصدار القديم
        await group_call.set_input_filename(file_path)
        await message.reply("تم تشغيل الملف المردود عليه!")
    else:
        await group_call.set_input_filename(audio_url)
        await message.reply("تم تشغيل الصوت من الرابط!")

app.run()
