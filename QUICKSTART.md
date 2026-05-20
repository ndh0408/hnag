# 🚀 HNAG Quick Start — Triển khai thật

> **Domain:** `tothanhthuy.cloud` · **Backend:** ServerLinux · **iOS:** macOS VM · **Email owner:** huy04082000@gmail.com

---

## 0. ⚠ KHẨN — Bảo mật trước

Bạn đã share DNS API key trong chat → **key đó coi như đã lộ**. Phải:

1. Vào Cloudflare/Porkbun dashboard → **REVOKE token cũ NGAY**
2. Tạo token mới với scope giới hạn (`Zone:DNS:Edit` cho `tothanhthuy.cloud`)
3. **KHÔNG paste vào file nào trong repo**. Chỉ:
   - GitHub repo secret: `CF_API_TOKEN`
   - Local env: `~/.config/hnag/dns.env` (chmod 600)

---

## 1. Local dev (5 phút) — chạy backend trên máy bạn

```bash
cd code/backend
cp .env.example .env
# Đổi DATABASE_URL, JWT_SECRET, OPENAI_API_KEY

cd ../infra
docker compose -f docker-compose.yml up -d postgres redis

cd ../backend
npm install
npx prisma generate
psql "$DATABASE_URL" -f ../sql/01_schema.sql
psql "$DATABASE_URL" -f ../sql/02_seed_data.sql
npm run start:dev
```

Test:
```bash
curl http://localhost:4000/health        # → {success:true,data:{ok:true,db:true,cache:true}}
```

---

## 2. Chuẩn bị server (1 lần — ~15 phút)

```bash
ssh ServerLinux

# Bootstrap (Docker, UFW, swap, sysctl, systemd unit)
sudo bash <(curl -fsSL https://raw.githubusercontent.com/<your-user>/<repo>/main/code/infra/server/bootstrap.sh)

# Copy code
sudo mkdir -p /opt/hnag && sudo chown $USER /opt/hnag
exit
```

Trên máy local:
```bash
scp -r code/infra/server/* code/sql/* ServerLinux:/opt/hnag/init/
```

Trên server:
```bash
ssh ServerLinux
cd /opt/hnag
cp hnag.env.example hnag.env
nano hnag.env                  # điền tất cả secrets
```

---

## 3. Setup DNS (3 phút)

Trên máy local — token mới đã tạo ở bước 0:
```bash
export CF_API_TOKEN='paste-NEW-token'
export PUBLIC_IP='<server-public-IPv4>'    # KHÔNG dùng Tailscale IP 100.x
bash code/infra/dns/setup-dns.sh
```

DNS sẽ propagate trong ~5-10 phút. Verify:
```bash
dig +short api.tothanhthuy.cloud
```

---

## 4. Issue TLS (lần đầu — 2 phút sau khi DNS propagate)

