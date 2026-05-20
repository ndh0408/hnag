# 12 — Live Cooking + Voice Assistant ("Hà")

> **Hai tính năng đắt giá nhất về cảm xúc + retention:**
> - **Live Cooking Mode** — biến nhà bếp thành Spotify/Netflix moment.
> - **Voice "Hà"** — giải phóng người dùng khỏi bàn phím khi tay bận.

---

## PART A — VOICE ASSISTANT ("HÀ")

## 1. Voice UX Principles

1. **Latency là cảm xúc.** TTS phải bật trong ≤700ms từ khi user dừng nói.
2. **Hỏi 1 lần, đáp 1 lần.** Không "barge in"; tôn trọng turn.
3. **Tone-aware.** User stress → Hà nói chậm hơn 10%, ấm hơn.
4. **Visible state.** Mic active phải có chỉ báo vật lý (waveform + dot đỏ).
5. **Privacy by design.** Wake word detect on-device; chỉ stream lên server sau khi nhận diện.

---

## 2. Pipeline Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│  USER nói:  "Hey Hà, hôm nay ăn gì?"                              │
└───────────────────────────┬───────────────────────────────────────┘
                            ↓
              ┌─────────────────────────────┐
              │ 1. WAKE WORD (on-device)    │
              │   • Porcupine VN model      │
              │   • Custom keyword: "Hà"    │
              │   • <30ms latency           │
              └─────────────┬───────────────┘
                            ↓
              ┌─────────────────────────────┐
              │ 2. VAD (Voice Activity)     │
              │   • Detect speech start/end │
              │   • Auto-end on silence 800ms│
              └─────────────┬───────────────┘
                            ↓
              ┌─────────────────────────────┐
              │ 3. ASR STREAM (real-time)   │
              │   • Whisper-large-v3 VN     │
              │   • Streamed via WebSocket  │
              │   • Partial transcripts     │
              │   • Latency p50: 400ms      │
              └─────────────┬───────────────┘
                            ↓ final transcript
              ┌─────────────────────────────┐
              │ 4. NLU / Intent             │
              │   • VinBERT-base-vi         │
              │   • LLM fallback (GPT-4o-mini)│
              │   • Tools called as needed  │
              └─────────────┬───────────────┘
                            ↓
              ┌─────────────────────────────┐
              │ 5. ORCHESTRATOR             │
              │   • Routes intent           │
              │   • Calls suggest/order/etc │
              │   • Composes reply (≤30 từ) │
              └─────────────┬───────────────┘
                            ↓
              ┌─────────────────────────────┐
              │ 6. TTS                      │
              │   • VBee VN (primary)       │
              │   • Common phrases cached   │
              │   • Stream audio 24kHz mp3  │
              └─────────────┬───────────────┘
                            ↓
              ┌─────────────────────────────┐
              │ 7. PLAYBACK + UI            │
              │   • Audio + transcript bubble│
              │   • Suggested cards inline   │
              └─────────────────────────────┘
```

**End-to-end latency budget (p50):** 1.4s — wake → first audio out.

---

## 3. Wake Word (On-device)

### 3.1 Model
- **Porcupine** (Picovoice) — fine-tuned with **300 VN samples saying "Hà"**
- Size: 32 KB, runs on CPU
- False positive: <1 per 4 hours

### 3.2 Privacy
- Mic data **never leaves device** until wake word triggers
- LED/icon indicator when active
- Permission re-prompted quarterly
- "Disable wake word" setting

### 3.3 Alternate triggers
- Long-press FAB (3D Touch friendly)
- Lock-screen shortcut (iOS Shortcuts)
- Apple Watch raise-to-speak
- Car: Siri/Google Assistant deeplink

---

## 4. ASR (Whisper Vietnamese)

### 4.1 Stack
- **Self-hosted Whisper large-v3** fine-tuned on **VinBigData VN audio + HNAG internal**
- Hosted on GPU (g4dn.xlarge) — autoscale 1–8 instances
- WebSocket streaming via [whisper.cpp server](https://github.com/ggerganov/whisper.cpp) custom build

### 4.2 Streaming protocol

```
CLIENT ──(WS)──→ /voice/stream
  Frame: 100ms PCM 16kHz mono chunks
  Header: { user_id, session_id, lang: 'vi' }
  
