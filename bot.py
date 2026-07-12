from pyrogram import Client, filters
from pytgcalls import GroupCallFactory

app = Client("MyBot", api_id=30357243, api_hash="9782c26101c502f026721b8e7993786c", bot_token="8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo")

# هذا هو الاستدعاء الصحيح لهذا الإصدار القديم
group_call_factory = GroupCallFactory(app)
group_call = group_call_factory.get_group_call()

@app.on_message(filters.command("play"))
async def play(client, message):
    await group_call.join(message.chat.id)
    await group_call.start_audio("https://download.samplelib.com/mp3/sample.mp3")
    await message.reply("تم التشغيل بنجاح!")

app.run()
