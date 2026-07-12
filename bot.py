from pyrogram import Client, filters

# تأكد أن البيانات هي نفسها المستخدمة سابقاً
app = Client(
    "MyBot", 
    api_id=30357243, 
    api_hash="9782c26101c502f026721b8e7993786c", 
    bot_token="8892595660:AAFIQO5THzLYYP1wvs56w_Ln1V8cjpFkDlo"
)

@app.on_message(filters.command("start"))
def start_handler(client, message):
    # هذه الرسالة ستظهر في التليجرام
    message.reply("أهلاً بك! البوت يعمل الآن بشكل صحيح.")
    # هذه الرسالة ستظهر في شاشة السيرفر للتأكد من وصول الأمر
    print(f"تم استلام أمر start من المستخدم: {message.from_user.id}")

print("البوت يعمل الآن..")
app.run()