SERVER ──(WS)──→ CLIENT
  Partial: { type: 'partial', text: '...', confidence: 0.8 }
  Final:   { type: 'final',   text: '...', words: [...] }
```

### 4.3 Vietnamese accuracy targets
- Standard Bắc: WER < 6%
- Trung (Huế, Đà Nẵng): WER < 10%
- Nam: WER < 7%
- Noise (street ambient): WER < 14%

### 4.4 Fallback chain
1. Self-hosted Whisper (primary, low cost)
2. VinAI ASR API (fallback if Whisper down)
3. Google Cloud Speech-to-Text VN (last resort, expensive)

---

## 5. NLU + Intent

Use **2-tier approach**:

```python
async def classify(transcript: str, user_ctx):
    # Tier 1 — local classifier (VinBERT fine-tuned)
    fast = await vinbert_classify(transcript)
    if fast.confidence > 0.85:
        return fast
    
    # Tier 2 — LLM (GPT-4o-mini) for ambiguous
    llm = await llm_intent_classify(transcript, user_ctx)
    return llm
```

**Intent labels:** (see prompt `voice_intent_classifier` in [prompts.json](../code/ai/prompts/prompts.json))

---

## 6. Response Generation

### 6.1 Hà's reply rules (voice)
- **Max 30 từ** (TTS đọc ngắn)
- Always 1 actionable hint at end
- Can call tools (suggest_food, navigate, order)
- Tone-adjusted (emotion field in prompt response)

### 6.2 Audio response structure

```json
{
  "speech": "Trời mưa rồi đó, phở Lý Quốc Sư 600m thôi, đi nhé?",
  "audio_url": "https://cdn.tothanhthuy.cloud/tts/abc.mp3",  // <300KB
  "cards": [{ "card_id": "...", "title": "Phở Lý Quốc Sư" }],
  "actions": [
    { "label": "Đi đến", "deeplink": "hnag://restaurants/..." },
    { "label": "Hỏi tiếp", "stay_in_voice": true }
  ],
  "emotion": "warm"
}
```

---

## 7. TTS Vietnamese

### 7.1 Provider stack
- **VBee VN** — primary (natural, multi-accent Bắc/Trung/Nam)
- **ElevenLabs (multilingual)** — fallback, premium quality
- **Self-hosted Coqui XTTS-v2 fine-tuned VN** — Year 2 cost reduction

### 7.2 Voice personalities

| Mode | Voice ID | Style |
|------|----------|-------|
| Default | VBee-female-bac-warm | Hà 25 tuổi gốc Hà Nội |
| Calm (mood=stress) | VBee-female-bac-soft | Chậm, ấm |
| Playful (mood=vui) | VBee-female-nam-upbeat | Tươi, năng động |
| Premium | ElevenLabs custom HNAG | Cloned voice |
| Saigon dialect | VBee-female-nam | Gốc Sài Gòn |
| Hue dialect | VBee-female-trung | Gốc Huế |

User picks in Settings → Voice.

### 7.3 Cached phrases (cost reduction)

Pre-generated audio for ~200 common phrases (Hà nói hằng ngày):
- "Đặt giao nhé?"
- "Hà đang nghĩ..."
- "Bạn nói lại được không?"
- "Đã thêm vào lưu sau"
- "Sáng nay đói chưa?"

Cache hit rate target: **45% of replies** → tiết kiệm $1000+/tháng.

### 7.4 Audio specs
- Codec: MP3 64kbps mono (đủ nghe cho voice)
- Sample rate: 24 kHz
- Streamed (first byte in ≤500ms)
- Pre-compressed Opus version for slow networks

---

## 8. Voice Assistant UI

### 8.1 State machine

```
IDLE → LISTENING → THINKING → SPEAKING → IDLE
  ▲         │           │          │
  └─────────┴───────────┴──────────┘ (any state → IDLE on close)