```bash
ssh ServerLinux
cd /opt/hnag

# Start nginx (chưa có cert → fail certbot lần đầu là OK)
docker compose -f docker-compose.prod.yml up -d nginx

docker compose -f docker-compose.prod.yml run --rm certbot certonly \
  --webroot --webroot-path /var/www/certbot \
  -d api.tothanhthuy.cloud \
  -d dash.tothanhthuy.cloud \
  -d app.tothanhthuy.cloud \
  -d cdn.tothanhthuy.cloud \
  -d tothanhthuy.cloud \
  -d www.tothanhthuy.cloud \
  --email huy04082000@gmail.com --agree-tos --non-interactive

docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

---

## 5. Build backend image + deploy lần đầu

Trên máy local:
```bash
cd code/backend
docker build -t ghcr.io/<your-user>/hnag-backend:latest .
docker login ghcr.io -u <your-user>          # paste PAT scope: write:packages
docker push ghcr.io/<your-user>/hnag-backend:latest
```

Trên server:
```bash
ssh ServerLinux
cd /opt/hnag
echo $GHCR_TOKEN | docker login ghcr.io -u <your-user> --password-stdin
GHCR_OWNER=<your-user> HNAG_VERSION=latest ./deploy.sh
```

Verify:
```bash
curl https://api.tothanhthuy.cloud/health
```

---

## 6. CI/CD auto-deploy (1 lần config)

Vào GitHub repo settings → Secrets:
- `TS_OAUTH_CLIENT_ID` + `TS_OAUTH_SECRET` (Tailscale OAuth — tạo tại admin.tailscale.com)
- `SERVER_SSH_KEY` (private key của `huy@ServerLinux` — deploy-only key)
- `GHCR_TOKEN` (Personal Access Token scope `read:packages` để server pull được)
- Cloudflare/Porkbun: `CF_API_TOKEN` *(nếu cần CI tự đổi DNS)*

Sau đó: push lên `main` → GitHub Actions tự build → push GHCR → SSH server → deploy.

---

## 7. iOS TestFlight build (1 lần config)

Trên macOS VM:
```bash
ssh vm
bash <(curl -fsSL https://raw.githubusercontent.com/<your-user>/<repo>/main/code/flutter/ios/setup-on-vm.sh)
# Sau đó: cài Xcode từ App Store thủ công, accept license
```

GitHub Secrets cần thêm:
- `VM_SSH_KEY` (private key của `ndh0408@vm`)
- App Store Connect API key: `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_CONTENT` (tải từ App Store Connect → Users and Access → Keys)
- `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_ITC_TEAM_ID`, `APPLE_APP_ID`

Trigger TestFlight build:
- Push code lên `develop` → auto build TestFlight beta
- Hoặc Actions tab → "iOS · TestFlight via VM" → Run workflow → chọn lane `beta`

Sau ~15 phút bạn nhận email "Build available on TestFlight" → cài app TestFlight từ App Store → đăng nhập → build có sẵn.

---

## 8. Owner Dashboard

```bash
cd code/owner-dashboard
cp .env.example .env
npm install
npm run dev          # http://localhost:3000

# Production: build image
docker build -t ghcr.io/<your-user>/hnag-owner-dashboard:latest .
docker push ghcr.io/<your-user>/hnag-owner-dashboard:latest
```

Deploy bằng cùng `deploy.sh` trên server (đã có service `owner-dashboard` trong docker-compose).

---

## 9. Data ingestion (sau MVP)

```bash
cd code/ingestion
# Chạy Airflow trên server hoặc VM riêng:
docker run -d --name airflow-hnag \
  -e AIRFLOW__CORE__EXECUTOR=LocalExecutor \
  -e TIKTOK_ACCESS_TOKEN='your-token' \
  -e FSQ_API_KEY='your-key' \
  -e OPENAI_API_KEY='your-key' \
  -v $PWD/dags:/opt/airflow/dags \
  -v $PWD/hnag_ingestion:/opt/airflow/hnag_ingestion \
  -p 8080:8080 \
  apache/airflow:2.9.3
```

DAGs đã viết:
- `tiktok_viral_food_vn` — hourly
- `foursquare_restaurants_vn` — weekly

---

## 10. Monitor & debug

```bash
# Logs
ssh ServerLinux 'docker compose -f /opt/hnag/docker-compose.prod.yml logs -f backend'

# Database
ssh -L 5432:127.0.0.1:5432 ServerLinux
# Local terminal: psql -h localhost -U hnag hnag

# Web log viewer
ssh -L 9999:127.0.0.1:9999 ServerLinux
# Mở: http://localhost:9999 (dozzle)

# Trạng thái
ssh ServerLinux 'systemctl status hnag'
```

---

## 11. Backup & disaster recovery

- Auto: `deploy.sh` backup DB trước mỗi deploy → `/opt/hnag/backups/YYYYMMDD-HHMMSS/`
- Retention: 14 ngày
- Off-site: thiết lập cron sync sang Backblaze B2:
  ```bash
  ssh ServerLinux
  sudo apt install rclone
  rclone config            # tạo remote 'b2'
  echo '0 3 * * * rclone copy /opt/hnag/backups b2:hnag-backups --max-age 7d' | crontab -e
  ```

---

## 12. Checklist trước khi public launch

- [ ] DNS đã propagate, HTTPS hoạt động cả 4 subdomains
- [ ] Backend `/health` trả 200, latency < 100ms từ Sài Gòn/Hà Nội
- [ ] iOS app build thành công TestFlight, đã cài + login được
- [ ] Android APK build, test trên ≥2 device
- [ ] Owner Dashboard accessible tại `dash.tothanhthuy.cloud`
- [ ] Smoke test: signup → onboarding → AI suggest → save → order intent
- [ ] Sentry hook + Datadog APM nhận events
- [ ] Backup tự động chạy, restore test pass
- [ ] Privacy policy + ToS link hiển thị trong app
- [ ] App Store screenshots, description tiếng Việt
- [ ] Privacy questionnaire App Store đã điền

---

## Câu hỏi nhanh

**Q: Server cần spec gì?**
A: Tier-1 launch: 4 vCPU / 8GB RAM / 100GB SSD đủ cho 10K MAU. 100K MAU cần 8 vCPU / 16GB RAM.

**Q: AWS Terraform khi nào cần?**
A: Sau khi đạt ~100K MAU hoặc cần multi-region. Hiện tại self-host rẻ hơn 20×.

**Q: TestFlight cho ai test được?**
A: Internal (25 người, tự thêm trong App Store Connect) → External (10K người, cần Apple review 1-2 ngày cho build đầu).

**Q: Tốn bao nhiêu tiền/tháng giai đoạn launch?**
- Server: ~$40 (Hetzner CX31 hoặc Vultr 4vCPU)
- Domain: ~$10/năm
- TLS: free (Let's Encrypt)
- AI: ~$50-300 tuỳ usage (10K MAU)
- OpenWeather/Mapbox: ~$20
- **Tổng:** ~$100-400/tháng cho 10K MAU
