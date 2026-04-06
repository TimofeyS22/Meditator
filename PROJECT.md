# Aura — Полное описание проекта

## Концепция

Aura — премиальное приложение для ментального восстановления, построенное на концепции **"Живого Космоса"**. Приложение не является типичным трекером медитаций. Это эмоциональный ИИ-компаньон, который чувствует состояние пользователя и мгновенно адаптирует визуальную среду, звук и рекомендации.

Ключевая метафора: пользователь живёт внутри личной вселенной, которая эволюционирует вместе с его эмоциональным состоянием. Чем больше он практикует — тем ярче и глубже становится его космос.

---

## Архитектура

### Стек технологий

| Слой | Технологии |
|------|-----------|
| **Мобильное приложение** | Flutter 3.11+, Dart, Riverpod (state management), GoRouter (навигация) |
| **Бэкенд** | Python, FastAPI, SQLAlchemy (async), asyncpg |
| **База данных** | PostgreSQL 16 |
| **ИИ** | GPT-4o через ProxyAPI.ru, ElevenLabs TTS |
| **Инфраструктура** | Docker Compose (Postgres + API) |

### Структура проекта

```
Meditator/
├── .env                          # API_BASE_URL для Flutter
├── pubspec.yaml                  # Flutter зависимости
├── lib/                          # Flutter-приложение (25 файлов, ~5900 строк)
│   ├── main.dart                 # Точка входа
│   ├── app/
│   │   └── router.dart           # Навигация (GoRouter)
│   ├── core/
│   │   ├── api/
│   │   │   └── api_client.dart   # HTTP-клиент (Dio + JWT)
│   │   ├── audio/
│   │   │   └── audio_service.dart # Аудио-плеер (just_audio)
│   │   ├── aura/
│   │   │   ├── atmosphere.dart   # Визуальные конфиги для 8 состояний вселенной
│   │   │   └── aura_engine.dart  # Движок состояния Aura (Riverpod Notifier)
│   │   ├── auth/
│   │   │   └── auth_service.dart # Сервис авторизации
│   │   └── storage/
│   │       └── local_storage.dart # SharedPreferences кэш
│   ├── features/
│   │   ├── splash/
│   │   │   └── splash_screen.dart    # Сцены 1-3: рождение вселенной
│   │   ├── onboarding/
│   │   │   └── onboarding_flow.dart  # Сцены 4-10: эмоция → авторизация → вход
│   │   ├── home/
│   │   │   └── home_screen.dart      # Главный экран с чекином настроения
│   │   ├── session/
│   │   │   └── session_screen.dart   # Экран медитативной сессии
│   │   ├── reality_break/
│   │   │   └── reality_break_screen.dart # Экстренная помощь "Мне плохо"
│   │   ├── timeline/
│   │   │   └── timeline_screen.dart  # История настроений
│   │   ├── profile/
│   │   │   └── profile_screen.dart   # Профиль и настройки
│   │   └── paywall/
│   │       └── paywall_screen.dart   # Экран подписки
│   └── shared/
│       ├── theme/
│       │   ├── cosmic.dart           # Дизайн-токены (цвета, отступы, анимации)
│       │   └── app_theme.dart        # Material 3 тёмная тема
│       └── widgets/
│           ├── aura_orb.dart         # Центральная сфера-компаньон
│           ├── breath_ring.dart      # Пульсирующее кольцо дыхания
│           ├── cosmic_background.dart # Живой космический фон (параллакс, туманности)
│           ├── cosmic_button.dart    # Светящаяся кнопка с градиентом
│           ├── glass_card.dart       # Стекломорфная карточка
│           ├── particle_field.dart   # Поле частиц с хаотичным режимом
│           └── typewriter_text.dart  # Посимвольный вывод текста
├── backend/
│   ├── docker-compose.yml        # Postgres + API
│   ├── Dockerfile                # Python 3.12 + uvicorn
│   ├── requirements.txt          # Python зависимости
│   └── app/
│       ├── main.py               # FastAPI приложение
│       ├── config.py             # Настройки (pydantic-settings)
│       ├── database.py           # Async SQLAlchemy engine
│       ├── models.py             # ORM модели (User, Session, MoodEntry, Meditation)
│       ├── schemas.py            # Pydantic схемы запросов/ответов
│       ├── auth.py               # JWT + bcrypt
│       ├── routes.py             # Все HTTP-эндпоинты
│       └── companion.py          # ИИ-компаньон (GPT + fallback)
└── ios/                          # iOS-специфичные файлы (Xcode, Podfile)
```

