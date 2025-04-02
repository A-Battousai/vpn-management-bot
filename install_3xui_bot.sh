#!/bin/bash

# رنگ‌های برای نمایش زیباتر
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# تابع برای نمایش خطا
error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# تابع برای نمایش موفقیت
success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

# تابع برای نمایش هشدار
warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# بررسی دسترسی root
if [ "$(id -u)" -ne 0 ]; then
    error "این اسکریپت باید با دسترسی root اجرا شود."
fi

# به روزرسانی سیستم
echo -e "${YELLOW}در حال به روزرسانی سیستم...${NC}"
apt update && apt upgrade -y || error "به روزرسانی سیستم با شکست مواجه شد."

# نصب پیش‌نیازها
echo -e "${YELLOW}در حال نصب پیش‌نیازها...${NC}"
apt install -y python3 python3-venv python3-pip git sqlite3 curl chromium-chromedriver || error "نصب پیش‌نیازها با شکست مواجه شد."

# دریافت اطلاعات پنل‌ها
echo -e "\n${GREEN}تنظیمات پنل‌های 3x-ui${NC}"
read -p "تعداد پنل‌های 3x-ui که می‌خواهید مدیریت کنید: " PANEL_COUNT

PANELS=()
for ((i=1; i<=PANEL_COUNT; i++)); do
    echo -e "\n${YELLOW}اطلاعات پنل شماره $i${NC}"
    read -p "آدرس IP یا دامنه پنل: " PANEL_IP
    read -p "پورت پنل (پیشفرض: 54321): " PANEL_PORT
    PANEL_PORT=${PANEL_PORT:-54321}
    read -p "نام کاربری پنل (پیشفرض: admin): " PANEL_USERNAME
    PANEL_USERNAME=${PANEL_USERNAME:-admin}
    read -p "رمز عبور پنل: " PANEL_PASSWORD
    read -p "آدرس URI Path (در صورت وجود، پیشفرض: /): " PANEL_PATH
    PANEL_PATH=${PANEL_PATH:-/}
    
    PANELS+=("$PANEL_IP:$PANEL_PORT:$PANEL_USERNAME:$PANEL_PASSWORD:$PANEL_PATH")
done

# دریافت اطلاعات ربات تلگرام
echo -e "\n${GREEN}اطلاعات ربات تلگرام${NC}"
read -p "توکن ربات تلگرام: " TELEGRAM_TOKEN

# دریافت آیدی ادمین
echo -e "\n${YELLOW}دریافت آیدی ادمین${NC}"
read -p "آیا می‌خواهید آیدی ادمین را از @userinfobot دریافت کنید؟ (y/n): " GET_ID_CHOICE

if [[ "$GET_ID_CHOICE" =~ ^[Yy]$ ]]; then
    echo -e "\nلطفاً به ربات @userinfobot در تلگرام مراجعه کنید و آیدی عددی خود را دریافت نمایید."
    read -p "آیدی عددی ادمین: " ADMIN_ID
else
    read -p "آیدی عددی ادمین را وارد کنید: " ADMIN_ID
fi

# ایجاد پوشه پروژه
PROJECT_DIR="/opt/3xui_manager"
echo -e "\n${YELLOW}در حال ایجاد پوشه پروژه در $PROJECT_DIR...${NC}"
mkdir -p $PROJECT_DIR || error "ایجاد پوشه پروژه با شکست مواجه شد."
cd $PROJECT_DIR || error "ورود به پوشه پروژه با شکست مواجه شد."

# ایجاد محیط مجازی
echo -e "${YELLOW}در حال ایجاد محیط مجازی پایتون...${NC}"
python3 -m venv venv || error "ایجاد محیط مجازی با شکست مواجه شد."
source venv/bin/activate || error "فعال‌سازی محیط مجازی با شکست مواجه شد."

# نصب کتابخانه‌های مورد نیاز با نسخه‌های سازگار
echo -e "${YELLOW}در حال نصب کتابخانه‌های پایتون...${NC}"
pip install python-telegram-bot==20.3 requests beautifulsoup4 selenium sqlalchemy || error "نصب کتابخانه‌ها با شکست مواجه شد."

