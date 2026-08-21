import flet as ft
import random
import requests
import threading
import sqlite3
import hashlib
import os
import smtplib
import time
import colorsys
from datetime import datetime
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

# ================= مسار حفظ قاعدة البيانات على الأندرويد =================
APP_DIR = os.path.dirname(os.path.abspath(__file__))
DB_FILE = os.path.join(APP_DIR, "app_sec_data.db")

# ================= بيانات الربط مع الموقع =================
API_URL = "https://ylafollow.com/api/v2"
API_KEY = "2ff0c9c3dbf8db742196dd1d4215bbe2"

# ================= بيانات إرسال البريد الإلكتروني (SMTP) =================
SENDER_EMAIL = "Thakurvvirender4959@gmail.com"
SENDER_PASSWORD = "efax hjte mupr odhh"

def send_email_otp(target_email, code, is_reset=False):
    try:
        msg = MIMEMultipart()
        msg['From'] = f"Follower X <{SENDER_EMAIL}>"
        msg['To'] = target_email
        
        if is_reset:
            msg['Subject'] = "كود إعادة تعيين كلمة المرور - Follower X"
            body = f"مرحباً بك في تطبيق Follower X!\n\nكود إعادة تعيين كلمة المرور الخاص بك هو: {code}\n\nيرجى إدخاله في التطبيق لإعادة تعيين كلمة المرور الخاصة بك."
        else:
            msg['Subject'] = "كود تفعيل حسابك - Follower X"
            body = f"مرحباً بك في تطبيق Follower X!\n\nكود التفعيل الخاص بك هو: {code}\n\nيرجى إدخاله في التطبيق لإكمال عملية التسجيل."
            
        msg.attach(MIMEText(body, 'plain', 'utf-8'))

        server = smtplib.SMTP('smtp.gmail.com', 587, timeout=15)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.sendmail(SENDER_EMAIL, target_email, msg.as_string())
        server.quit()
        return True, "تم الإرسال بنجاح"
    except Exception as ex:
        print(f"Error sending email: {ex}")
        return False, str(ex)

# ================= إدارة قاعدة البيانات =================
def init_db():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            balance REAL DEFAULT 0.0,
            spent REAL DEFAULT 0.0
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS saved_credentials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            identity TEXT,
            password TEXT
        )
    ''')
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            api_order_id TEXT,
            service_name TEXT,
            service_type TEXT,
            link TEXT,
            quantity INTEGER,
            cost REAL,
            status TEXT,
            start_count TEXT,
            remains TEXT,
            created_at TEXT
        )
    ''')
    conn.commit()
    conn.close()

init_db()

def save_remembered_credentials(identity, password):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('DELETE FROM saved_credentials')
    cursor.execute('INSERT INTO saved_credentials (identity, password) VALUES (?, ?)', (identity, password))
    conn.commit()
    conn.close()

def get_remembered_credentials():
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('SELECT identity, password FROM saved_credentials LIMIT 1')
    row = cursor.fetchone()
    conn.close()
    return row if row else (None, None)

def hash_password(password: str, salt: bytes = None) -> tuple[str, str]:
    if salt is None:
        salt = os.urandom(16)
    key = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, 100000)
    return key.hex(), salt.hex()

def register_user_db(username, email, password):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    key_hex, salt_hex = hash_password(password)
    try:
        cursor.execute('INSERT INTO users (username, email, password_hash, salt, balance) VALUES (?, ?, ?, ?, 0.0)',
                       (username.lower(), email.lower(), key_hex, salt_hex))
        conn.commit()
        conn.close()
        return True, "تم إنشاء الحساب بنجاح!"
    except sqlite3.IntegrityError:
        conn.close()
        return False, "اسم المستخدم أو البريد الإلكتروني مسجل بالفعل!"

def check_login_db(identity, password):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    identity_clean = identity.lower()
    
    cursor.execute('SELECT id, password_hash, salt FROM users WHERE username = ? OR email = ?', (identity_clean, identity_clean))
    row = cursor.fetchone()
    conn.close()

    if not row:
        return "NOT_FOUND", None
    
    user_id, stored_hash_hex, salt_hex = row
    salt_bytes = bytes.fromhex(salt_hex)
    calculated_hash_hex, _ = hash_password(password, salt_bytes)
    
    if calculated_hash_hex == stored_hash_hex:
        return "SUCCESS", user_id
    else:
        return "WRONG_PASSWORD", None

def update_user_password(email, new_password):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    key_hex, salt_hex = hash_password(new_password)
    cursor.execute('UPDATE users SET password_hash = ?, salt = ? WHERE email = ?',
                   (key_hex, salt_hex, email.lower().strip()))
    conn.commit()
    conn.close()
    return True

def get_user_data(user_id):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('SELECT balance, spent, username FROM users WHERE id = ?', (user_id,))
    row = cursor.fetchone()
    conn.close()
    if row:
        return {"balance": row[0], "spent": row[1], "username": row[2]}
    return {"balance": 0.0, "spent": 0.0, "username": ""}

def update_user_balance(user_id, cost):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('UPDATE users SET balance = balance - ?, spent = spent + ? WHERE id = ?', (cost, cost, user_id))
    conn.commit()
    conn.close()

def save_order(user_id, api_order_id, service_name, service_type, link, quantity, cost, status="قيد الانتظار"):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    date_str = datetime.now().strftime("%Y-%m-%d")
    cursor.execute('''
        INSERT INTO orders (user_id, api_order_id, service_name, service_type, link, quantity, cost, status, start_count, remains, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, '-', ?, ?)
    ''', (user_id, str(api_order_id), service_name, service_type, link, quantity, cost, status, str(quantity), date_str))
    conn.commit()
    conn.close()

def get_user_orders(user_id):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('SELECT api_order_id, service_name, status, link, cost, quantity, start_count, remains, created_at, id FROM orders WHERE user_id = ? ORDER BY id DESC', (user_id,))
    rows = cursor.fetchall()
    conn.close()
    return rows

def update_order_status(db_id, new_status, start_count="-", remains="-"):
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute('UPDATE orders SET status = ?, start_count = ?, remains = ? WHERE id = ?', (new_status, start_count, remains, db_id))
    conn.commit()
    conn.close()

# ================= الشعار الرمزي الخالي من الصور =================
def create_app_logo_badge(size=75):
    return ft.Container(
        content=ft.Text("X", size=int(size * 0.5), weight=ft.FontWeight.BOLD, color="#FF2A40"),
        width=size,
        height=size,
        border_radius=size // 2,
        alignment=ft.alignment.center,
        bgcolor="#0F0F18",
        border=ft.border.all(2, "#FF2A40"),
        shadow=ft.BoxShadow(blur_radius=12, color="#40FF2A40")
    )

# ================= عنصر العنوان المعدل =================
def create_shimmer_title():
    text_content = ft.Row([
        ft.Text("FOLLOWER", size=9, weight=ft.FontWeight.BOLD, color="white"),
        ft.Text("-", size=9, weight=ft.FontWeight.BOLD, color="#FF2A40"),
        ft.Text("X", size=9, weight=ft.FontWeight.BOLD, color="white"),
        ft.Text(" | ", size=9, weight=ft.FontWeight.BOLD, color="#555577"),
        ft.Text("فولور اكس", size=9, weight=ft.FontWeight.BOLD, color="white"),
    ], alignment=ft.MainAxisAlignment.CENTER, spacing=3)

    shimmer_container = ft.Container(
        content=text_content,
        padding=ft.padding.symmetric(horizontal=12, vertical=5),
        border_radius=10,
        bgcolor="#0F0F18",
        border=ft.border.all(1.2, "#FF2A40"),
        alignment=ft.alignment.center,
        shadow=ft.BoxShadow(blur_radius=6, color="#33FF2A40"),
    )

    def animate_border():
        colors_list = ["#FF2A40", "#D00020", "#00FFC2", "#FF2A40"]
        idx = 0
        while True:
            try:
                shimmer_container.border = ft.border.all(1.2, colors_list[idx % len(colors_list)])
                shimmer_container.update()
                idx += 1
                time.sleep(0.4)
            except Exception:
                break

    threading.Thread(target=animate_border, daemon=True).start()
    return shimmer_container