---

## Пользовательский путь

### 1. Splash (Scenes 1-3) — ~8 секунд

Пользователь входит в приложение. Экран полностью чёрный на 800мс (сброс визуального шума). Затем в центре появляется единственная точка фиолетового света (#A78BFA), которая медленно растёт от 6px до 24px. Свет начинает "дышать" — пульсация масштаба 1.0↔1.08 каждые 2.4 секунды. Далее проявляется радиальный градиент космоса (#1E1B4B → #020617), и из центра расширяются 35 частиц в трёх параллаксных слоях (0.5x, 1.0x, 1.5x скорости). Каждая частица появляется с задержкой (stagger). Используются только кривые easeOutCubic, easeInOutSine и cubic-bezier(0.4, 0, 0.2, 1).

### 2. Emotional Entry (Scenes 4-5)

Текст "Что ты сейчас чувствуешь?" появляется с анимацией opacity 0→1 + translateY +12→0 за 500мс. Ниже — 5 состояний со staggered-появлением:

| Состояние | Реакция космоса |
|-----------|----------------|
| **Спокойствие** | Частицы замедляются на 40%, свечение увеличивается, тон → мягкий синий (#60A5FA) |
| **Тревога** | Частицы ускоряются на 30%, появляется дрожание 0.75px, яркость снижается |
| **Усталость** | Движение замедляется на 60%, затуманивание, приглушение |
| **Перегрузка** | Плотность частиц ×1.8, хаотичное движение, лёгкий zoom-in |
| **Пустота** | Частицы почти исчезают (×0.2), статичный фон, минимум света |

Переход космоса: 700мс, easeOutCubic. Все параметры (скорость, плотность, хаотичность, свечение, оттенок) интерполируются плавно.

### 3. AI Response (Scene 6)

Появляется орб ИИ-компаньона — 16px белый круг с фиолетовым свечением (blur 40px). Орб плавает по синусоиде (амплитуда 6px, период 4с). Отображается короткая фраза: "Давай замедлимся.", "Отдохни.", "Я здесь." — в зависимости от выбранной эмоции.

### 4. Авторизация (Scenes 7-8)

Экран предлагает три способа входа:
- Apple (заглушка)
- Google (заглушка)
- Email (рабочий)

Кнопки: стекломорфные (glassmorphism), высота 48px, border-radius 24px, фон rgba(255,255,255,0.08), blur 20px. Staggered-появление.

При выборе Email — форма с сегментным переключателем [Регистрация | Вход]:
- Поля: высота 52px, border-radius 20px, фон rgba(255,255,255,0.06)
- Фокус: свечение цвета выбранной эмоции (#A78BFA@0.4), масштаб 1.01
- Набор текста: частицы космоса чуть ускоряются (+5%)
- Ошибки: без красного цвета, только opacity-shift и подсказка

Регистрация/вход отправляет запрос на `/api/auth/register` или `/api/auth/login`. Токены сохраняются в Keychain (flutter_secure_storage).

### 5. Universe Deepening (Scene 9)

После успешной авторизации — эффект "углубления" вселенной:
- Camera zoom 1.0 → 1.1 за 1200мс
- Больше частиц, больше света
- Виньетка ослабевает

### 6. Final State (Scene 10)

Орб компаньона в центре, текст "Я здесь" (fade-in 500мс, scale 0.95→1). Через 3.5 секунды — плавный переход на главный экран.

### 7. Главный экран (Home)

Живой космический фон адаптируется к текущему состоянию пользователя. По центру вопрос "Как ты сейчас?" с 5 эмоциональными чипами. После чекина:
- Появляется AuraOrb (анимированная сфера с дыханием и shimmer-эффектом)
- Текст присутствия ИИ (если не silent-режим)
- Кнопка действия ("Сбросить за 1 мин", "Перезагрузка", "Углубиться" и т.д.)
- Внизу — кнопка "Мне плохо" для экстренной помощи

Контент скроллится при нехватке места. Кнопка "Мне плохо" закреплена внизу.

### 8. Сессия (Session)

Таймер с аудио-сопровождением. Тип сессии определяется эмоциональным состоянием:
- anxiety_relief (60 сек)
- energy_reset (90 сек)
- overload_relief (60 сек)
- grounding (90 сек)
- deepen (90 сек)
- sleep_reset (90 сек)

После завершения — "послесвечение" (afterglow), данные отправляются в API.

### 9. Reality Break ("Мне плохо")

Экстренная помощь: фазовые успокаивающие фразы, кольцо дыхания, аудио. Переводит пользователя из состояния паники в относительное спокойствие за 1-2 минуты.

### 10. Профиль

Статистика (сессии, стрик, чекины), прогресс вселенной, кнопка синхронизации (ведёт в авторизацию если не залогинен), настройки, подписка.

### 11. Timeline

Хронология всех эмоциональных чекинов из локального хранилища.

---

## Бэкенд — API

### Docker-сервисы

| Сервис | Порт (хост) | Назначение |
|--------|-------------|-----------|
| **db** | 5433 | PostgreSQL 16-alpine |
| **api** | 8002 | FastAPI (uvicorn, 2 workers) |

### Эндпоинты

| Метод | Путь | Аутентификация | Описание |
|-------|------|----------------|----------|
| GET | `/health` | — | Проверка здоровья |
| POST | `/api/auth/register` | — | Регистрация → JWT-пара |
| POST | `/api/auth/login` | — | Вход → JWT-пара |
| POST | `/api/auth/refresh` | — | Обновление токена |
| GET | `/api/profile` | Bearer JWT | Получить профиль |
| PUT | `/api/profile` | Bearer JWT | Обновить профиль |
| POST | `/api/sessions` | Bearer JWT | Создать сессию |
| GET | `/api/sessions/stats` | Bearer JWT | Статистика пользователя |
| POST | `/api/mood` | Bearer JWT | Создать запись настроения |
| GET | `/api/mood/history` | Bearer JWT | История настроений |
| POST | `/api/companion` | Bearer JWT | Запрос к ИИ-компаньону |
| GET | `/api/meditations` | — | Каталог медитаций |
| POST | `/api/meditations/generate` | Bearer JWT | Генерация медитации (GPT) |
| POST | `/api/tts` | Bearer JWT | Озвучка текста (ElevenLabs) |

### Модели данных (PostgreSQL)

**User** — email, password_hash, display_name, is_premium, premium_expires_at, total_sessions, current_streak, longest_streak, total_minutes, last_session_date, preferred_duration, notification_enabled, notification_hour, companion_tone, dominant_emotion, emotional_trend, calm_ratio, effective_session_types, created_at, updated_at.

**Session** — user_id (FK), session_type, duration_seconds, completed, mood_before, mood_after, audio_track, created_at.

**MoodEntry** — user_id (FK), emotion (anxiety|fatigue|overload|emptiness|calm), intensity (1-5), note, context (checkin|reality_break|post_session), ai_insight, created_at.

**Meditation** — id, title, description, category, session_type, duration_seconds, audio_file, is_premium, play_count, created_at.

### ИИ-компаньон (CompanionEngine)

Двухуровневая система:
1. **GPT-4o** через ProxyAPI.ru — анализирует полный контекст пользователя (текущая эмоция, время суток, стрик, тренд, доминирующая эмоция, утренние/вечерние паттерны, эффективные типы сессий) и возвращает персонализированный ответ.
2. **Fallback** — правила на основе эмоции + времени суток, если GPT недоступен.

4 режима ответа:
- **minimal_verbal** — мягкая фраза ("Давай замедлимся.")
- **action_suggestion** — конкретное действие ("Попробуем перезагрузку за 1 минуту?")
- **silent** — молчание, только визуальные изменения вселенной
- **reflective** — наблюдение паттерна ("Каждый вечер тревога приходит. Замечаешь?")

8 визуальных состояний вселенной: calm, anxiety, fatigue, overload, emptiness, focus, joy, sleepy — каждое с уникальными цветами, скоростью частиц, интенсивностью, виньеткой.

---

## Визуальная система

### Цветовая палитра

| Токен | Цвет | Использование |
|-------|------|--------------|
| `Cosmic.bg` | #020108 | Основной фон |
| `Cosmic.surface` | #0A0A1A | Карточки |
| `Cosmic.primary` | #8B7FFF | Основной акцент (фиолетовый) |
| `Cosmic.accent` | #5CE1E6 | Вторичный акцент (бирюзовый) |
| `Cosmic.warm` | #FFB156 | Тёплый акцент (янтарь) |
| `Cosmic.rose` | #FF6B8A | Стресс/экстренность |
| `Cosmic.green` | #56E09A | Спокойствие |
| `Cosmic.text` | #F0ECF9 | Основной текст |
| `Cosmic.textMuted` | #8A84A8 | Приглушённый текст |
| `Cosmic.textDim` | #5A5478 | Третичный текст |

### Анимационная система

| Токен | Значение | Использование |
|-------|----------|--------------|
| `Anim.fast` | 200мс | Микро-переходы UI |
| `Anim.normal` | 400мс | Стандартные переходы |
| `Anim.slow` | 800мс | Плавные появления |
| `Anim.breath` | 4000мс | Цикл дыхания |
| `Anim.cosmic` | 20сек | Фоновый цикл космоса |
| `Anim.curve` | cubic(0.16, 1.0, 0.3, 1.0) | Основная кривая |
| `Anim.curveSmooth` | cubic(0.4, 0.0, 0.0, 1.0) | Плавная кривая |

Дополнительно в splash/onboarding используются точные кривые из спецификации:
- `easeOutCubic` — появление элементов
- `easeInOutSine` (cubic 0.37, 0, 0.63, 1) — дыхательные циклы
- `materialEase` (cubic 0.4, 0, 0.2, 1) — стандартные переходы

---

## Зависимости Flutter

| Пакет | Версия | Назначение |
|-------|--------|-----------|
| flutter_riverpod | ^2.6.1 | State management |
| go_router | ^17.1.0 | Навигация |
| dio | ^5.9.2 | HTTP-клиент |
| just_audio | ^0.10.5 | Аудиоплеер |
| audio_session | ^0.2.3 | Конфигурация аудиосессии |
| flutter_secure_storage | ^9.2.4 | Keychain (JWT токены) |
| shared_preferences | ^2.5.4 | Локальный кэш |
| flutter_dotenv | ^6.0.0 | .env переменные |
| connectivity_plus | ^7.0.0 | Проверка соединения |
| url_launcher | ^6.3.2 | Открытие URL |

## Зависимости Backend

| Пакет | Версия | Назначение |
|-------|--------|-----------|
| fastapi | 0.115.0 | Web-фреймворк |
| uvicorn[standard] | 0.30.0 | ASGI-сервер |
| sqlalchemy[asyncio] | 2.0.35 | ORM |
| asyncpg | 0.30.0 | Async PostgreSQL-драйвер |
| pydantic | 2.9.0 | Валидация данных |
| pydantic-settings | 2.5.0 | Настройки из env |
| python-jose[cryptography] | 3.3.0 | JWT |
| passlib[bcrypt] | 1.7.4 | Хеширование паролей |
| bcrypt | 4.1.3 | Bcrypt-бэкенд |
| httpx | 0.27.0 | HTTP-клиент (для GPT/TTS) |
| alembic | 1.13.0 | Миграции (в requirements, не подключен) |
| email-validator | 2.1.0 | Валидация email |

---

## Навигация (GoRouter)

| Путь | Экран | Переход |
|------|-------|---------|
| `/splash` | SplashScreen | slowFade 1200мс |
| `/onboarding` | OnboardingFlow | slowFade 1200мс |
| `/home` | HomeScreen | fade 600мс |
| `/session?type=X&duration=Y` | SessionScreen | scaleUp 500мс |
| `/reality-break` | RealityBreakScreen | instantDim 200мс |
| `/timeline` | TimelineScreen | slideUp 400мс |
| `/profile` | ProfileScreen | slideUp 400мс |
| `/paywall` | PaywallScreen | slideUp 400мс |

Начальный маршрут: `/splash`.

---

## Оффлайн-режим

Приложение полностью работает без сети:
- Чекин настроения сохраняется локально (SharedPreferences)
- AuraEngine вычисляет атмосферу по правилам (без GPT)
- Аудио из бандла
- Статистика кэшируется локально
- При появлении сети — синхронизация с API

---

## Запуск

### Бэкенд
```bash
cd backend
docker compose up -d
# API: http://localhost:8002
# Health: http://localhost:8002/health
```

### Flutter
```bash
# .env должен содержать: API_BASE_URL=http://localhost:8002
flutter run
```

### Переменные окружения (backend)
| Переменная | Значение по умолчанию | Описание |
|-----------|----------------------|----------|
| DATABASE_URL | postgresql+asyncpg://meditator:meditator_secret@db:5432/meditator | БД |
| JWT_SECRET | change-me-in-production | Секрет JWT |
| OPENAI_API_KEY | — | Ключ OpenAI (для медитаций) |
| AI_BASE_URL | https://api.proxyapi.ru/openai/v1 | Прокси для GPT |
| AI_API_KEY | — | Ключ ProxyAPI |
| ELEVENLABS_API_KEY | — | Ключ ElevenLabs (TTS) |
| CORS_ORIGINS | * | Разрешённые источники |
