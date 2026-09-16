@echo off
title تشغيل منصة PitchUp بالكامل
color 0A
echo ====================================================
echo        جاري تشغيل منصة PitchUp الرياضية
echo ====================================================
echo 1. تشغيل السيرفر وقاعدة البيانات (Port 3001)...
start "PitchUp Backend Engine" cmd /k "cd backend && npm run dev"

timeout /t 3 /nobreak >nul

echo 2. تشغيل لوحة تحكم الإدارة العليا (Port 3000)...
start "PitchUp Super Admin" cmd /k "cd web-dashboard && npm run dev"

timeout /t 5 /nobreak >nul

echo ====================================================
echo  تم التشغيل بنجاح!
echo  لوحة التحكم للمدير: http://localhost:3000
echo ====================================================
start http://localhost:3000
pause