# ================= التطبيق الرئيسي =================
def main(page: ft.Page):
    page.title = "Follower X - فولور اكس"
    page.theme_mode = ft.ThemeMode.DARK
    page.bgcolor = "#06060B"
    page.padding = 0
    page.window_width = 410
    page.window_height = 820

    current_platform = ["انستغرام"]
    is_dark_mode = [True]
    current_route = ["/splash"]
    current_extra = [None]
    all_api_services = []
    current_user_id = [None]
    last_order_info = [None]

    def clear_overlays():
        page.overlay.clear()
        page.update()

    def show_alert(msg, color="#FF2A40"):
        page.snack_bar = ft.SnackBar(content=ft.Text(msg, color="white", weight=ft.FontWeight.BOLD), bgcolor=color)
        page.snack_bar.open = True
        page.update()

    # ================= إشعار منبثق أعلى الشاشة =================
    def show_top_notification(title, body):
        notification_card = ft.Container(
            content=ft.Row([
                ft.Icon(ft.Icons.NOTIFICATIONS_ACTIVE, color="#00FFC2", size=24),
                ft.Column([
                    ft.Text(title, color="white", weight=ft.FontWeight.BOLD, size=13),
                    ft.Text(body, color="#DDDDDD", size=11),
                ], spacing=2, expand=True)
            ], alignment=ft.MainAxisAlignment.START, spacing=10),
            padding=12,
            bgcolor="#1A1A2E",
            border_radius=14,
            border=ft.border.all(1.5, "#00FFC2"),
            shadow=ft.BoxShadow(blur_radius=15, color="#6600FFC2"),
            margin=ft.margin.only(top=40, left=15, right=15)
        )
        
        page.overlay.append(notification_card)
        page.update()

        def remove_notification():
            time.sleep(4)
            if notification_card in page.overlay:
                page.overlay.remove(notification_card)
                page.update()

        threading.Thread(target=remove_notification, daemon=True).start()

    def show_custom_dialog(title, text):
        def close_dlg(e=None):
            dlg.open = False
            page.update()

        dlg = ft.AlertDialog(
            title=ft.Row([
                ft.Text(title, color="#FF2A40", weight=ft.FontWeight.BOLD, size=16),
                ft.IconButton(icon=ft.Icons.CLOSE, icon_color="white" if is_dark_mode[0] else "black", on_click=close_dlg)
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            content=ft.Text(text, color="white" if is_dark_mode[0] else "black", size=14),
            bgcolor="#12121A" if is_dark_mode[0] else "#FFFFFF"
        )
        page.overlay.append(dlg)
        dlg.open = True
        page.update()

    # ================= نافذة الضبط السفلية =================
    def open_settings_bottom_sheet(e=None):
        def toggle_theme(evt):
            is_dark_mode[0] = evt.control.value
            page.theme_mode = ft.ThemeMode.DARK if is_dark_mode[0] else ft.ThemeMode.LIGHT
            page.bgcolor = "#06060B" if is_dark_mode[0] else "#F2F2F7"
            page.update()
            navigate_to(current_route[0], current_extra[0])

        bs = ft.BottomSheet(
            ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Text("⚙️ الإعدادات", size=16, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                        ft.IconButton(icon=ft.Icons.CLOSE, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: close_bs())
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    ft.Divider(color="#333344" if is_dark_mode[0] else "#CCCCCC"),
                    ft.Row([
                        ft.Text("الوضع الداكن", size=14, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                        ft.Switch(value=is_dark_mode[0], active_color="#00FFC2", on_change=toggle_theme)
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                ], spacing=15, alignment=ft.MainAxisAlignment.CENTER),
                padding=20,
                bgcolor="#12121D" if is_dark_mode[0] else "#FFFFFF",
                border_radius=ft.border_radius.only(top_left=20, top_right=20)
            )
        )

        def close_bs(e=None):
            bs.open = False
            page.update()

        page.overlay.append(bs)
        bs.open = True
        page.update()

    # ================= أيقونة الضبط المتحركة =================
    def create_settings_button():
        btn = ft.Container(
            content=ft.Text("⚙️", size=22),
            rotate=ft.Rotate(0, alignment=ft.alignment.center),
            on_click=open_settings_bottom_sheet,
            padding=5,
            ink=True
        )

        def spin():
            angle = 0.0
            while True:
                try:
                    angle += 0.15
                    if angle >= 6.28:
                        angle = 0.0
                    btn.rotate = ft.Rotate(angle, alignment=ft.alignment.center)
                    btn.update()
                    time.sleep(0.08)
                except Exception:
                    break

        threading.Thread(target=spin, daemon=True).start()
        return btn

    # ================= مستطيل الألوان الديناميكي =================
    def create_dynamic_smooth_box(content):
        box = ft.Container(
            content=content,
            padding=12,
            border_radius=16,
            bgcolor="#0E0E18" if is_dark_mode[0] else "#FFFFFF",
            border=ft.border.all(2, "#FF2A40"),
            alignment=ft.alignment.center,
            animate=ft.Animation(150, ft.AnimationCurve.LINEAR)
        )

        def continuous_color_shift():
            hue = 0.0
            while True:
                try:
                    hue = (hue + 0.01) % 1.0
                    r, g, b = colorsys.hsv_to_rgb(hue, 0.85, 1.0)
                    hex_color = f"#{int(r*255):02x}{int(g*255):02x}{int(b*255):02x}"
                    box.border = ft.border.all(2, hex_color)
                    box.update()
                    time.sleep(0.1)
                except Exception:
                    break

        threading.Thread(target=continuous_color_shift, daemon=True).start()
        return box

    # ================= شبكة الفئات =================
    def build_category_grid():
        c_tiktok = ft.Container(content=ft.Icon(ft.Icons.MUSIC_NOTE, color="white", size=24), width=52, height=52, bgcolor="#FE2755", border_radius=12, alignment=ft.alignment.center)
        c_facebook = ft.Container(content=ft.Icon(ft.Icons.FACEBOOK, color="white", size=24), width=52, height=52, bgcolor="#1877F2", border_radius=12, alignment=ft.alignment.center)
        c_youtube = ft.Container(content=ft.Icon(ft.Icons.PLAY_ARROW, color="white", size=26), width=52, height=52, bgcolor="#FF0000", border_radius=12, alignment=ft.alignment.center)
        c_twitter = ft.Container(content=ft.Icon(ft.Icons.DISCORD, color="white", size=24), width=52, height=52, bgcolor="#1DA1F2", border_radius=12, alignment=ft.alignment.center)
        c_insta = ft.Container(content=ft.Icon(ft.Icons.CAMERA_ALT, color="white", size=24), width=52, height=52, gradient=ft.LinearGradient(["#833AB4", "#FD1D1D", "#FCB045"]), border_radius=12, alignment=ft.alignment.center)

        c_kick = ft.Container(content=ft.Text("K", color="white", size=22, weight=ft.FontWeight.BOLD), width=52, height=52, bgcolor="#00E701", border_radius=12, alignment=ft.alignment.center)
        c_soundcloud = ft.Container(content=ft.Icon(ft.Icons.CLOUD, color="white", size=24), width=52, height=52, bgcolor="#FF5500", border_radius=12, alignment=ft.alignment.center)
        c_spotify = ft.Container(content=ft.Icon(ft.Icons.HEADSET, color="white", size=24), width=52, height=52, bgcolor="#1DB954", border_radius=12, alignment=ft.alignment.center)
        c_telegram = ft.Container(content=ft.Icon(ft.Icons.SEND, color="white", size=22), width=52, height=52, bgcolor="#229ED9", border_radius=12, alignment=ft.alignment.center)
        c_twitch = ft.Container(content=ft.Icon(ft.Icons.CHAT_BUBBLE, color="white", size=22), width=52, height=52, bgcolor="#9146FF", border_radius=12, alignment=ft.alignment.center)

        return ft.Column([
            ft.Row([c_tiktok, c_facebook, c_youtube, c_twitter, c_insta], alignment=ft.MainAxisAlignment.SPACE_EVENLY),
            ft.Row([c_kick, c_soundcloud, c_spotify, c_telegram, c_twitch], alignment=ft.MainAxisAlignment.SPACE_EVENLY),
        ], spacing=10)

    # ================= شبكة طرق الدفع =================
    def build_payments_grid():
        tile_bg = "#181824" if is_dark_mode[0] else "#F8F9FA"
        card_border = "#282838" if is_dark_mode[0] else "#DDDDDD"

        def pay_box(content):
            return ft.Container(
                content=content,
                height=52,
                bgcolor=tile_bg,
                border_radius=10,
                border=ft.border.all(1, card_border),
                alignment=ft.alignment.center,
                expand=True
            )

        p_visa = pay_box(ft.Text("VISA", color="#2563EB", size=18, weight=ft.FontWeight.BOLD, italic=True))
        p_mc = pay_box(ft.Row([
            ft.Container(width=16, height=16, bgcolor="#EB001B", border_radius=8),
            ft.Container(width=16, height=16, bgcolor="#F79E1B", border_radius=8, margin=ft.margin.only(left=-7)),
        ], alignment=ft.MainAxisAlignment.CENTER))
        p_usdt = pay_box(ft.Row([
            ft.Icon(ft.Icons.DIAMOND, color="#26A17B", size=18),
            ft.Text("USDT", color="#26A17B", size=12, weight=ft.FontWeight.BOLD)
        ], alignment=ft.MainAxisAlignment.CENTER, spacing=4))
        p_paytr = pay_box(ft.Row([
            ft.Icon(ft.Icons.FAST_FORWARD, color="#0088FF", size=15),
            ft.Text("PAYTR", color="#0088FF", size=13, weight=ft.FontWeight.BOLD)
        ], alignment=ft.MainAxisAlignment.CENTER, spacing=4))
        p_crypto = pay_box(ft.Row([
            ft.Icon(ft.Icons.VIEW_IN_AR, color="white" if is_dark_mode[0] else "black", size=16),
            ft.Text("cryptomus", color="white" if is_dark_mode[0] else "black", size=11, weight=ft.FontWeight.BOLD)
        ], alignment=ft.MainAxisAlignment.CENTER, spacing=4))
        p_payeer = pay_box(ft.Text("PAYEER", color="#00A3E0", size=14, weight=ft.FontWeight.BOLD))
        p_binance = pay_box(ft.Row([
            ft.Icon(ft.Icons.TOKEN, color="#F0B90B", size=16),
            ft.Text("BINANCE", color="#F0B90B", size=12, weight=ft.FontWeight.BOLD)
        ], alignment=ft.MainAxisAlignment.CENTER, spacing=4))
        p_stripe = pay_box(ft.Text("stripe", color="#635BFF", size=15, weight=ft.FontWeight.BOLD))

        return ft.Column([
            ft.Row([p_visa, p_mc], spacing=8),
            ft.Row([p_usdt, p_paytr], spacing=8),
            ft.Row([p_crypto, p_payeer], spacing=8),
            ft.Row([p_binance, p_stripe], spacing=8),
        ], spacing=8)

    def simplify_service_name(original_name, platform):
        name_lower = original_name.lower()
        if "متابعين" in original_name or "followers" in name_lower:
            return f"متابعين {platform} حقيقيين"
        elif "لايكات" in original_name or "إعجابات" in original_name or "likes" in name_lower:
            return f"لايكات {platform} تفاعلية"
        elif "مشاهدات" in original_name or "views" in name_lower:
            return f"مشاهدات {platform} فورية"
        elif "اعضاء" in original_name or "أعضاء" in original_name or "members" in name_lower:
            return f"أعضاء {platform} حقيقيين"
        elif "تعليقات" in original_name or "comments" in name_lower:
            return f"تعليقات {platform} مخصصة"
        else:
            words = original_name.split()
            if len(words) > 5:
                return " ".join(words[:5]) + "..."
            return original_name

    def navigate_to(route_name, extra_data=None):
        current_route[0] = route_name
        current_extra[0] = extra_data
        clear_overlays()
        page.controls.clear()
        
        if route_name == "/splash":
            page.add(splash_view())
        elif route_name == "/login":
            page.add(login_view())
        elif route_name == "/register":
            page.add(register_view())
        elif route_name == "/dashboard":
            page.add(dashboard_view())
        elif route_name == "/about":
            page.add(about_view())
        elif route_name == "/services":
            if extra_data:
                current_platform[0] = extra_data
            page.add(services_view(current_platform[0]))
        elif route_name == "/order_form":
            page.add(order_form_view(extra_data))
        elif route_name == "/orders_history":
            page.add(orders_history_view())
        elif route_name == "/free_services":
            page.add(free_services_view())
            
        page.update()

    # ================= 0. واجهة الانتظار (Splash) =================
    def splash_view():
        icons_list = [ft.Icons.CAMERA_ALT, ft.Icons.FACEBOOK, ft.Icons.SEND, ft.Icons.MUSIC_NOTE, ft.Icons.PLAY_ARROW, ft.Icons.DISCORD]
        colors_list = ["#E1306C", "#1877F2", "#229ED9", "#FE2755", "#FF0000", "#5865F2"]
        
        icon_display = ft.Icon(icons_list[0], color=colors_list[0], size=36)
        
        def start_loading_animation():
            for idx in range(8):
                icon_display.name = icons_list[idx % len(icons_list)]
                icon_display.color = colors_list[idx % len(colors_list)]
                try:
                    page.update()
                except Exception:
                    break
                time.sleep(0.2)
            navigate_to("/login")

        threading.Thread(target=start_loading_animation, daemon=True).start()

        return ft.Container(
            content=ft.Column([
                ft.Row([create_settings_button()], alignment=ft.MainAxisAlignment.START),
                ft.Container(expand=True),
                
                create_app_logo_badge(100),
                ft.Container(height=12),
                
                create_shimmer_title(),
                ft.Container(height=6),
                ft.Text("عالم زيادة وتطوير حسابات التواصل الاجتماعي", size=10, color="#777799" if is_dark_mode[0] else "#555577"),
                
                ft.Container(height=25),
                
                ft.Container(
                    content=icon_display,
                    padding=12,
                    border_radius=50,
                    bgcolor="#12121F" if is_dark_mode[0] else "#EAEAEA",
                    border=ft.border.all(1, "#3300FFC2"),
                    shadow=ft.BoxShadow(blur_radius=15, color="#4400FFC2")
                ),
                ft.Container(height=10),
                ft.Text("LOADING...", size=13, weight=ft.FontWeight.BOLD, color="#00FFC2"),
                
                ft.Container(expand=True),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, alignment=ft.MainAxisAlignment.CENTER),
            padding=25,
            expand=True,
            gradient=ft.LinearGradient(["#0A0A14", "#030306"] if is_dark_mode[0] else ["#FFFFFF", "#F0F0F5"], begin=ft.alignment.TOP_CENTER, end=ft.alignment.BOTTOM_CENTER)
        )

    # ================= 1. واجهة تسجيل الدخول =================
    def login_view():
        saved_ident, saved_pass = get_remembered_credentials()

        identity_field = ft.TextField(
            label="اسم المستخدم أو البريد الإلكتروني",
            value=saved_ident if saved_ident else "",
            border_radius=12,
            border_color="#2A2A3E" if is_dark_mode[0] else "#CCCCCC",
            focused_border_color="#00FFC2",
            prefix_icon=ft.Icons.PERSON_OUTLINE,
            bgcolor="#0E0E18" if is_dark_mode[0] else "#F9F9FC"
        )
        password_field = ft.TextField(
            label="كلمة المرور",
            value=saved_pass if saved_pass else "",
            password=True,
            can_reveal_password=True,
            border_radius=12,
            border_color="#2A2A3E" if is_dark_mode[0] else "#CCCCCC",
            focused_border_color="#00FFC2",
            prefix_icon=ft.Icons.LOCK_OUTLINE,
            bgcolor="#0E0E18" if is_dark_mode[0] else "#F9F9FC"
        )
        remember_checkbox = ft.Checkbox(label="تذكرني", value=True if saved_ident else False, active_color="#FF2A40")

        def handle_login(e):
            ident = identity_field.value.strip() if identity_field.value else ""
            pwd = password_field.value if password_field.value else ""

            if not ident or not pwd:
                show_alert("يرجى إدخال جميع البيانات المطلوبة!", "#FF2A40")
                return

            def async_check_login():
                res, uid = check_login_db(ident, pwd)
                if res == "NOT_FOUND" or res == "WRONG_PASSWORD":
                    show_custom_dialog("تنبيه", "لا يوجد حساب بهذه المعلومات")
                elif res == "SUCCESS":
                    current_user_id[0] = uid
                    if remember_checkbox.value:
                        save_remembered_credentials(ident, pwd)
                    show_alert("تم تسجيل الدخول بنجاح!", "#00FFC2")
                    navigate_to("/dashboard")

            threading.Thread(target=async_check_login, daemon=True).start()

        def open_forgot_password_dialog(e=None):
            reset_email_field = ft.TextField(label="البريد الإلكتروني المسجل", border_radius=10, hint_text="example@gmail.com")

            def close_forgot_dlg(e=None):
                forgot_dlg.open = False
                page.update()

            def handle_reset_request(e):
                em = reset_email_field.value.strip() if reset_email_field.value else ""
                if not em:
                    show_alert("يرجى إدخال البريد الإلكتروني!", "#FF2A40")
                    return

                forgot_dlg.open = False
                page.update()

                reset_otp = random.randint(100000, 999999)
                otp_reset_field = ft.TextField(label="أدخل كود التحقق (6 أرقام)", border_radius=10, keyboard_type=ft.KeyboardType.NUMBER)

                def close_otp_reset_dlg(e=None):
                    otp_reset_dlg.open = False
                    page.update()

                def verify_reset_otp(e):
                    val = otp_reset_field.value.strip() if otp_reset_field.value else ""
                    if str(reset_otp) == val:
                        otp_reset_dlg.open = False
                        page.update()

                        new_pass_field = ft.TextField(label="كلمة المرور الجديدة", password=True, can_reveal_password=True, border_radius=10)
                        conf_new_pass_field = ft.TextField(label="تأكيد كلمة المرور الجديدة", password=True, can_reveal_password=True, border_radius=10)

                        def save_new_password(e):
                            np = new_pass_field.value if new_pass_field.value else ""
                            cnp = conf_new_pass_field.value if conf_new_pass_field.value else ""

                            if not np or not cnp:
                                show_alert("يرجى ملء جميع الحقول!", "#FF2A40")
                                return

                            if len(np) < 8:
                                show_alert("كلمة المرور يجب أن تكون 8 أحرف أو أكثر!", "#FF2A40")
                                return

                            if np != cnp:
                                show_alert("كلمتا المرور غير متطابقين!", "#FF2A40")
                                return

                            threading.Thread(target=lambda: update_user_password(em, np), daemon=True).start()
                            new_pass_dlg.open = False
                            page.update()
                            show_alert("تم تغيير كلمة المرور بنجاح! جاري الدخول...", "#00FFC2")
                            navigate_to("/dashboard")

                        new_pass_dlg = ft.AlertDialog(
                            title=ft.Text("تعيين كلمة مرور جديدة", color="#00FFC2", weight=ft.FontWeight.BOLD),
                            content=ft.Column([
                                ft.Text("أدخل كلمة المرور الجديدة لحسابك:", color="white" if is_dark_mode[0] else "black", size=13),
                                new_pass_field,
                                conf_new_pass_field
                            ], height=180, spacing=10),
                            actions=[
                                ft.ElevatedButton("إرسال وحفظ", bgcolor="#00FFC2", color="black", on_click=save_new_password),
                            ],
                            bgcolor="#12121A" if is_dark_mode[0] else "#FFFFFF"
                        )
                        page.overlay.append(new_pass_dlg)
                        new_pass_dlg.open = True
                        page.update()
                    else:
                        show_alert("كود التحقق غير صحيح!", "#FF2A40")

                otp_reset_dlg = ft.AlertDialog(
                    title=ft.Text("تأكيد كود التحقق", color="#00FFC2", weight=ft.FontWeight.BOLD),
                    content=ft.Column([
                        ft.Text(f"لقد أرسلنا كود التحقق للايميل:\n{em}", color="white" if is_dark_mode[0] else "black", size=13),
                        otp_reset_field
                    ], height=130, spacing=10),
                    actions=[
                        ft.ElevatedButton("تأكيد الكود", bgcolor="#00FFC2", color="black", on_click=verify_reset_otp),
                        ft.TextButton("إلغاء", on_click=close_otp_reset_dlg)
                    ],
                    bgcolor="#12121A" if is_dark_mode[0] else "#FFFFFF"
                )

                page.overlay.append(otp_reset_dlg)
                otp_reset_dlg.open = True
                page.update()

                def async_send_reset_otp():
                    ok, err = send_email_otp(em, reset_otp, is_reset=True)
                    if not ok:
                        show_alert(f"فشل إرسال البريد: {err}", "#FF2A40")

                threading.Thread(target=async_send_reset_otp, daemon=True).start()

            forgot_dlg = ft.AlertDialog(
                title=ft.Text("إعادة تعيين كلمة المرور", color="#FF2A40", weight=ft.FontWeight.BOLD),
                content=ft.Column([
                    ft.Text("أدخل بريدك الإلكتروني للتحقق من حسابك:", color="white" if is_dark_mode[0] else "black", size=13),
                    reset_email_field
                ], height=120, spacing=10),
                actions=[
                    ft.ElevatedButton("إرسال", bgcolor="#FF2A40", color="white", on_click=handle_reset_request),
                    ft.TextButton("إلغاء", on_click=close_forgot_dlg)
                ],
                bgcolor="#12121A" if is_dark_mode[0] else "#FFFFFF"
            )
            page.overlay.append(forgot_dlg)
            forgot_dlg.open = True
            page.update()

        signature_box = ft.Container(
            content=ft.Text(
                "MohammeD Al-Hussein",
                size=11,
                weight=ft.FontWeight.BOLD,
                color="#00FFC2",
                selectable=False
            ),
            padding=ft.padding.symmetric(horizontal=16, vertical=5),
            border_radius=8,
            border=ft.border.all(1, "#4400FFC2"),
            bgcolor="#0A00FFC2",
            alignment=ft.alignment.center
        )

        cat_header = ft.Column([
            ft.Text("اختر الفئة", size=22, weight=ft.FontWeight.BOLD, color="#38BDF8"),
            ft.Row([
                ft.Icon(ft.Icons.SUBDIRECTORY_ARROW_LEFT, color="#38BDF8", size=26),
                ft.Container(width=70, height=2, bgcolor="#38BDF8", border_radius=1)
            ], alignment=ft.MainAxisAlignment.CENTER, spacing=0)
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)

        pay_header = ft.Column([
            ft.Row([
                ft.Text("طرق دفع ", size=20, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                ft.Text("متعددة", size=20, weight=ft.FontWeight.BOLD, color="#38BDF8")
            ], alignment=ft.MainAxisAlignment.CENTER),
            ft.Container(width=60, height=3, bgcolor="#38BDF8", border_radius=2)
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)

        return ft.Container(
            content=ft.Column([
                ft.Row([create_settings_button()], alignment=ft.MainAxisAlignment.START),
                
                create_app_logo_badge(75),
                
                ft.Text("مرحباً بعودتك! 👋", size=17, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                ft.Text("أدخل بياناتك لتسجيل الدخول إلى حسابك", size=11, color="#8888AA" if is_dark_mode[0] else "#666688", text_align=ft.TextAlign.CENTER),
                
                identity_field,
                password_field,
                
                ft.Row([
                    remember_checkbox,
                    ft.TextButton("نسيت كلمة السر؟", style=ft.ButtonStyle(color="#FF2A40"), on_click=open_forgot_password_dialog)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                
                ft.Container(
                    content=ft.ElevatedButton(
                        "دخول الحساب 🚀",
                        bgcolor="transparent",
                        color="white",
                        width=400,
                        height=46,
                        style=ft.ButtonStyle(elevation=0, shape=ft.RoundedRectangleBorder(radius=10)),
                        on_click=handle_login
                    ),
                    border_radius=10,
                    gradient=ft.LinearGradient(["#FF2A40", "#A00020"]),
                    shadow=ft.BoxShadow(blur_radius=10, color="#66FF2A40")
                ),
                
                ft.Row([
                    ft.Text("ليس لديك حساب؟", color="#888", size=12),
                    ft.TextButton("إنشاء حساب جديد", style=ft.ButtonStyle(color="#00FFC2"), on_click=lambda _: navigate_to("/register"))
                ], alignment=ft.MainAxisAlignment.CENTER),

                ft.Container(height=5),
                signature_box,
                ft.Container(height=10),

                cat_header,
                ft.Container(height=4),
                create_dynamic_smooth_box(build_category_grid()),
                
                ft.Container(height=15),

                pay_header,
                ft.Container(height=4),
                create_dynamic_smooth_box(build_payments_grid()),
                
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=10, scroll=ft.ScrollMode.AUTO),
            padding=22,
            expand=True,
            gradient=ft.LinearGradient(["#120307", "#06060A"] if is_dark_mode[0] else ["#FFFFFF", "#F2F2F7"], begin=ft.alignment.TOP_CENTER, end=ft.alignment.BOTTOM_CENTER)
        )

    # ================= 2. واجهة إنشاء حساب جديد =================
    def register_view():
        reg_user = ft.TextField(label="اسم المستخدم", border_radius=12, border_color="#2A2A38" if is_dark_mode[0] else "#CCCCCC", bgcolor="#0E0E18" if is_dark_mode[0] else "#F9F9FC")
        reg_email = ft.TextField(label="البريد الإلكتروني (@gmail.com حصراً)", hint_text="example@gmail.com", border_radius=12, border_color="#2A2A38" if is_dark_mode[0] else "#CCCCCC", bgcolor="#0E0E18" if is_dark_mode[0] else "#F9F9FC")
        reg_pass = ft.TextField(label="كلمة المرور (8 حروف أو أكثر)", password=True, can_reveal_password=True, border_radius=12, border_color="#2A2A38" if is_dark_mode[0] else "#CCCCCC", bgcolor="#0E0E18" if is_dark_mode[0] else "#F9F9FC")
        reg_conf = ft.TextField(label="إعادة كتابة كلمة المرور", password=True, can_reveal_password=True, border_radius=12, border_color="#2A2A38" if is_dark_mode[0] else "#CCCCCC", bgcolor="#0E0E18" if is_dark_mode[0] else "#F9F9FC")

        def validate_passwords(e):
            p = reg_pass.value if reg_pass.value else ""
            pc = reg_conf.value if reg_conf.value else ""

            if pc == "":
                reg_conf.border_color = "#2A2A38" if is_dark_mode[0] else "#CCCCCC"
                reg_conf.focused_border_color = "#00FFC2"
                reg_conf.error_text = None
            elif p == pc:
                reg_conf.border_color = "#00FFC2"
                reg_conf.focused_border_color = "#00FFC2"
                reg_conf.error_text = None
            else:
                reg_conf.border_color = "#FF2A40"
                reg_conf.focused_border_color = "#FF2A40"
                reg_conf.error_text = "كلمة المرور غير متطابقة"
            
            reg_conf.update()

        reg_pass.on_change = validate_passwords
        reg_conf.on_change = validate_passwords

        captcha_answer = [0]
        generated_otp = [0]

        def open_email_verification_dialog():
            generated_otp[0] = random.randint(100000, 999999)
            user_target_email = reg_email.value.strip()

            otp_input_field = ft.TextField(label="أدخل كود التفعيل المكون من 6 أرقام", border_radius=10, keyboard_type=ft.KeyboardType.NUMBER)

            def close_otp_dialog(e=None):
                otp_dialog.open = False
                page.update()

            def verify_otp_and_register(e):
                val = otp_input_field.value.strip() if otp_input_field.value else ""
                if str(generated_otp[0]) == val:
                    def async_reg():
                        success, msg = register_user_db(reg_user.value.strip(), user_target_email, reg_pass.value)
                        otp_dialog.open = False
                        page.update()
                        if success:
                            show_alert("تم تفعيل الحساب وإنشاؤه بنجاح!", "#00FFC2")
                            res, uid = check_login_db(reg_user.value.strip(), reg_pass.value)
                            if res == "SUCCESS":
                                current_user_id[0] = uid
                            navigate_to("/dashboard")
                        else:
                            show_alert(msg, "#FF2A40")

                    threading.Thread(target=async_reg, daemon=True).start()
                else:
                    show_alert("الكود غير صحيح! يرجى التأكد وإعادة المحاولة.", "#FF2A40")

            otp_dialog = ft.AlertDialog(
                title=ft.Text("تأكيد البريد الإلكتروني", color="#00FFC2", weight=ft.FontWeight.BOLD),
                content=ft.Column([
                    ft.Text(f"تم إرسال كود التفعيل إلى البريد:\n{user_target_email}", color="white" if is_dark_mode[0] else "black", size=13),
                    otp_input_field
                ], height=130, spacing=10),
                actions=[
                    ft.ElevatedButton("تأكيد وإنشاء الحساب", bgcolor="#00FFC2", color="black", on_click=verify_otp_and_register),
                    ft.TextButton("إلغاء", on_click=close_otp_dialog)
                ],
                bgcolor="#12121A" if is_dark_mode[0] else "#FFFFFF"
            )

            page.overlay.append(otp_dialog)
            otp_dialog.open = True
            page.update()

            def async_send():
                ok, err = send_email_otp(user_target_email, generated_otp[0])
                if not ok:
                    show_alert(f"فشل إرسال البريد: {err}", "#FF2A40")

            threading.Thread(target=async_send, daemon=True).start()

        def open_captcha_dialog():
            num1 = random.randint(10, 90)
            num2 = random.randint(5, 40)
            num3 = random.randint(1, 10)
            
            captcha_expr = f"{num1} + {num2} - {num3}"
            captcha_answer[0] = num1 + num2 - num3

            captcha_input_field = ft.TextField(label="أدخل الناتج هنا", border_radius=10, keyboard_type=ft.KeyboardType.NUMBER)

            def close_captcha_dialog(e=None):
                captcha_dialog.open = False
                page.update()

            def verify_captcha_step(e):
                val = captcha_input_field.value.strip() if captcha_input_field.value else ""
                if str(captcha_answer[0]) == val:
                    captcha_dialog.open = False
                    page.update()
                    open_email_verification_dialog()
                else:
                    show_alert("إجابة الكابتشا غير صحيحة! حاول مرة أخرى.", "#FF2A40")

            captcha_dialog = ft.AlertDialog(
                title=ft.Text("التحقق من أنك لست روبوت", color="#00FFC2", weight=ft.FontWeight.BOLD),
                content=ft.Column([
                    ft.Text("يرجى حل المسألة الحسابية التالية لإكمال التسجيل:", color="white" if is_dark_mode[0] else "black"),
                    ft.Container(
                        content=ft.Text(f"{captcha_expr} = ?", size=22, weight=ft.FontWeight.BOLD, color="#FF2A40"),
                        alignment=ft.alignment.center,
                        padding=10
                    ),
                    captcha_input_field
                ], height=160, spacing=10),
                actions=[
                    ft.ElevatedButton("تأكيد الكابتشا", bgcolor="#00FFC2", color="black", on_click=verify_captcha_step),
                    ft.TextButton("إلغاء", on_click=close_captcha_dialog)
                ],
                bgcolor="#12121A" if is_dark_mode[0] else "#FFFFFF"
            )
            
            page.overlay.append(captcha_dialog)
            captcha_dialog.open = True
            page.update()

        def handle_register_click(e):
            u = reg_user.value.strip() if reg_user.value else ""
            em = reg_email.value.strip() if reg_email.value else ""
            p = reg_pass.value if reg_pass.value else ""
            pc = reg_conf.value if reg_conf.value else ""

            if not u or not em or not p or not pc:
                show_alert("يرجى ملء جميع الحقول!", "#FF2A40")
                return

            if not em.lower().endswith("@gmail.com"):
                show_custom_dialog("تنبيه النطاق", "لايمكن اكمال انشاء حساب استخدم ايميل بهذه الصيغه:\nExample@gmail.com (نطاق @gmail.com حصراً)")
                return

            if len(p) < 8:
                show_alert("كلمة المرور يجب أن تكون 8 أحرف أو أكثر!", "#FF2A40")
                return

            if p != pc:
                show_alert("كلمة المرور غير متطابقة مع حقل إعادة الكتابة!", "#FF2A40")
                return

            open_captcha_dialog()

        return ft.Container(
            content=ft.Column([
                ft.Row([create_settings_button()], alignment=ft.MainAxisAlignment.START),
                ft.Container(
                    content=create_shimmer_title(),
                    alignment=ft.alignment.center
                ),
                ft.Container(height=5),
                ft.Text("إنشاء حساب جديد ✨", size=18, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                reg_user,
                reg_email,
                reg_pass,
                reg_conf,
                ft.Container(height=5),
                ft.Container(
                    content=ft.ElevatedButton("إنشاء حساب الآن", bgcolor="#00FFC2", color="black", width=400, height=46, style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10)), on_click=handle_register_click),
                    shadow=ft.BoxShadow(blur_radius=10, color="#4400FFC2")
                ),
                ft.TextButton("لديك حساب بالفعل؟ تسجيل الدخول", style=ft.ButtonStyle(color="#FF2A40"), on_click=lambda _: navigate_to("/login"))
            ], scroll=ft.ScrollMode.AUTO, spacing=10, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
            padding=20,
            expand=True,
            bgcolor="#0A0A0F" if is_dark_mode[0] else "#FFFFFF"
        )

    # ================= 3. القائمة الجانبية =================
    def create_drawer_item(icon_name, title, color_theme, on_click_action):
        return ft.Container(
            content=ft.Row([
                ft.Container(
                    content=ft.Icon(icon_name, color=color_theme, size=20),
                    padding=8,
                    border_radius=8,
                    bgcolor="#1A" + color_theme.replace("#", "")
                ),
                ft.Text(title, color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.W_600, size=13),
            ], spacing=12),
            padding=ft.padding.symmetric(horizontal=12, vertical=10),
            border_radius=10,
            bgcolor="#151522" if is_dark_mode[0] else "#F0F0F5",
            border=ft.border.all(1, "#222235" if is_dark_mode[0] else "#E0E0E0"),
            ink=True,
            on_click=on_click_action
        )

    page.drawer = ft.NavigationDrawer(
        bgcolor="#0E0E17" if is_dark_mode[0] else "#FFFFFF",
        controls=[
            ft.Container(
                content=ft.Column([
                    create_app_logo_badge(65),
                    ft.Container(height=6),
                    create_shimmer_title(),
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                padding=18,
                bgcolor="#12121E" if is_dark_mode[0] else "#F5F5FA",
                border=ft.border.only(bottom=ft.BorderSide(1, "#202032" if is_dark_mode[0] else "#E0E0E0"))
            ),
            ft.Container(
                content=ft.Column([
                    create_drawer_item(
                        ft.Icons.HOME, 
                        "الرئيسية", 
                        "#00FFC2", 
                        lambda _: (setattr(page.drawer, 'open', False), navigate_to("/dashboard"))
                    ),
                    create_drawer_item(
                        ft.Icons.RECEIPT_LONG, 
                        "سجل الطلبات", 
                        "#FF2A40", 
                        lambda _: (setattr(page.drawer, 'open', False), navigate_to("/orders_history"))
                    ),
                    create_drawer_item(
                        ft.Icons.CARD_GIFTCARD, 
                        "الخدمات المجانية", 
                        "#38BDF8", 
                        lambda _: (setattr(page.drawer, 'open', False), navigate_to("/free_services"))
                    ),
                    create_drawer_item(
                        ft.Icons.INFO, 
                        "من نحن", 
                        "#3B82F6", 
                        lambda _: (setattr(page.drawer, 'open', False), navigate_to("/about"))
                    ),
                    create_drawer_item(
                        ft.Icons.SUPPORT_AGENT, 
                        "اتصل بنا (الدعم الفني)", 
                        "#F59E0B", 
                        lambda _: page.launch_url("https://t.me/ffmrd")
                    ),
                    create_drawer_item(
                        ft.Icons.ACCOUNT_BALANCE_WALLET, 
                        "إضافة أموال (شحن الحساب)", 
                        "#10B981", 
                        lambda _: show_alert("تواصل مع الدعم عبر التليجرام لشحن رصيدك", "#10B981")
                    ),
                    ft.Divider(color="#202032" if is_dark_mode[0] else "#E0E0E0", height=10),
                    create_drawer_item(
                        ft.Icons.LOGOUT, 
                        "تسجيل الخروج", 
                        "#EF4444", 
                        lambda _: (setattr(page.drawer, 'open', False), navigate_to("/login"))
                    ),
                ], spacing=10),
                padding=15
            )
        ]
    )

    # ================= 4. الواجهة الرئيسية (Dashboard) =================
    def dashboard_view():
        u_data = get_user_data(current_user_id[0]) if current_user_id[0] else {"balance": 0.0, "spent": 0.0, "username": ""}
        u_orders = get_user_orders(current_user_id[0]) if current_user_id[0] else []

        stats_grid = ft.Row([
            ft.Container(
                content=ft.Column([
                    ft.Icon(ft.Icons.SHOPPING_BAG, color="#FF2A40", size=20), 
                    ft.Text("طلباتك", size=10, color="#8888AA" if is_dark_mode[0] else "#666688"), 
                    ft.Text(f"{len(u_orders)}", weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black", size=13)
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER), 
                bgcolor="#12121C" if is_dark_mode[0] else "#F4F4F8", padding=12, border_radius=10, expand=True, border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD")
            ),
            ft.Container(
                content=ft.Column([
                    ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT, color="#00FFC2", size=20), 
                    ft.Text("انفاقك", size=10, color="#8888AA" if is_dark_mode[0] else "#666688"), 
                    ft.Text(f"{u_data['spent']:.2f}$", weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black", size=13)
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER), 
                bgcolor="#12121C" if is_dark_mode[0] else "#F4F4F8", padding=12, border_radius=10, expand=True, border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD")
            ),
            ft.Container(
                content=ft.Column([
                    ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET, color="#FFD700", size=20), 
                    ft.Text("رصيدك", size=10, color="#8888AA" if is_dark_mode[0] else "#666688"), 
                    ft.Text(f"{u_data['balance']:.2f}$", weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black", size=13)
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER), 
                bgcolor="#12121C" if is_dark_mode[0] else "#F4F4F8", padding=12, border_radius=10, expand=True, border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD")
            ),
        ], spacing=8)

        dashboard_action_buttons = ft.Column([
            ft.Row([
                ft.Container(
                    content=ft.Row([
                        ft.Icon(ft.Icons.CARD_GIFTCARD, color="#00FFC2", size=16),
                        ft.Text("خدمات مجانية", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12)
                    ], alignment=ft.MainAxisAlignment.CENTER, spacing=6),
                    bgcolor="#12121C" if is_dark_mode[0] else "#F4F4F8",
                    padding=12,
                    border_radius=10,
                    border=ft.border.all(1, "#00FFC2"),
                    expand=True,
                    ink=True,
                    on_click=lambda _: navigate_to("/free_services")
                ),
                ft.Container(
                    content=ft.Row([
                        ft.Icon(ft.Icons.RECEIPT_LONG, color="#FF2A40", size=16),
                        ft.Text("سجل الطلبات", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12)
                    ], alignment=ft.MainAxisAlignment.CENTER, spacing=6),
                    bgcolor="#12121C" if is_dark_mode[0] else "#F4F4F8",
                    padding=12,
                    border_radius=10,
                    border=ft.border.all(1, "#FF2A40"),
                    expand=True,
                    ink=True,
                    on_click=lambda _: navigate_to("/orders_history")
                ),
            ], spacing=10),
            ft.Container(
                content=ft.Row([
                    ft.Icon(ft.Icons.ADD_CARD, color="#FFD700", size=18),
                    ft.Text("شحن الحساب", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=13)
                ], alignment=ft.MainAxisAlignment.CENTER, spacing=8),
                bgcolor="#12121C" if is_dark_mode[0] else "#F4F4F8",
                padding=12,
                border_radius=10,
                border=ft.border.all(1.2, "#FFD700"),
                width=400,
                ink=True,
                on_click=lambda _: show_alert("تواصل مع الدعم عبر التليجرام لشحن رصيدك!", "#FFD700")
            )
        ], spacing=8)

        last_order_box = ft.Container()
        if last_order_info[0]:
            o = last_order_info[0]
            last_order_box = ft.Container(
                content=ft.Column([
                    ft.Row([
                        ft.Icon(ft.Icons.CHECK_CIRCLE, color="#00FFC2", size=20),
                        ft.Text("تم ارسال طلبك بنجاح! 🚀", color="#00FFC2", weight=ft.FontWeight.BOLD, size=13),
                    ], alignment=ft.MainAxisAlignment.START, spacing=6),
                    ft.Divider(color="#3300FFC2", height=8),
                    ft.Text(f"الخدمة: {o.get('service_name')}", color="white" if is_dark_mode[0] else "black", size=11, weight=ft.FontWeight.BOLD),
                    ft.Text(f"الرابط: {o.get('link')}", color="#AAAAAA", size=11),
                    ft.Row([
                        ft.Text(f"الكمية: {o.get('quantity')}", color="white" if is_dark_mode[0] else "black", size=11),
                        ft.Text(f"التكلفة: ${o.get('cost'):.3f}", color="#00FFC2", weight=ft.FontWeight.BOLD, size=11),
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    ft.Text(f"نوع الخدمة: {o.get('service_type')}", color="#38BDF8", size=11, weight=ft.FontWeight.BOLD),
                ], spacing=4),
                bgcolor="#0F1F1C" if is_dark_mode[0] else "#E6F9F3",
                padding=12,
                border_radius=10,
                border=ft.border.all(1.2, "#00FFC2"),
                margin=ft.margin.only(top=5, bottom=10)
            )

            def hide_last_order_after_one_min():
                time.sleep(60)
                last_order_info[0] = None
                try:
                    last_order_box.visible = False
                    page.update()
                except Exception:
                    pass

            threading.Thread(target=hide_last_order_after_one_min, daemon=True).start()

        search_results_container = ft.Column(spacing=8)

        def perform_service_search(query):
            query_str = query.strip().lower()
            search_results_container.controls.clear()
            
            if not query_str:
                page.update()
                return

            def search_thread():
                if not all_api_services:
                    try:
                        res = requests.post(API_URL, data={'key': API_KEY, 'action': 'services'}, timeout=10)
                        if res.status_code == 200:
                            all_api_services.extend(res.json())
                    except Exception as ex:
                        print("API load error:", ex)

                filtered = [
                    s for s in all_api_services 
                    if query_str in str(s.get('name', '')).lower() or query_str in str(s.get('category', '')).lower()
                ]

                if filtered:
                    for s in filtered[:20]:
                        s_short = simplify_service_name(s.get('name', ''), "خدمة")
                        search_results_container.controls.append(
                            ft.Container(
                                content=ft.Column([
                                    ft.Text(s_short, color="black" if not is_dark_mode[0] else "white", weight=ft.FontWeight.BOLD, size=12),
                                    ft.Row([
                                        ft.Text(f"المعرف: {s.get('service')}", color="#666", size=10),
                                        ft.Text(f"السعر: ${s.get('rate')}/1000", color="#00AA77", weight=ft.FontWeight.BOLD, size=11),
                                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                                ], spacing=4),
                                bgcolor="#F8F9FA" if not is_dark_mode[0] else "#12121C",
                                padding=10,
                                border_radius=8,
                                border=ft.border.all(1, "#DDDDDD" if not is_dark_mode[0] else "#202030"),
                                ink=True,
                                on_click=lambda _, serv=s: navigate_to("/order_form", serv)
                            )
                        )
                else:
                    search_results_container.controls.append(
                        ft.Container(
                            content=ft.Row([
                                ft.Icon(ft.Icons.CANCEL, color="#FF2A40", size=18),
                                ft.Text(f"لايوجد نتيجة لبحثك ( {query.strip()} )", color="#FF2A40", weight=ft.FontWeight.BOLD, size=12),
                            ], alignment=ft.MainAxisAlignment.CENTER, spacing=6),
                            padding=10,
                            border_radius=8,
                            bgcolor="#1AFF2A40",
                            border=ft.border.all(1, "#FF2A40")
                        )
                    )
                try:
                    page.update()
                except Exception:
                    pass

            threading.Thread(target=search_thread, daemon=True).start()

        search_field = ft.TextField(
            hint_text="بحث في الخدمات",
            hint_style=ft.TextStyle(color="#888888", size=13),
            border_radius=12,
            bgcolor="#EFEFEF" if is_dark_mode[0] else "#FFFFFF",
            color="black",
            border_color="#E0E0E0",
            focused_border_color="#00FFC2",
            prefix_icon=ft.Icons.SEARCH,
            content_padding=ft.padding.symmetric(horizontal=15, vertical=10),
            on_change=lambda e: perform_service_search(e.control.value)
        )

        search_container_box = ft.Container(
            content=ft.Column([
                search_field,
                last_order_box,
                search_results_container
            ], spacing=8),
            margin=ft.margin.only(top=10, bottom=5)
        )

        def app_card(app_name, icon_name, color):
            return ft.Container(
                content=ft.Row([
                    ft.Icon(icon_name, color=color, size=22),
                    ft.Text(app_name, color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=13)
                ], alignment=ft.MainAxisAlignment.START),
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF",
                padding=16,
                border_radius=10,
                border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD"),
                expand=True,
                ink=True,
                on_click=lambda _: navigate_to("/services", app_name)
            )

        apps_grid = ft.Column([
            ft.Row([app_card("انستغرام", ft.Icons.CAMERA_ALT, "#E1306C"), app_card("فيسبوك", ft.Icons.FACEBOOK, "#1877F2")], spacing=8),
            ft.Row([app_card("تليجرام", ft.Icons.SEND, "#229ED9"), app_card("تيك توك", ft.Icons.MUSIC_NOTE, "#FE2755")], spacing=8),
            ft.Row([app_card("يوتيوب", ft.Icons.PLAY_ARROW, "#FF0000"), app_card("سبوتيفاي", ft.Icons.HEADSET, "#1DB954")], spacing=8),
            ft.Row([
                ft.Container(
                    content=ft.Row([
                        ft.Icon(ft.Icons.CLOSE, color="white" if is_dark_mode[0] else "black", size=22),
                        ft.Text("تويتر اكس", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=13)
                    ], alignment=ft.MainAxisAlignment.CENTER),
                    bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF",
                    padding=16,
                    border_radius=10,
                    border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD"),
                    expand=True,
                    ink=True,
                    on_click=lambda _: navigate_to("/services", "تويتر اكس")
                )
            ], spacing=8),
        ], spacing=8)

        payment_methods = ft.Container(
            content=ft.Column([
                ft.Text("طرق الدفع المدعومة", size=13, weight=ft.FontWeight.BOLD, color="#8888AA" if is_dark_mode[0] else "#555577"),
                ft.Row([
                    ft.Container(content=ft.Text("Visa / Master", color="white" if is_dark_mode[0] else "black", size=11), bgcolor="#181824" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=6),
                    ft.Container(content=ft.Text("زين كاش", color="#FFD700", size=11), bgcolor="#181824" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=6),
                    ft.Container(content=ft.Text("آسيا سيل", color="#FF2A40", size=11), bgcolor="#181824" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=6),
                ], alignment=ft.MainAxisAlignment.SPACE_AROUND)
            ], spacing=8),
            bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF", padding=12, border_radius=10, border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD")
        )

        return ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.Row([
                        ft.IconButton(icon=ft.Icons.MENU, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: page.open(page.drawer)),
                        create_settings_button()
                    ], spacing=0),
                    create_shimmer_title(),
                    create_app_logo_badge(32)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                padding=10,
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF"
            ),
            ft.Container(
                content=ft.Column([
                    stats_grid,
                    dashboard_action_buttons,
                    search_container_box,
                    ft.Text("اختر المنصة للبدء:", size=14, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                    apps_grid,
                    ft.Container(height=5),
                    payment_methods,
                ], scroll=ft.ScrollMode.AUTO, spacing=12),
                padding=12,
                expand=True
            )
        ], expand=True)

    # ================= 5. واجهة عرض الخدمات المباشرة =================
    def services_view(platform_name):
        services_container = ft.Column(scroll=ft.ScrollMode.AUTO, spacing=10, expand=True)
        loading_ring = ft.ProgressRing(color="#FF2A40", width=42, height=42, stroke_width=4)

        def animate_loader_colors():
            color_cycle = ["#FF2A40", "#00FFC2", "#38BDF8", "#EAB308", "#A855F7"]
            idx = 0
            while True:
                try:
                    loading_ring.color = color_cycle[idx % len(color_cycle)]
                    loading_ring.update()
                    idx += 1
                    time.sleep(0.35)
                except Exception:
                    break

        threading.Thread(target=animate_loader_colors, daemon=True).start()

        icon_map = {
            "انستغرام": (ft.Icons.CAMERA_ALT, "#E1306C"),
            "فيسبوك": (ft.Icons.FACEBOOK, "#1877F2"),
            "تليجرام": (ft.Icons.SEND, "#229ED9"),
            "تيك توك": (ft.Icons.MUSIC_NOTE, "#FE2755"),
            "يوتيوب": (ft.Icons.PLAY_ARROW, "#FF0000"),
            "سبوتيفاي": (ft.Icons.HEADSET, "#1DB954"),
            "تويتر اكس": (ft.Icons.CLOSE, "#FFFFFF" if is_dark_mode[0] else "#000000")
        }
        
        selected_icon, selected_color = icon_map.get(platform_name, (ft.Icons.APPS, "#00FFC2"))

        category_card = ft.Container(
            content=ft.Row([
                ft.Icon(selected_icon, color=selected_color, size=20),
                ft.Text(f"خدمات {platform_name} المتاحة", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=13)
            ], alignment=ft.MainAxisAlignment.CENTER, spacing=8),
            padding=10,
            border_radius=8,
            bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF",
            border=ft.border.all(1.2, "#00FFC2"),
        )

        def fetch_api_services():
            try:
                payload = {'key': API_KEY, 'action': 'services'}
                res = requests.post(API_URL, data=payload, timeout=10)
                if res.status_code == 200:
                    data = res.json()
                    if not all_api_services:
                        all_api_services.extend(data)

                    services_container.controls.clear()
                    
                    matched_services = []
                    p_name = platform_name.strip().lower()

                    keywords = []
                    if p_name == "انستغرام":
                        keywords = ["انستغرام", "انستقرام", "إنستغرام", "instagram", "insta"]
                    elif p_name == "فيسبوك":
                        keywords = ["فيسبوك", "فيس بوك", "facebook", "fb"]
                    elif p_name == "تليجرام":
                        keywords = ["تليجرام", "تلغرام", "تيليجرام", "telegram", "tg"]
                    elif p_name == "تيك توك":
                        keywords = ["تيك توك", "تيكتوك", "tiktok"]
                    elif p_name == "يوتيوب":
                        keywords = ["يوتيوب", "youtube", "yt"]
                    elif p_name == "سبوتيفاي":
                        keywords = ["سبوتيفاي", "spotify"]
                    elif "تويتر" in p_name or "twitter" in p_name or "x" in p_name:
                        keywords = ["تويتر", "twitter", "x"]
                    else:
                        keywords = [p_name]

                    for item in data:
                        cat = str(item.get('category', '')).lower()
                        name = str(item.get('name', '')).lower()
                        is_match = any(kw in cat or kw in name for kw in keywords)
                        if is_match:
                            matched_services.append(item)
                    
                    if not matched_services:
                        services_container.controls.append(
                            ft.Container(
                                content=ft.Text(f"لا توجد خدمات متاحة حالياً لمنصة {platform_name}", color="#FF2A40", size=13),
                                padding=15
                            )
                        )
                    else:
                        for s in matched_services[:35]:
                            s_short = simplify_service_name(s.get('name', ''), platform_name)
                            rate_val = float(s.get('rate', 0.0))
                            
                            btn_card = ft.Container(
                                content=ft.Row([
                                    ft.Column([
                                        ft.Text(s_short, color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12),
                                        ft.Text(f"المعرف: #{s.get('service')}", color="#8888AA", size=10),
                                    ], spacing=2, expand=True),
                                    ft.Container(
                                        content=ft.Text(f"${rate_val:.2f}", color="black", weight=ft.FontWeight.BOLD, size=11),
                                        bgcolor="#00FFC2",
                                        padding=ft.padding.symmetric(horizontal=10, vertical=6),
                                        border_radius=8
                                    ),
                                    ft.Icon(ft.Icons.ARROW_FORWARD_IOS, color="#8888AA", size=14)
                                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, spacing=10),
                                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF",
                                padding=12,
                                border_radius=10,
                                border=ft.border.all(1, "#202030" if is_dark_mode[0] else "#DDDDDD"),
                                ink=True,
                                on_click=lambda _, serv=s: navigate_to("/order_form", serv)
                            )
                            services_container.controls.append(btn_card)
                else:
                    services_container.controls.clear()
                    services_container.controls.append(ft.Text("تعذر جلب الخدمات من السيرفر!", color="#FF2A40"))
            except Exception as ex:
                services_container.controls.clear()
                services_container.controls.append(ft.Text(f"خطأ في الاتصال بالشبكة: {str(ex)}", color="#FF2A40"))

            try:
                page.update()
            except Exception:
                pass

        services_container.controls.append(
            ft.Container(
                content=loading_ring,
                alignment=ft.alignment.center,
                padding=50
            )
        )

        threading.Thread(target=fetch_api_services, daemon=True).start()

        return ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.IconButton(icon=ft.Icons.ARROW_BACK, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: navigate_to("/dashboard")),
                    ft.Text(f"خدمات {platform_name}", color="white" if is_dark_mode[0] else "black", size=15, weight=ft.FontWeight.BOLD),
                    ft.Row([
                        create_settings_button(),
                        ft.IconButton(icon=ft.Icons.MENU, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: page.open(page.drawer))
                    ], spacing=0)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                padding=10,
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF"
            ),
            ft.Container(
                content=ft.Column([
                    category_card,
                    ft.Container(height=4),
                    services_container
                ], spacing=8),
                padding=12,
                expand=True
            )
        ], expand=True)

    # ================= 6. صفحة تفاصيل الخدمة وإرسال الطلب =================
    def order_form_view(service_data):
        if not service_data:
            service_data = {}

        raw_name = service_data.get('name', 'خدمة غير محددة')
        serv_id = service_data.get('service', '0')
        rate_per_1000 = float(service_data.get('rate', 0.0))
        min_qty = int(service_data.get('min', 100))
        max_qty = int(service_data.get('max', 10000))
        desc_text = service_data.get('description', 'لا يوجد وصف متاح لهذه الخدمة حالياً.')

        service_field = ft.TextField(
            value=f"{raw_name} (ID: {serv_id})",
            read_only=True,
            multiline=True,
            min_lines=2,
            max_lines=5,
            border_radius=10,
            bgcolor="#181824" if is_dark_mode[0] else "#F0F0F5",
            border_color="#333348" if is_dark_mode[0] else "#CCCCCC",
            text_size=13
        )

        desc_box = ft.Container(
            content=ft.Column([
                ft.Text("الوصف:", weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black", size=12),
                ft.Text(desc_text if desc_text else "لا يوجد وصف لهذه الخدمة", color="#AAAAAA", size=11)
            ], spacing=4),
            padding=10,
            border_radius=10,
            bgcolor="#12121D" if is_dark_mode[0] else "#F8F8FD",
            border=ft.border.all(1, "#28283E" if is_dark_mode[0] else "#DDDDDD"),
            width=400
        )

        link_field = ft.TextField(
            label="الرابط",
            hint_text="أدخل رابط الحساب أو المنشور هنا",
            border_radius=10,
            border_color="#2A2A38" if is_dark_mode[0] else "#CCCCCC",
            focused_border_color="#00FFC2",
            bgcolor="#0E0E18" if is_dark_mode[0] else "#FFFFFF"
        )

        qty_field = ft.TextField(
            label="الكمية",
            hint_text=f"بين {min_qty} و {max_qty}",
            border_radius=10,
            border_color="#2A2A38" if is_dark_mode[0] else "#CCCCCC",
            focused_border_color="#00FFC2",
            keyboard_type=ft.KeyboardType.NUMBER,
            bgcolor="#0E0E18" if is_dark_mode[0] else "#FFFFFF"
        )

        limit_info_text = ft.Text(
            f"الحد الأدنى: {min_qty} - الحد الأعلى: {max_qty}",
            color="#8888AA",
            size=11,
            weight=ft.FontWeight.BOLD
        )

        error_warn_text = ft.Text("", color="#FF2A40", size=11, weight=ft.FontWeight.BOLD, visible=False)

        cost_field = ft.TextField(
            value="💲 التكلفة: 0.00$",
            read_only=True,
            border_radius=10,
            bgcolor="#181824" if is_dark_mode[0] else "#F0F0F5",
            border_color="#00FFC2",
            text_size=13
        )

        def on_qty_changed(e):
            val_str = qty_field.value.strip() if qty_field.value else ""
            if not val_str.isdigit():
                cost_field.value = "💲 التكلفة: 0.00$"
                error_warn_text.visible = False
                qty_field.border_color = "#2A2A38" if is_dark_mode[0] else "#CCCCCC"
                page.update()
                return

            q = int(val_str)
            if q < min_qty or q > max_qty:
                error_warn_text.value = f"⚠️ ينبغي أن تكون الكمية بين الحد الأدنى ({min_qty}) والحد الأعلى ({max_qty})"
                error_warn_text.visible = True
                qty_field.border_color = "#FF2A40"
            else:
                error_warn_text.visible = False
                qty_field.border_color = "#00FFC2"

            total_cost = (q / 1000.0) * rate_per_1000
            cost_field.value = f"💲 التكلفة: {total_cost:.3f}$"
            page.update()

        qty_field.on_change = on_qty_changed

        def submit_order(e):
            lnk = link_field.value.strip() if link_field.value else ""
            q_str = qty_field.value.strip() if qty_field.value else ""

            has_err = False
            if not lnk:
                link_field.border_color = "#FF2A40"
                has_err = True
            else:
                link_field.border_color = "#00FFC2"

            if not q_str or not q_str.isdigit():
                qty_field.border_color = "#FF2A40"
                has_err = True
            else:
                qty_field.border_color = "#00FFC2"

            if has_err:
                show_alert("⚠️ يرجى ملء كافة الحقول بشكل صحيح!", "#FF2A40")
                return

            qty = int(q_str)
            if qty < min_qty or qty > max_qty:
                show_alert(f"⚠️ الطلب خارج النطاق المسموح! الحد الأدنى: {min_qty} - الأعلى: {max_qty}", "#FF2A40")
                return

            total_cost = (qty / 1000.0) * rate_per_1000
            u_data = get_user_data(current_user_id[0]) if current_user_id[0] else {"balance": 0.0}

            if u_data["balance"] < total_cost:
                show_custom_dialog(
                    "رصيد غير كافي ⚠️",
                    f"لم يتم اكتمال طلبك!\nرصيدك حالياً بالتطبيق هو: {u_data['balance']:.2f}$\nوالخدمة التي طلبتها سعرها الإجمالي: {total_cost:.3f}$\nيرجى شحن حسابك لتنفيذ الطلب."
                )
                return

            def async_submit():
                update_user_balance(current_user_id[0], total_cost)

                api_order_id = str(random.randint(100000, 999999))
                try:
                    res = requests.post(API_URL, data={
                        'key': API_KEY,
                        'action': 'add',
                        'service': serv_id,
                        'link': lnk,
                        'quantity': qty
                    }, timeout=10)
                    if res.status_code == 200:
                        res_j = res.json()
                        if 'order' in res_j:
                            api_order_id = str(res_j['order'])
                except Exception as ex:
                    print("API order err:", ex)

                serv_type = "مجانية" if total_cost == 0 else "مدفوعة"
                save_order(current_user_id[0], api_order_id, raw_name, serv_type, lnk, qty, total_cost)

                last_order_info[0] = {
                    "service_name": raw_name,
                    "link": lnk,
                    "quantity": qty,
                    "cost": total_cost,
                    "service_type": serv_type
                }

                show_top_notification(
                    "تم ارسال طلبك وخصم من رصيدك",
                    f"التكلفة: ${total_cost:.3f} | لخدمة {current_platform[0]}"
                )

                navigate_to("/dashboard")

            threading.Thread(target=async_submit, daemon=True).start()

        send_btn = ft.Container(
            content=ft.ElevatedButton(
                "إرسال الطلب 🚀",
                bgcolor="transparent",
                color="white",
                width=400,
                height=46,
                style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10)),
                on_click=submit_order
            ),
            border_radius=10,
            bgcolor="#4D8B5CF6",
            border=ft.border.all(1.2, "#8B5CF6"),
            shadow=ft.BoxShadow(blur_radius=8, color="#4D8B5CF6")
        )

        return ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.IconButton(icon=ft.Icons.ARROW_BACK, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: navigate_to("/services", current_platform[0])),
                    ft.Text(current_platform[0], color="white" if is_dark_mode[0] else "black", size=15, weight=ft.FontWeight.BOLD),
                    ft.Row([
                        create_settings_button(),
                        ft.IconButton(icon=ft.Icons.MENU, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: page.open(page.drawer))
                    ], spacing=0)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                padding=10,
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF"
            ),
            ft.Container(
                content=ft.Column([
                    ft.Text("الخدمة المختارة:", weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black", size=13),
                    service_field,
                    desc_box,
                    link_field,
                    qty_field,
                    limit_info_text,
                    error_warn_text,
                    cost_field,
                    ft.Container(height=10),
                    send_btn
                ], spacing=10, scroll=ft.ScrollMode.AUTO),
                padding=15,
                expand=True
            )
        ], expand=True)

    # ================= 7. واجهة سجل الطلبات =================
    def orders_history_view():
        orders_list_container = ft.Column(scroll=ft.ScrollMode.AUTO, spacing=12, expand=True)
        orders_data = get_user_orders(current_user_id[0]) if current_user_id[0] else []

        def check_and_update_status(db_id, api_ord_id):
            def async_update():
                try:
                    res = requests.post(API_URL, data={
                        'key': API_KEY,
                        'action': 'status',
                        'order': api_ord_id
                    }, timeout=10)
                    if res.status_code == 200:
                        res_j = res.json()
                        st = res_j.get('status', 'قيد الانتظار')
                        
                        status_translation = {
                            "Pending": "قيد الانتظار",
                            "In progress": "قيد التنفيذ",
                            "Processing": "قيد المعالجة",
                            "Completed": "مكتمل",
                            "Partial": "مكتمل جزئياً",
                            "Canceled": "ملغي"
                        }
                        new_st = status_translation.get(st, st)
                        start_c = str(res_j.get('start_count', '-'))
                        remains = str(res_j.get('remains', '-'))

                        update_order_status(db_id, new_st, start_c, remains)

                        if new_st in ["مكتمل", "Completed"]:
                            show_top_notification(
                                "تم إكمال طلبك ⚡",
                                "تم اكتمال طلبك بنجاح راجع سجل الطلبات الان"
                            )
                        else:
                            show_alert(f"تم تحديث حالة الطلب إلى: {new_st}", "#00FFC2")

                        navigate_to("/orders_history")
                except Exception as ex:
                    show_alert(f"خطأ أثناء جلب الحالة من الموقع: {str(ex)}", "#FF2A40")

            threading.Thread(target=async_update, daemon=True).start()

        if not orders_data:
            orders_list_container.controls.append(
                ft.Container(
                    content=ft.Column([
                        ft.Icon(ft.Icons.RECEIPT_LONG, color="#666", size=48),
                        ft.Text("لا يوجد لديك أي طلبات شخصية سابقة!", color="#888", size=13, weight=ft.FontWeight.BOLD)
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                    padding=40,
                    alignment=ft.alignment.center
                )
            )
        else:
            for ord_row in orders_data:
                api_ord_id, s_name, status, link, cost, qty, start_c, remains, created_at, db_id = ord_row
                
                order_card = ft.Container(
                    content=ft.Column([
                        ft.Row([
                            ft.Icon(ft.Icons.CALENDAR_MONTH, color="#00C8FF", size=16),
                            ft.Text(created_at, color="#00C8FF", size=12, weight=ft.FontWeight.BOLD)
                        ], alignment=ft.MainAxisAlignment.END, spacing=4),
                        
                        ft.Row([
                            ft.Container(
                                content=ft.Text(str(api_ord_id), color="white", weight=ft.FontWeight.BOLD, size=13),
                                bgcolor="#00B2FF",
                                padding=ft.padding.symmetric(horizontal=16, vertical=6),
                                border_radius=12
                            )
                        ], alignment=ft.MainAxisAlignment.CENTER),
                        
                        ft.Row([
                            ft.Text(f"🔥 {s_name}", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=13, text_align=ft.TextAlign.CENTER)
                        ], alignment=ft.MainAxisAlignment.CENTER),
                        
                        ft.Row([
                            ft.Container(
                                content=ft.Text("إلغاء", color="white", size=11, weight=ft.FontWeight.BOLD),
                                bgcolor="#FF2A2A",
                                padding=ft.padding.symmetric(horizontal=12, vertical=5),
                                border_radius=8,
                                ink=True,
                                on_click=lambda _, b_id=db_id: (update_order_status(b_id, "ملغي"), navigate_to("/orders_history"))
                            ),
                            ft.Container(
                                content=ft.Text("تحديث الحالة", color="white", size=11, weight=ft.FontWeight.BOLD),
                                bgcolor="#00B2FF",
                                padding=ft.padding.symmetric(horizontal=10, vertical=5),
                                border_radius=8,
                                ink=True,
                                on_click=lambda _, b_id=db_id, a_id=api_ord_id: check_and_update_status(b_id, a_id)
                            ),
                            ft.Container(
                                content=ft.Text(status, color="#FFD700" if status == "قيد الانتظار" else "#00FFC2", size=12, weight=ft.FontWeight.BOLD),
                                border=ft.border.all(1, "#FFD700" if status == "قيد الانتظار" else "#00FFC2"),
                                padding=ft.padding.symmetric(horizontal=14, vertical=5),
                                border_radius=8
                            )
                        ], alignment=ft.MainAxisAlignment.CENTER, spacing=8),
                        
                        ft.Container(
                            content=ft.Row([
                                ft.Text(link, color="#00B2FF", size=11, weight=ft.FontWeight.BOLD, overflow=ft.TextOverflow.ELLIPSIS),
                                ft.Icon(ft.Icons.LINK, color="#00B2FF", size=14)
                            ], alignment=ft.MainAxisAlignment.CENTER, spacing=4),
                            bgcolor="#1E202E" if is_dark_mode[0] else "#EAEAEA",
                            padding=8,
                            border_radius=10,
                            alignment=ft.alignment.center
                        ),
                        
                        ft.Row([
                            ft.Container(
                                content=ft.Column([
                                    ft.Row([ft.Text("التكلفة:", color="#00B2FF", size=11, weight=ft.FontWeight.BOLD), ft.Icon(ft.Icons.LOCAL_OFFER, color="#00B2FF", size=12)], alignment=ft.MainAxisAlignment.CENTER),
                                    ft.Text(f"{cost:.3f}", color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12)
                                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                                bgcolor="#1E202E" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=8, expand=True
                            ),
                            ft.Container(
                                content=ft.Column([
                                    ft.Row([ft.Text("الكمية:", color="#00B2FF", size=11, weight=ft.FontWeight.BOLD), ft.Icon(ft.Icons.FORMAT_LIST_BULLETED, color="#00B2FF", size=12)], alignment=ft.MainAxisAlignment.CENTER),
                                    ft.Text(str(qty), color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12)
                                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                                bgcolor="#1E202E" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=8, expand=True
                            ),
                        ], spacing=8),
                        
                        ft.Row([
                            ft.Container(
                                content=ft.Column([
                                    ft.Row([ft.Text("عدد البدء:", color="#00B2FF", size=11, weight=ft.FontWeight.BOLD), ft.Icon(ft.Icons.BAR_CHART, color="#00B2FF", size=12)], alignment=ft.MainAxisAlignment.CENTER),
                                    ft.Text(start_c, color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12)
                                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                                bgcolor="#1E202E" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=8, expand=True
                            ),
                            ft.Container(
                                content=ft.Column([
                                    ft.Row([ft.Text("المتبقي:", color="#00B2FF", size=11, weight=ft.FontWeight.BOLD), ft.Icon(ft.Icons.TIMER, color="#00B2FF", size=12)], alignment=ft.MainAxisAlignment.CENTER),
                                    ft.Text(str(remains), color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12)
                                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                                bgcolor="#1E202E" if is_dark_mode[0] else "#EAEAEA", padding=8, border_radius=8, expand=True
                            ),
                        ], spacing=8),

                    ], spacing=8),
                    bgcolor="#12131C" if is_dark_mode[0] else "#FFFFFF",
                    padding=12,
                    border_radius=14,
                    border=ft.border.all(1, "#222436" if is_dark_mode[0] else "#CCCCCC")
                )
                orders_list_container.controls.append(order_card)

        return ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.IconButton(icon=ft.Icons.ARROW_BACK, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: navigate_to("/dashboard")),
                    ft.Text("سجل الطلبات الشخصية", color="white" if is_dark_mode[0] else "black", size=15, weight=ft.FontWeight.BOLD),
                    ft.Row([
                        create_settings_button(),
                        ft.IconButton(icon=ft.Icons.MENU, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: page.open(page.drawer))
                    ], spacing=0)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                padding=10,
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF"
            ),
            ft.Container(
                content=orders_list_container,
                padding=12,
                expand=True
            )
        ], expand=True)

    # ================= 8. واجهة الخدمات المجانية =================
    def free_services_view():
        free_container = ft.Column(scroll=ft.ScrollMode.AUTO, spacing=10, expand=True)
        loading_ring = ft.ProgressRing(color="#00FFC2", width=36, height=36)

        def fetch_free_services():
            try:
                res = requests.post(API_URL, data={'key': API_KEY, 'action': 'services'}, timeout=10)
                if res.status_code == 200:
                    data = res.json()
                    free_container.controls.clear()
                    
                    free_items = [s for s in data if float(s.get('rate', 1.0)) == 0.0 or "مجاني" in str(s.get('name', '')) or "free" in str(s.get('name', '')).lower()]
                    
                    if not free_items:
                        free_items = [
                            {"service": "3060", "name": "أعضاء تليجرام فوري مجاني 🔥", "rate": "0.00", "min": "50", "max": "500", "description": "خدمة تجريبية مجانية سريعة."},
                            {"service": "3061", "name": "مشاهدات انستغرام مجانية 🎁", "rate": "0.00", "min": "100", "max": "1000", "description": "خدمة مشاهدات مجانية للجميع."},
                        ]

                    for s in free_items:
                        btn_card = ft.Container(
                            content=ft.Row([
                                ft.Column([
                                    ft.Text(s.get('name', ''), color="white" if is_dark_mode[0] else "black", weight=ft.FontWeight.BOLD, size=12),
                                    ft.Text(f"المعرف: #{s.get('service')} - مجاناً بالكامل", color="#00FFC2", size=10),
                                ], spacing=2, expand=True),
                                ft.Container(
                                    content=ft.Text("0.00$", color="black", weight=ft.FontWeight.BOLD, size=11),
                                    bgcolor="#00FFC2",
                                    padding=ft.padding.symmetric(horizontal=10, vertical=6),
                                    border_radius=8
                                ),
                                ft.Icon(ft.Icons.ARROW_FORWARD_IOS, color="#8888AA", size=14)
                            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, spacing=10),
                            bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF",
                            padding=12,
                            border_radius=10,
                            border=ft.border.all(1, "#00FFC2"),
                            ink=True,
                            on_click=lambda _, serv=s: navigate_to("/order_form", serv)
                        )
                        free_container.controls.append(btn_card)
            except Exception:
                free_container.controls.clear()
                free_container.controls.append(ft.Text("تعذر جلب الخدمات المجانية!", color="#FF2A40"))

            try:
                page.update()
            except Exception:
                pass

        free_container.controls.append(
            ft.Container(content=loading_ring, alignment=ft.alignment.center, padding=40)
        )

        threading.Thread(target=fetch_free_services, daemon=True).start()

        return ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.IconButton(icon=ft.Icons.ARROW_BACK, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: navigate_to("/dashboard")),
                    ft.Text("الخدمات المجانية 🎁", color="white" if is_dark_mode[0] else "black", size=15, weight=ft.FontWeight.BOLD),
                    ft.Row([
                        create_settings_button(),
                        ft.IconButton(icon=ft.Icons.MENU, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: page.open(page.drawer))
                    ], spacing=0)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                padding=10,
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF"
            ),
            ft.Container(
                content=free_container,
                padding=12,
                expand=True
            )
        ], expand=True)

    # ================= 9. صفحة من نحن =================
    def about_view():
        return ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.IconButton(icon=ft.Icons.ARROW_BACK, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: navigate_to("/dashboard")),
                    ft.Text("من نحن", color="white" if is_dark_mode[0] else "black", size=15, weight=ft.FontWeight.BOLD),
                    ft.Row([
                        create_settings_button(),
                        ft.IconButton(icon=ft.Icons.MENU, icon_color="white" if is_dark_mode[0] else "black", on_click=lambda _: page.open(page.drawer))
                    ], spacing=0)
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                padding=10,
                bgcolor="#12121C" if is_dark_mode[0] else "#FFFFFF"
            ),
            ft.Container(
                content=ft.Column([
                    create_app_logo_badge(90),
                    ft.Text("Follower X - فولور اكس", size=18, weight=ft.FontWeight.BOLD, color="white" if is_dark_mode[0] else "black"),
                    ft.Text("تطبيقك الأفضل لتطوير وزيادة المتابعين والتفاعل على جميع منصات التواصل الاجتماعي بسرعات عالية وأسعار منافسة.", text_align=ft.TextAlign.CENTER, color="#AAAAAA", size=13),
                    ft.Divider(color="#222233"),
                    ft.Text("الإصدار: 1.0.0", color="#00FFC2", weight=ft.FontWeight.BOLD, size=12),
                    ft.ElevatedButton("تواصل معنا عبر تلغرام", icon=ft.Icons.SEND, bgcolor="#0088CC", color="white", on_click=lambda _: page.launch_url("https://t.me/ffmrd"))
                ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=15),
                padding=25,
                expand=True
            )
        ], expand=True)

    # التشغيل البدائي
    navigate_to("/splash")

ft.app(target=main)