# ایجاد فایل پیکربندی
echo -e "${YELLOW}در حال ایجاد فایل پیکربندی...${NC}"
cat > config.json <<EOF
{
    "telegram_token": "$TELEGRAM_TOKEN",
    "admin_id": $ADMIN_ID,
    "panels": [
EOF

for panel in "${PANELS[@]}"; do
    IFS=':' read -r ip port username password path <<< "$panel"
    cat >> config.json <<EOF
        {
            "ip": "$ip",
            "port": "$port",
            "username": "$username",
            "password": "$password",
            "path": "$path"
        },
EOF
done

# حذف کامای آخر
sed -i '$ s/,$//' config.json

cat >> config.json <<EOF
    ]
}
EOF

# ایجاد فایل اصلی ربات با اصلاحات نهایی
echo -e "${YELLOW}در حال ایجاد فایل اصلی ربات...${NC}"
cat > 3xui_manager.py <<'EOF'
import json
import sqlite3
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Updater, CommandHandler, CallbackContext, CallbackQueryHandler, MessageHandler
from telegram.ext import filters as Filters
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from urllib.parse import urljoin
import time
import logging

# تنظیمات لاگ
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# تنظیمات اولیه
with open('config.json') as f:
    config = json.load(f)

# تنظیمات Selenium برای وب اسکرپینگ
chrome_options = Options()
chrome_options.add_argument("--headless")
chrome_options.add_argument("--no-sandbox")
chrome_options.add_argument("--disable-dev-shm-usage")

# اتصال به دیتابیس
conn = sqlite3.connect('3xui_manager.db')
cursor = conn.cursor()
cursor.execute('''
    CREATE TABLE IF NOT EXISTS accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vpn_code TEXT UNIQUE,
        user_id INTEGER,
        panel_id INTEGER,
        data_limit REAL,
        used_data REAL,
        expiry_date TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
''')
conn.commit()

def get_panel_url(panel, path=''):
    base = f"http://{panel['ip']}:{panel['port']}"
    return urljoin(base, panel['path'] + path)

def login_to_panel(panel):
    try:
        driver = webdriver.Chrome(options=chrome_options)
        driver.get(get_panel_url(panel, 'login'))
        
        # پر کردن فرم لاگین
        username_field = driver.find_element(By.NAME, 'username')
        password_field = driver.find_element(By.NAME, 'password')
        
        username_field.send_keys(panel['username'])
        password_field.send_keys(panel['password'])
        
        # کلیک روی دکمه ورود
        login_button = driver.find_element(By.XPATH, "//button[@type='submit']")
        login_button.click()
        
        # منتظر بمانید تا لاگین کامل شود
        time.sleep(3)
        return driver
        
    except Exception as e:
        logger.error(f"خطا در ورود به پنل: {str(e)}")
        return None

def get_account_info(driver, vpn_code):
    try:
        # رفتن به صفحه مدیریت اکانت‌ها
        driver.get(get_panel_url(panel, 'inbounds'))
        time.sleep(3)
        
        # پارس کردن صفحه با BeautifulSoup
        soup = BeautifulSoup(driver.page_source, 'html.parser')
        
        # پیدا کردن اکانت بر اساس کد VPN
        account_row = None
        for row in soup.find_all('tr'):
            if vpn_code in row.text:
                account_row = row
                break
                
        if account_row:
            # استخراج اطلاعات از ردیف جدول
            cells = account_row.find_all('td')
            data_usage = cells[4].get_text(strip=True) if len(cells) > 4 else "N/A"
            expiry_date = cells[5].get_text(strip=True) if len(cells) > 5 else "N/A"
            
            return {
                'data_usage': data_usage,
                'expiry_date': expiry_date
            }
        return None
        
    except Exception as e:
        logger.error(f"خطا در دریافت اطلاعات اکانت: {str(e)}")
        return None

def start(update: Update, context: CallbackContext):
    keyboard = [
        [InlineKeyboardButton("🔍 اطلاعات اکانت", callback_data='account_info')],
        [InlineKeyboardButton("🔋 شارژ اکانت", callback_data='charge')],
        [InlineKeyboardButton("➕ اکانت جدید", callback_data='new_account')]
    ]
    
    update.message.reply_text(
        "به ربات مدیریت 3x-ui خوش آمدید! لطفاً گزینه مورد نظر را انتخاب کنید:",
        reply_markup=InlineKeyboardMarkup(keyboard)
    )