```

### 8.2 Visual states

```
IDLE                LISTENING            THINKING            SPEAKING
[Hà orb static]    [Waveform live]      [Pulse + dots]      [Mouth move sync]
Tap to start       Auto on speech       AI processing       Audio playing
Lavender pulse     Orange ripple        Multi-color shift   Orange flow
```

### 8.3 Full-screen layout

```
┌──────────────────────────────────────────────┐
│ ←   Hà — Trợ lý ẩm thực                 ⚙   │
├──────────────────────────────────────────────┤
│                                              │
│                                              │
│                                              │
│              ╭───────────╮                   │
│              │           │  ← Rive orb       │
│              │   Hà 🎤   │     128×128       │
│              │           │                   │
│              ╰───────────╯                   │
│                                              │
│           "Hà đang nghe..."                  │
│                                              │
│   ┌────────────────────────────────────┐    │
│   │ "Hôm nay ăn gì healthy dưới        │    │
│   │  sáu mươi nghìn?"                  │    │
│   └────────────────────────────────────┘    │
│                                              │
│                                              │
│                                              │
│   ┌── Hà replies ──────────────────────┐    │
│   │                                    │    │
│   │  "Salad cá hồi ở Saladbox 600m,   │    │
│   │   45k, healthy đó nha 🥗"          │    │
│   │                                    │    │
│   │  [card preview]                    │    │
│   │  [Xem]  [Đặt giao]  [Chỉ đường]   │    │
│   └────────────────────────────────────┘    │
│                                              │
├──────────────────────────────────────────────┤
│        🎤  Bấm để nói tiếp                   │
└──────────────────────────────────────────────┘
```

### 8.4 Rive orb states (4 animations)

| State | Description |
|-------|-------------|
| Idle | Slow breathing pulse, lavender gradient |
| Listening | Waveform reactive to mic input, orange flow |
| Thinking | Multi-color shift (purple→orange→red), spin |
| Speaking | Wave matches audio amplitude, brighter |

### 8.5 Hands-free conversation
- After response, mic auto-reopens for 3s
- "Nói tiếp đi nha" prompt
- User can stay in voice mode for chains of queries
- Auto-close if no speech for 8s

---

## 9. Use Cases & Sample Conversations

### 9.1 Daily suggest

```
User:  "Hà ơi, hôm nay ăn gì?"
Hà:    "Bụng đói tới mức nào?"
User:  "Đang đói lắm"
Hà:    "Trong khoảng bao nhiêu tiền?"
User:  "Dưới năm mươi"
Hà:    "Bún chả Bà Hai 600m thôi, 45k bao no, đi không?"
       [card preview] [Đặt giao] [Đi ăn]
```

### 9.2 Order intent

```
User:  "Đặt giùm tao tô phở Lý Quốc Sư"
Hà:    "Bò tái hay nạm?"
User:  "Tái nạm gầu"
Hà:    "55k, qua GrabFood — xác nhận?"
User:  "OK"
Hà:    "Hà mở app rồi đó, kéo xuống bấm xác nhận nhé"
       [opens GrabFood deeplink with order pre-filled]
```

### 9.3 Group decision

```
User:  "Hà ơi anh em sắp ăn rồi, không biết chọn gì"
Hà:    "Có mấy người?"
User:  "Bốn đứa"
Hà:    "Để Hà tạo vote nhé, gửi link cho bạn"
       [auto-creates poll, copies invite link to clipboard]
```

### 9.4 Cooking guide (hands-free)

```
User:  "Hà, dạy nấu trứng chiên cà chua đi"
Hà:    "Có bốn bước. Bắt đầu chưa?"
User:  "Rồi"
Hà:    "Bước 1: đập bốn trứng đánh tan, nêm một thìa nước mắm."
       [waits 30s, detects user moving]
       "Xong bước 1, nói 'tiếp' khi sẵn sàng"
