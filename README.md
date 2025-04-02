

### 📥 **نحوه استفاده از اسکریپت روی سرور**  
پس از آپلود اسکریپت به GitHub، از این دستورات برای اجرا استفاده کنید:  

```bash
# 1. دانلود اسکریپت از GitHub
wget https://raw.githubusercontent.com/username/3xui-telegram-bot/main/install_3xui_bot.sh

# 2. دادن مجوز اجرا
chmod +x install_3xui_bot.sh

# 3. اجرای اسکریپت
sudo ./install_3xui_bot.sh
```

---

### 🔧 **تنظیمات پیشرفته (اختیاری)**  
1. **افزودن `README.md`** برای راهنمای استفاده:  
   ```markdown
   # ربات مدیریت 3X-UI

   ## 📌 راهنمای نصب
   ```bash
   wget https://raw.githubusercontent.com/username/3xui-telegram-bot/main/install_3xui_bot.sh
   chmod +x install_3xui_bot.sh
   sudo ./install_3xui_bot.sh
   ```

   ## ✨ ویژگی‌ها
   - پشتیبانی از چندین پنل 3X-UI
   - وب اسکرپینگ خودکار
   - مدیریت مالکیت اکانت‌ها
   ```

2. **اضافه کردن `.gitignore`** برای فایل‌های حساس:  
   ```
   config.json
   *.db
   venv/
   ```

3. **بروزرسانی خودکار اسکریپت**:  
   - می‌توانید یک سیستم `update.sh` بسازید که آخرین نسخه اسکریپت را از GitHub دانلود کند.  

---

### ❓ **اگر مشکل داشتید**  
- **خطای `404` در دانلود**: مطمئن شوید آدرس ریپو و نام فایل درست است.  
- **دسترسی رد شد**: اگر ریپو **Private** است، باید از **GitHub Token** استفاده کنید:  
  ```bash
  wget https://raw.githubusercontent.com/username/3xui-telegram-bot/main/install_3xui_bot.sh?token=YOUR_TOKEN
  ```

---

✅ **تمام شد!** حالا می‌توانید اسکریپت را از هر سروری اجرا کنید.  
اگر نیاز به راهنمایی بیشتر دارید، بپرسید! 😊
