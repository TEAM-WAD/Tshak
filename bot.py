from pyrogram import Client
from pytgcalls import PyTgCalls
from pytgcalls.types.input_stream import AudioPiped

app = Client("MyBot", api_id=30357243, api_hash="9782c26101c502f026721b8e7993786c", bot_token="8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo")
pytgcalls = PyTgCalls(app)

@app.on_message()
async def handler(client, message):
    if message.text == "/play":
        await pytgcalls.join_group_call(
            message.chat.id,
            AudioPiped("https://download.samplelib.com/mp3/sample.mp3")
        )
        await message.reply("تم التشغيل!")

app.run()