User:  "Tiếp"
Hà:    "Bước 2: cà chua thái múi cau, xào mềm với hành lá..."
```

---

## 10. Voice Privacy & Safety

### 10.1 Data lifecycle
- Audio chunks: deleted from RAM after ASR
- Transcript: stored 30 days (training), then anonymized
- TTS audio: not stored on server
- Conversation memory: opt-in for "Premium long-term memory"

### 10.2 User controls
- Pause voice 7 days (Settings)
- Delete all voice transcripts (Settings → Privacy)
- Disable Hà voice from ever speaking (text-only)
- Disable wake word

### 10.3 Compliance
- Always show recording indicator
- No voice biometrics
- Child voice detection → soft prompt

---

## PART B — LIVE COOKING MODE

## 11. Concept

User chọn recipe → enter **Live Cooking** → Hà hướng dẫn từng bước, hands-free, voice-driven, with timers.

**Why it matters:**
- Retention: avg session 18 minutes (cao gấp 4× home feed)
- Premium driver: 60% Live Cooking users upgrade
- Content moat: turns recipes from text → experience
- Social: optional "Couple cooks together" + Apple Watch companion

---

## 12. Feature Set

### 12.1 Step-by-step coach
- Each step displayed full-screen
- Auto-advance with voice commands
- Multi-timer support (parallel)
- Voice commands: tiếp, lặp lại, dừng, quay lại, đo lại

### 12.2 Hands-free voice control
- Wake word always-on during cooking
- "Hey Hà, tiếp" / "Hà, đặt timer mười phút"
- Voice-only navigation (no screen tap needed)

### 12.3 Multi-timer
- Up to 4 timers simultaneously
- Named ("Luộc trứng", "Hầm xương")
- Audio + haptic alerts when done
- Visual ring around recipe card

### 12.4 Smart pause
- Detects: user holding phone → pause
- Re-engages on "Hà, tiếp"
- Auto-resume after 60s inactive

### 12.5 Couple co-cooking (premium)
- 2 paired accounts in same recipe
- Real-time sync of steps
- Voice chat overlay
- "Em làm xong bước 3 chưa?" auto-relayed

### 12.6 Apple Watch companion
- Watch shows current step + timer
- Tap to advance
- Wrist haptic when timer ends
- Heart rate-aware (if elevated → suggest break)

---

## 13. UI Layout (Live Cooking Screen)

```
┌─────────────────────────────────────────────┐
│                                             │
│   Trứng chiên cà chua  ·  Bước 2 / 4        │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│   [Hero photo bước 2 — large, no clutter]   │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│   Cà chua thái múi cau,                     │
│   xào mềm với hành lá                       │
│                                             │
│   ⏱  Timer 5:00  ──────●────                │
│                                             │
│   Tip: cho 1 thìa nước cuối                 │
│   để trứng mềm hơn ✨                       │
│                                             │
├─────────────────────────────────────────────┤
│                                             │
│   [← Quay lại]   [⏸ Dừng]   [Tiếp →]        │
│                                             │
│   🎤  "Hey Hà, tiếp"                        │
│                                             │
└─────────────────────────────────────────────┘
```

**Always-on:**
- Screen wake lock active
- Volume up to 80% (default during cooking)
- Mic always listening (wake word)
- Display brightness max

---

## 14. State Model

```
LIVE COOKING SESSION
├── status: PREP | COOKING | PAUSED | DONE | ABANDONED
├── current_step: 0..N-1
├── timers: [{ name, total_sec, remaining_sec, status }]
├── voice_history: [{ from, text, ts }]
├── partner_id: nullable    ← couple mode
├── watch_paired: bool
└── analytics:
    - started_at, completed_at
    - voice_commands_count
    - step_durations[]
    - errors_encountered[]
```

---

## 15. Voice Commands (Cooking)

| Command (VN) | Action |
|--------------|--------|
| "Tiếp", "Tiếp theo", "Bước tới" | Advance step |
| "Quay lại", "Lùi" | Previous step |
| "Lặp lại" | Re-read current step |
| "Dừng", "Tạm dừng" | Pause |
| "Tiếp tục" | Resume |
| "Đặt timer X phút" | Create timer |
| "Còn bao lâu" | Read current timer |
| "Hủy timer" | Cancel timer |
| "Bao nhiêu nguyên liệu" | Read ingredient list |
| "Đo lại" | Repeat measurements for current step |
| "Hà ơi giúp" | Trigger free-form Q&A |
| "Xong" | Mark recipe complete |

---

## 16. Backend Workflow

```
[Client] enter live cooking
       ↓ POST /v1/cooking/session
       ↓ { recipe_id, watch_paired }
       
[Server] creates LiveCookingSession in Postgres + Redis
       ↓ returns session_id
       
[Client] connects WS /realtime?channel=cooking:{session_id}
       
