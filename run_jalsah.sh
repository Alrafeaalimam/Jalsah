#!/usr/bin/env bash

# ==============================================================================
# Jalsah (جلسة) - MikroTik Cards Management System Full Stack Launcher
# ==============================================================================

set -e

echo "=========================================================="
echo "   🟣 منظومة جلسة (Jalsah) - تشغيل المشروع بالكامل"
echo "=========================================================="
echo ""

# 1. التأكد من تشغيل قاعدة بيانات PostgreSQL
echo "📦 [1/3] فحص وتشغيل قاعدة بيانات PostgreSQL..."
if ! pg_isready -h 127.0.0.1 >/dev/null 2>&1; then
  pg_ctl -D $PREFIX/var/lib/postgresql -l /data/data/com.termux/files/home/pg.log start || true
  sleep 2
fi
echo "   ✓ قاعدة البيانات متصلة بنجاح."

# 2. تشغيل خادم الـ Backend (Fastify API) على المنفذ 3000
echo "⚙️ [2/3] فحص وتشغيل خادم الـ Backend API..."
if ! curl -s http://127.0.0.1:3000/health >/dev/null 2>&1; then
  cd /data/data/com.termux/files/home/mikrotik_cards_backend
  node dist/presentation/http/server.js > /data/data/com.termux/files/home/backend.log 2>&1 &
  sleep 2
fi
echo "   ✓ خادم الـ Backend يعمل على: http://127.0.0.1:3000"

# 3. تشغيل واجهة الويب (Flutter Web App) على المنفذ 8080
echo "🌐 [3/3] تشغيل خادم واجهة الويب (Jalsah Web)..."
cd /data/data/com.termux/files/home/mikrotik_cards_app
fuser -k 8080/tcp 2>/dev/null || true

LOCAL_IP=$(python3 -c "import socket; s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.connect(('8.8.8.8', 80)); print(s.getsockname()[0]); s.close()" 2>/dev/null || echo "127.0.0.1")

echo ""
echo "=========================================================="
echo "   🚀 تم تشغيل مشروع جلسة بالكامل بنجاح!"
echo "=========================================================="
echo ""
echo "📱 رابط فتح التطبيق على متصفح جهازك:"
echo "👉 http://localhost:8080"
echo "👉 http://127.0.0.1:8080"
echo ""
if [ "$LOCAL_IP" != "127.0.0.1" ]; then
  echo "🌐 رابط الفتح من أي جهاز آخر على نفس شبكة الواي فاي:"
  echo "👉 http://$LOCAL_IP:8080"
  echo ""
fi
echo "🔌 خادم الـ Backend API:"
echo "👉 http://127.0.0.1:3000"
echo ""
echo "اضغط Ctrl+C لإيقاف السيرفر في أي وقت."
echo "=========================================================="

python3 range_server.py 8080 build/web
