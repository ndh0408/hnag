# DNS setup — `tothanhthuy.cloud`

## ⚠ SECURITY FIRST

**KHÔNG BAO GIỜ commit API key vào git.** Đã thấy bạn paste key trong chat — coi như key đó **đã bị lộ**, nên:

1. Vào DNS provider → **REVOKE token cũ ngay**
2. Tạo token mới với scope giới hạn:
   - Cloudflare: chỉ `Zone:DNS:Edit` cho zone `tothanhthuy.cloud`
   - Porkbun: enable API access cho domain này, copy mới
3. Token mới:
   - Lưu vào `~/.config/hnag/dns.env` (chmod 600) cho local
   - Lưu vào GitHub repo secret `CF_API_TOKEN` (or `PORKBUN_API_KEY` + `PORKBUN_SECRET_KEY`)
   - **Không paste vào file nào trong repo**

## Setup DNS (1 lần)

```bash
# Local machine (your Windows/Mac/Linux)
export CF_API_TOKEN='paste-new-token-here'
export PUBLIC_IP='1.2.3.4'  # actual public IPv4 of ServerLinux

bash code/infra/dns/setup-dns.sh
```

Records created:
- `tothanhthuy.cloud` (apex) → IP
- `www.tothanhthuy.cloud` → IP
- `api.tothanhthuy.cloud` → IP
- `dash.tothanhthuy.cloud` → IP
- `app.tothanhthuy.cloud` → IP
- `cdn.tothanhthuy.cloud` → IP

## Issue TLS certs (after DNS propagates ~5 min)

```bash
ssh ServerLinux
cd /opt/hnag
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

Certbot service tự renew mỗi 12 tiếng (see `docker-compose.prod.yml`).

## Verify

```bash
dig +short api.tothanhthuy.cloud
curl -fsS https://api.tothanhthuy.cloud/health
curl -fsSI https://api.tothanhthuy.cloud   # check TLS
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `dig` returns nothing | DNS chưa propagate, đợi 5–10 phút |
| Certbot fails "challenge timeout" | Check port 80 mở (UFW: `sudo ufw allow 80/tcp`) |
| Nginx 502 | `docker compose logs backend` xem container có healthy không |
| Cert renew fails | Check disk space `df -h`, log: `docker compose logs certbot` |