def handle_vpn_code(update: Update, context: CallbackContext):
    vpn_code = update.message.text.strip()
    user_id = update.effective_user.id
    
    # جستجو در تمام پنل‌ها
    for i, panel in enumerate(config['panels']):
        driver = login_to_panel(panel)
        if driver:
            account_info = get_account_info(driver, vpn_code)
            driver.quit()
            
            if account_info:
                # ذخیره اطلاعات در دیتابیس
                cursor.execute('''
                    INSERT OR REPLACE INTO accounts 
                    (vpn_code, user_id, panel_id, data_limit, used_data, expiry_date)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', (vpn_code, user_id, i, 100, 0, account_info['expiry_date']))
                conn.commit()
                
                update.message.reply_text(f"""
✅ اطلاعات اکانت شما:
• سرور: پنل {i+1}
• حجم باقی‌مانده: {account_info['data_usage']}
• تاریخ انقضا: {account_info['expiry_date']}
                """)
                return
    
    update.message.reply_text("❌ کد VPN معتبر نیست یا یافت نشد!")

def button_handler(update: Update, context: CallbackContext):
    query = update.callback_query
    query.answer()
    
    if query.data == 'account_info':
        query.edit_message_text("لطفاً کد VPN خود را ارسال کنید:")
        context.user_data['action'] = 'account_info'
        
    elif query.data == 'charge':
        context.bot.send_message(
            chat_id=config['admin_id'],
            text=f"📢 درخواست شارژ جدید!\nکاربر: @{query.from_user.username}\nآیدی: {query.from_user.id}"
        )
        query.edit_message_text("درخواست شارژ شما به ادمین ارسال شد.")
        
    elif query.data == 'new_account':
        context.bot.send_message(
            chat_id=config['admin_id'],
            text=f"📢 درخواست اکانت جدید!\nکاربر: @{query.from_user.username}\nآیدی: {query.from_user.id}"
        )
        query.edit_message_text("درخواست اکانت جدید شما به ادمین ارسال شد.")

def admin_command(update: Update, context: CallbackContext):
    if update.effective_user.id != config['admin_id']:
        return
    
    command = update.message.text.split()
    if command[0] == '/change_owner' and len(command) == 3:
        vpn_code = command[1]
        new_user_id = int(command[2])
        
        cursor.execute('''
            UPDATE accounts SET user_id = ? WHERE vpn_code = ?
        ''', (new_user_id, vpn_code))
        conn.commit()
        
        update.message.reply_text(f"✅ مالک اکانت {vpn_code} به {new_user_id} تغییر یافت.")

def error_handler(update: Update, context: CallbackContext):
    logger.error(f"خطا در پردازش پیام: {context.error}")

def main():
    updater = Updater(config['telegram_token'])
    dp = updater.dispatcher
    
    dp.add_handler(CommandHandler("start", start))
    dp.add_handler(CommandHandler("change_owner", admin_command))
    dp.add_handler(CallbackQueryHandler(button_handler))
    dp.add_handler(MessageHandler(Filters.TEXT & ~Filters.COMMAND, handle_vpn_code))
    dp.add_error_handler(error_handler)
    
    updater.start_polling()
    updater.idle()

if __name__ == '__main__':
    main()
EOF

# ایجاد سرویس systemd با تنظیمات بهینه
echo -e "${YELLOW}در حال ایجاد سرویس systemd...${NC}"
cat > /etc/systemd/system/3xui-manager.service <<EOF
[Unit]
Description=3X-UI Manager Bot
After=network.target
StartLimitIntervalSec=60

[Service]
User=root
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/python $PROJECT_DIR/3xui_manager.py
Restart=always
RestartSec=10
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
EOF

# فعال‌سازی سرویس
systemctl daemon-reload
systemctl enable 3xui-manager
systemctl start 3xui-manager

# بررسی وضعیت سرویس
echo -e "${YELLOW}بررسی وضعیت سرویس...${NC}"
sleep 5
systemctl status 3xui-manager --no-pager

# نصب تکمیل شد
success "نصب ربات مدیریت 3X-UI با موفقیت انجام شد!"
echo -e "برای مشاهده لاگ‌ها از دستور زیر استفاده کنید:"
echo -e "${GREEN}journalctl -u 3xui-manager -f${NC}"
echo -e "\nاگر خطایی مشاهده کردید، لطفاً گزارش دهید."
