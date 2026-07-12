from pyrogram import Client, filters
from pytgcalls import GroupCallFactory

app = Client("MyBot", api_id=30357243, api_hash="9782c26101c502f026721b8e7993786c", bot_token="8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo")

group_call = GroupCallFactory(app).get_file_group_call()

@app.on_message(filters.command("play"))
async def play(client, message):
    # 1. الانضمام التلقائي للمجموعة
    try:
        await group_call.join(message.chat.id)
    except:
        pass # إذا كان منضماً بالفعل سيستمر

    # 2. التشغيل بالرد على ملف صوتي أو الرابط الافتراضي
    if message.reply_to_message and message.reply_to_message.audio:
        # تحميل الملف الصوتي المرسل
        file_path = await message.reply_to_message.download()
        await group_call.start_audio(file_path)
        await message.reply("تم تشغيل الملف الصوتي الذي رددت عليه!")
    else:
        # التشغيل من رابط إذا لم يكن هناك رد على ملف
        await group_call.start_audio("https://download.samplelib.com/mp3/sample.mp3")
        await message.reply("تم التشغيل من الرابط الافتراضي!")

app.run()