[On each voice command]
[Client] WS event: { type: 'cmd', text: 'tiếp' }
       ↓
[Server] update step, broadcast state
       ↓ WS event back: { current_step, timers, ... }
       
[Timer]
[Server] schedule in BullMQ
       ↓ on completion → WS push + push notification
```

---

## 17. Multi-Modal Step Format

Each recipe step can have:

```json
{
  "index": 1,
  "title": "Đập trứng",
  "description": "Đập 4 trứng vào tô, đánh tan, nêm 1 tsp nước mắm",
  "duration_min": 2,
  "ingredients_used": ["trứng x 4", "nước mắm x 1 tsp"],
  "media": {
    "image": "...",
    "short_video": "...",  // optional 5s loop showing technique
    "voice_audio": "..."   // pre-recorded TTS for offline
  },
  "tips": ["Đánh tan nhẹ tay tránh bọt"],
  "timer": null,
  "checkpoint": false,   // is this a "wait for user confirmation" step?
  "voice_prompts": {
    "intro": "Bước 1 — đập trứng",
    "outro": "Xong rồi đó, nói 'tiếp' nhé"
  }
}
```

---

## 18. Couple Co-Cook Sync

Two users cook the same recipe simultaneously:

```
Couple A connects → cooking:abc:userA
Couple B connects → cooking:abc:userB
       ↓
Both share state via group channel cooking:abc:couple
       ↓
Events:
  - A advanced to step 3 → B sees "Mai đã sang bước 3"
  - B's timer ending → A gets haptic + visual ping
  - Voice messages: "Bước 4 dễ ăn không?" → forwarded
       ↓
Optional: voice channel always open (push-to-talk)
```

UI shows partner avatar with current step indicator.

---

## 19. Apple Watch Companion

### 19.1 Capabilities
- Show current step
- Voice command via Siri shortcut
- Timer alerts (wrist tap)
- Quick controls: Tiếp / Pause
- Heart rate monitor (mode "calm cooking" detection)

### 19.2 Implementation
- WatchKit + WatchConnectivity
- Background app refresh
- Live Activity bridge

---

## 20. Analytics & Optimization

Track per cooking session:
- **Completion rate** — % users who finish recipe
- **Step duration vs estimate** — recipe accuracy
- **Voice command success rate**
- **Timer usage**
- **Drop-off step** (which step users abandon)

Use to:
- Refine recipe time estimates
- Improve voice command understanding
- A/B test step ordering

---

## 21. Premium Features

| Feature | Free | Premium |
|---------|------|---------|
| Live Cooking sessions | 3/month | Unlimited |
| Multi-timer | 1 timer | 4 timers |
| Apple Watch | ❌ | ✅ |
| Couple co-cook | ❌ | ✅ |
| Voice continuous (always-on) | 30 min/day | Unlimited |
| Offline mode (pre-cached) | ❌ | ✅ |
| Custom voice | ❌ | ✅ |

---

## 22. Edge Cases

| Case | Behavior |
|------|----------|
| Mic blocked (no permission) | Show "Cần mic" + button to settings |
| User leaves app mid-cook | Live Activity persists, push when timer done |
| Network loss | Cached recipe + offline voice (pre-rendered TTS) |
| Voice misrecognition | Show suggested action chips below for tap |
| Phone overheats | Reduce screen brightness, pause video |
| Long pause (>30 min) | Auto end session, save progress |

---

## 23. Roadmap

- **V1 (Month 4):** Live Cooking solo + voice commands + 1 timer
- **V1.5:** Multi-timer, recipe analytics
- **V2 (Month 7):** Apple Watch, Couple co-cook
- **V3 (Month 12):** Smart home integration (lights dim when "Hà cooking"), oven/induction control via Matter

---

## 24. Cost Estimates (Voice + Cooking)

| Item | Cost / DAU / mo |
|------|-----------------|
| ASR (Whisper self-hosted) | $0.018 |
| LLM intent + reply (mostly mini) | $0.012 |
| TTS (VBee + cache) | $0.008 |
| Audio CDN | $0.002 |
| **Total voice** | **$0.04 / DAU / mo** |

At 5M MAU with 30% voice users → **$60K/mo**.
Premium covers 4× this — comfortable margin.

---
