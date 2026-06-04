# Sourcing Bot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Telegram-бот, который ищет поставщиков на Alibaba и 1688.com, анализирует их через Claude API и помогает пользователю найти лучшие варианты.

**Architecture:** Async Python-бот (python-telegram-bot v20) с двумя Playwright scrapers, Claude API для анализа, SQLite для хранения данных и APScheduler для еженедельного мониторинга цен.

**Tech Stack:** Python 3.11+, python-telegram-bot 20, playwright, beautifulsoup4, deep-translator, anthropic, sqlalchemy, apscheduler, pytest, pytest-asyncio

---

## File Structure

```
sourcing-bot/
├── bot/
│   ├── __init__.py
│   ├── database.py          # SQLAlchemy models + DB class
│   ├── analyzer.py          # Claude API: анализ, флаги, шаблоны
│   ├── calculator.py        # Landed cost калькулятор
│   ├── scheduler.py         # APScheduler мониторинг цен
│   ├── scrapers/
│   │   ├── __init__.py
│   │   ├── base.py          # SupplierRaw dataclass
│   │   ├── alibaba.py       # Playwright + parse
│   │   └── c1688.py         # Playwright + deep-translator + parse
│   └── handlers/
│       ├── __init__.py
│       ├── search.py        # /start, /categories, /search
│       ├── favorites.py     # /favorites, статусы
│       ├── history.py       # /history
│       └── admin.py         # /add_category
├── tests/
│   ├── fixtures/
│   │   ├── alibaba_results.html   # sample Alibaba search page
│   │   └── c1688_results.html     # sample 1688 search page
│   ├── test_database.py
│   ├── test_analyzer.py
│   ├── test_calculator.py
│   └── test_scrapers.py
├── .env.example
├── requirements.txt
└── main.py
```

---

## Task 1: Project Setup

**Files:**
- Create: `sourcing-bot/requirements.txt`
- Create: `sourcing-bot/.env.example`
- Create: `sourcing-bot/main.py` (skeleton)
- Create: `sourcing-bot/bot/__init__.py`
- Create: `sourcing-bot/bot/scrapers/__init__.py`
- Create: `sourcing-bot/bot/handlers/__init__.py`

- [ ] **Step 1: Create project directory and all __init__.py files**

```bash
mkdir -p sourcing-bot/bot/scrapers sourcing-bot/bot/handlers sourcing-bot/tests/fixtures
touch sourcing-bot/bot/__init__.py sourcing-bot/bot/scrapers/__init__.py sourcing-bot/bot/handlers/__init__.py
```

- [ ] **Step 2: Write requirements.txt**

```
# sourcing-bot/requirements.txt
python-telegram-bot==20.7
playwright==1.41.0
beautifulsoup4==4.12.3
deep-translator==1.11.4
anthropic==0.23.1
sqlalchemy==2.0.27
apscheduler==3.10.4
pytest==8.0.0
pytest-asyncio==0.23.4
```

- [ ] **Step 3: Write .env.example**

```
# sourcing-bot/.env.example
TELEGRAM_TOKEN=your_telegram_bot_token_here
ANTHROPIC_API_KEY=your_anthropic_api_key_here
DB_PATH=sourcing.db
```

- [ ] **Step 4: Write main.py skeleton**

```python
# sourcing-bot/main.py
import asyncio
import os
from dotenv import load_dotenv
from telegram.ext import ApplicationBuilder
from bot.database import Database
from bot.handlers.search import register_search_handlers
from bot.handlers.favorites import register_favorites_handlers
from bot.handlers.history import register_history_handlers
from bot.handlers.admin import register_admin_handlers
from bot.scheduler import start_scheduler

load_dotenv()


async def main():
    db = Database(os.getenv("DB_PATH", "sourcing.db"))
    db.init()

    app = ApplicationBuilder().token(os.getenv("TELEGRAM_TOKEN")).build()
    app.bot_data["db"] = db

    register_search_handlers(app)
    register_favorites_handlers(app)
    register_history_handlers(app)
    register_admin_handlers(app)

    start_scheduler(app, db)

    print("Bot started...")
    await app.run_polling()


if __name__ == "__main__":
    asyncio.run(main())
```

- [ ] **Step 5: Install dependencies**

```bash
cd sourcing-bot
pip install -r requirements.txt
python -m playwright install chromium
```

Expected: все пакеты устанавливаются без ошибок.

- [ ] **Step 6: Commit**

```bash
cd sourcing-bot
git init
git add .
git commit -m "feat: project scaffold"
```

---

## Task 2: Database Models

**Files:**
- Create: `sourcing-bot/bot/database.py`
- Create: `sourcing-bot/tests/test_database.py`

- [ ] **Step 1: Write failing tests**

```python
# sourcing-bot/tests/test_database.py
import pytest
from bot.database import Database, Supplier, Search, Favorite


@pytest.fixture
def db():
    database = Database(":memory:")
    database.init()
    return database


def test_save_and_get_supplier(db):
    s = Supplier(
        platform="alibaba", name="Test Co.", price_min=10.0, price_max=20.0,
        moq=50, rating=4.5, reviews=120, years_on_platform=5,
        delivery_days="14-21", certifications=["CE"], contacts={"email": "t@t.com"},
        url="https://alibaba.com/test", search_query="massage gun",
        red_flags=[], avg_market_price=15.0, score=80.0, summary="Good supplier.",
    )
    saved = db.save_supplier(s)
    assert saved.id is not None
    fetched = db.get_supplier(saved.id)
    assert fetched.name == "Test Co."
    assert fetched.platform == "alibaba"


def test_save_and_get_search(db):
    search = db.save_search(
        user_id=123, query="massage gun",
        category="Массажное оборудование", subcategory="Пистолет-массажер",
        results=[{"id": 1}],
    )
    assert search.id is not None
    history = db.get_user_history(user_id=123)
    assert len(history) == 1
    assert history[0].query == "massage gun"


def test_history_limit(db):
    for i in range(25):
        db.save_search(user_id=1, query=f"q{i}", category="A", subcategory="A1", results=[])
    history = db.get_user_history(user_id=1, limit=20)
    assert len(history) == 20


def test_favorite_status_flow(db):
    s = Supplier(
        platform="alibaba", name="Fav Co.", price_min=5.0, price_max=10.0,
        moq=100, rating=4.8, reviews=200, years_on_platform=7,
        delivery_days="7-14", certifications=[], contacts={},
        url="https://alibaba.com/fav", search_query="filter",
        red_flags=[], avg_market_price=7.5, score=90.0, summary="Top pick.",
    )
    saved = db.save_supplier(s)
    fav = db.add_favorite(user_id=123, supplier_id=saved.id)
    assert fav.status == "Найден"
    updated = db.update_favorite_status(fav_id=fav.id, user_id=123, status="Контактирую")
    assert updated.status == "Контактирую"


def test_get_default_categories(db):
    cats = db.get_categories()
    assert "Массажное оборудование" in cats
    assert "Пистолет-массажер" in cats["Массажное оборудование"]
    assert "Фильтры воды" in cats
    assert "Фильтры воздуха" in cats


def test_add_custom_category(db):
    db.add_category("Тренажёры", ["Беговая дорожка", "Велотренажёр"])
    cats = db.get_categories()
    assert "Тренажёры" in cats
    assert "Беговая дорожка" in cats["Тренажёры"]


def test_get_favorites_by_status(db):
    s = Supplier(
        platform="alibaba", name="S1", price_min=1.0, price_max=2.0, moq=10,
        rating=4.0, reviews=50, years_on_platform=3, delivery_days="21",
        certifications=[], contacts={}, url="https://a.com", search_query="q",
        red_flags=[], avg_market_price=1.5, score=70.0, summary="ok",
    )
    saved = db.save_supplier(s)
    fav = db.add_favorite(user_id=1, supplier_id=saved.id)
    db.update_favorite_status(fav.id, user_id=1, status="Заказал")
    
    ordered = db.get_user_favorites(user_id=1, status="Заказал")
    assert len(ordered) == 1
    none_found = db.get_user_favorites(user_id=1, status="Найден")
    assert len(none_found) == 0
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd sourcing-bot
pytest tests/test_database.py -v
```

Expected: `ModuleNotFoundError: No module named 'bot.database'`

- [ ] **Step 3: Implement database.py**

```python
# sourcing-bot/bot/database.py
from __future__ import annotations
from datetime import datetime
from typing import Optional
from sqlalchemy import (Column, Integer, String, Float, DateTime,
                        Text, ForeignKey, JSON, create_engine)
from sqlalchemy.orm import declarative_base, relationship, sessionmaker

Base = declarative_base()

DEFAULT_CATEGORIES = {
    "Массажное оборудование": [
        "Массажное кресло", "Пистолет-массажер", "Массажный стол",
        "Массажная подушка", "Ручной массажер",
    ],
    "Фильтры воды": [
        "Фильтр обратного осмоса", "Проточный фильтр",
        "Кувшин-фильтр", "Ультрафиолетовый фильтр",
    ],
    "Фильтры воздуха": [
        "HEPA очиститель", "Угольный фильтр", "Ионизатор", "Промышленный фильтр",
    ],
}

VALID_STATUSES = ["Найден", "Контактирую", "Жду ответа", "Заказал", "Отказал"]


class Supplier(Base):
    __tablename__ = "suppliers"
    id = Column(Integer, primary_key=True)
    platform = Column(String(20))
    name = Column(String(200))
    price_min = Column(Float)
    price_max = Column(Float)
    moq = Column(Integer)
    rating = Column(Float)
    reviews = Column(Integer)
    years_on_platform = Column(Integer)
    delivery_days = Column(String(50))
    certifications = Column(JSON)
    contacts = Column(JSON)
    url = Column(String(500))
    search_query = Column(String(200))
    scraped_at = Column(DateTime, default=datetime.utcnow)
    red_flags = Column(JSON)
    avg_market_price = Column(Float)
    score = Column(Float)
    summary = Column(Text)


class Search(Base):
    __tablename__ = "searches"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer)
    query = Column(String(200))
    category = Column(String(100))
    subcategory = Column(String(100))
    results_json = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)


class Favorite(Base):
    __tablename__ = "favorites"
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer)
    supplier_id = Column(Integer, ForeignKey("suppliers.id"))
    status = Column(String(50), default="Найден")
    notes = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)
    supplier = relationship("Supplier")


class CategoryModel(Base):
    __tablename__ = "categories"
    id = Column(Integer, primary_key=True)
    name = Column(String(100), unique=True)
    subcategories = Column(JSON)


class Database:
    def __init__(self, db_path: str = "sourcing.db"):
        self.engine = create_engine(f"sqlite:///{db_path}")
        # expire_on_commit=False — objects remain usable after session closes
        self.SessionLocal = sessionmaker(bind=self.engine, expire_on_commit=False)

    def init(self):
        Base.metadata.create_all(self.engine)
        self._seed_categories()

    def _seed_categories(self):
        # expire_on_commit=False keeps objects usable after session closes
        with self.SessionLocal() as s:
            for name, subs in DEFAULT_CATEGORIES.items():
                if not s.query(CategoryModel).filter_by(name=name).first():
                    s.add(CategoryModel(name=name, subcategories=subs))
            s.commit()

    def save_supplier(self, supplier: Supplier) -> Supplier:
        with self.SessionLocal() as s:
            s.add(supplier)
            s.commit()
            s.refresh(supplier)
            return supplier

    def get_supplier(self, supplier_id: int) -> Optional[Supplier]:
        with self.SessionLocal() as s:
            return s.get(Supplier, supplier_id)

    def save_search(self, user_id: int, query: str, category: str,
                    subcategory: str, results: list) -> Search:
        with self.SessionLocal() as s:
            search = Search(user_id=user_id, query=query, category=category,
                            subcategory=subcategory, results_json=results)
            s.add(search)
            s.commit()
            s.refresh(search)
            return search

    def get_user_history(self, user_id: int, limit: int = 20) -> list[Search]:
        with self.SessionLocal() as s:
            return (s.query(Search).filter_by(user_id=user_id)
                    .order_by(Search.created_at.desc()).limit(limit).all())

    def add_favorite(self, user_id: int, supplier_id: int) -> Favorite:
        with self.SessionLocal() as s:
            fav = Favorite(user_id=user_id, supplier_id=supplier_id)
            s.add(fav)
            s.commit()
            s.refresh(fav)
            return fav

    def update_favorite_status(self, fav_id: int, user_id: int, status: str) -> Optional[Favorite]:
        with self.SessionLocal() as s:
            fav = s.query(Favorite).filter_by(id=fav_id, user_id=user_id).first()
            if fav and status in VALID_STATUSES:
                fav.status = status
                fav.updated_at = datetime.utcnow()
                s.commit()
                s.refresh(fav)
            return fav

    def get_user_favorites(self, user_id: int, status: Optional[str] = None) -> list[Favorite]:
        from sqlalchemy.orm import joinedload
        with self.SessionLocal() as s:
            q = (s.query(Favorite).filter_by(user_id=user_id)
                 .options(joinedload(Favorite.supplier)))
            if status:
                q = q.filter_by(status=status)
            return q.order_by(Favorite.updated_at.desc()).all()

    def get_categories(self) -> dict[str, list[str]]:
        with self.SessionLocal() as s:
            return {c.name: c.subcategories for c in s.query(CategoryModel).all()}

    def add_category(self, name: str, subcategories: list[str]):
        with self.SessionLocal() as s:
            existing = s.query(CategoryModel).filter_by(name=name).first()
            if existing:
                existing.subcategories = subcategories
            else:
                s.add(CategoryModel(name=name, subcategories=subcategories))
            s.commit()

    def get_all_favorites_for_monitoring(self) -> list[Favorite]:
        from sqlalchemy.orm import joinedload
        with self.SessionLocal() as s:
            return (s.query(Favorite)
                    .filter(Favorite.status.in_(["Найден", "Контактирую", "Жду ответа"]))
                    .options(joinedload(Favorite.supplier))
                    .all())
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd sourcing-bot
pytest tests/test_database.py -v
```

Expected: `7 passed`

- [ ] **Step 5: Commit**

```bash
git add bot/database.py tests/test_database.py
git commit -m "feat: database models and operations"
```

---

## Task 3: Scraper Base + Alibaba Scraper

**Files:**
- Create: `sourcing-bot/bot/scrapers/base.py`
- Create: `sourcing-bot/bot/scrapers/alibaba.py`
- Create: `sourcing-bot/tests/fixtures/alibaba_results.html`
- Create: `sourcing-bot/tests/test_scrapers.py` (Alibaba part)

- [ ] **Step 1: Create SupplierRaw dataclass**

```python
# sourcing-bot/bot/scrapers/base.py
from dataclasses import dataclass, field


@dataclass
class SupplierRaw:
    platform: str
    name: str
    price_min: float
    price_max: float
    moq: int
    rating: float
    reviews: int
    years_on_platform: int
    delivery_days: str
    certifications: list[str]
    contacts: dict
    url: str
    search_query: str
```

- [ ] **Step 2: Create Alibaba fixture HTML**

```html
<!-- sourcing-bot/tests/fixtures/alibaba_results.html -->
<!DOCTYPE html>
<html>
<body>
<div class="organic-list-offer-outter">
  <a href="https://shenzhen-massage.en.alibaba.com" class="company-name">Shenzhen MassagePro Co.</a>
  <span class="price">US $12.00-18.00</span>
  <span class="moq">50 pieces</span>
  <span class="score">4.8</span>
  <span class="year-label">8 YRS</span>
  <span class="review-count">234 reviews</span>
</div>
<div class="organic-list-offer-outter">
  <a href="https://guangzhou-health.en.alibaba.com" class="company-name">Guangzhou Health Equipment Ltd</a>
  <span class="price">US $9.50-14.00</span>
  <span class="moq">100 pieces</span>
  <span class="score">4.5</span>
  <span class="year-label">3 YRS</span>
  <span class="review-count">45 reviews</span>
</div>
</body>
</html>
```

- [ ] **Step 3: Write failing tests for Alibaba parser**

```python
# sourcing-bot/tests/test_scrapers.py
import os
import pytest
from bot.scrapers.alibaba import parse_alibaba_html
from bot.scrapers.c1688 import parse_1688_html

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def load_fixture(name: str) -> str:
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as f:
        return f.read()


def test_parse_alibaba_returns_suppliers():
    html = load_fixture("alibaba_results.html")
    results = parse_alibaba_html(html, query="massage gun", n=15)
    assert len(results) == 2
    assert results[0].platform == "alibaba"
    assert results[0].name == "Shenzhen MassagePro Co."


def test_parse_alibaba_price():
    html = load_fixture("alibaba_results.html")
    results = parse_alibaba_html(html, query="massage gun", n=15)
    assert results[0].price_min == 12.0
    assert results[0].price_max == 18.0


def test_parse_alibaba_moq():
    html = load_fixture("alibaba_results.html")
    results = parse_alibaba_html(html, query="massage gun", n=15)
    assert results[0].moq == 50


def test_parse_alibaba_rating():
    html = load_fixture("alibaba_results.html")
    results = parse_alibaba_html(html, query="massage gun", n=15)
    assert results[0].rating == 4.8


def test_parse_alibaba_years():
    html = load_fixture("alibaba_results.html")
    results = parse_alibaba_html(html, query="massage gun", n=15)
    assert results[0].years_on_platform == 8


def test_parse_alibaba_limit():
    html = load_fixture("alibaba_results.html")
    results = parse_alibaba_html(html, query="massage gun", n=1)
    assert len(results) == 1


def test_parse_alibaba_empty_html():
    results = parse_alibaba_html("<html><body></body></html>", query="x", n=15)
    assert results == []
```

- [ ] **Step 4: Run tests to verify they fail**

```bash
pytest tests/test_scrapers.py::test_parse_alibaba_returns_suppliers -v
```

Expected: `ModuleNotFoundError: No module named 'bot.scrapers.alibaba'`

- [ ] **Step 5: Implement alibaba.py**

```python
# sourcing-bot/bot/scrapers/alibaba.py
from __future__ import annotations
import asyncio
import re
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright
from bot.scrapers.base import SupplierRaw

_SEARCH_URL = "https://www.alibaba.com/trade/search?SearchText={query}&tab=supplier"
_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


async def scrape_alibaba(query: str, n: int = 15) -> list[SupplierRaw]:
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(user_agent=_USER_AGENT)
        page = await context.new_page()
        try:
            await page.goto(_SEARCH_URL.format(query=query), timeout=30000)
            await page.wait_for_load_state("networkidle", timeout=20000)
            await asyncio.sleep(2)
            html = await page.content()
            return parse_alibaba_html(html, query, n)
        finally:
            await browser.close()


def parse_alibaba_html(html: str, query: str, n: int = 15) -> list[SupplierRaw]:
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select(
        ".organic-list-offer-outter, .list-no-v2-outter, "
        "[class*='offer-list-row'], [class*='J-offer-wrapper']"
    )
    results = []
    for card in cards[:n]:
        try:
            name = _text(card, ".company-name, [class*='company-name']") or "Unknown"
            price_text = _text(card, ".price, [class*='price']") or "0"
            price_min, price_max = _parse_price(price_text)
            moq = _parse_moq(_text(card, ".moq, [class*='moq']") or "1")
            rating = _parse_float(_text(card, ".score, [class*='score'], .rating") or "0")
            years = _parse_years(_text(card, "[class*='year']") or "0")
            reviews = _parse_int(_text(card, "[class*='review']") or "0")
            url_el = card.select_one("a[href*='alibaba.com']")
            url = url_el.get("href", "") if url_el else ""
            results.append(SupplierRaw(
                platform="alibaba",
                name=name,
                price_min=price_min,
                price_max=price_max,
                moq=moq,
                rating=min(rating, 5.0),
                reviews=reviews,
                years_on_platform=years,
                delivery_days="14-30",
                certifications=[],
                contacts={},
                url=url,
                search_query=query,
            ))
        except Exception:
            continue
    return results


def _text(tag, selector: str) -> str | None:
    el = tag.select_one(selector)
    return el.get_text(strip=True) if el else None


def _parse_price(text: str) -> tuple[float, float]:
    nums = re.findall(r"[\d.]+", text.replace(",", ""))
    if len(nums) >= 2:
        return float(nums[0]), float(nums[1])
    elif nums:
        v = float(nums[0])
        return v, v
    return 0.0, 0.0


def _parse_moq(text: str) -> int:
    nums = re.findall(r"\d+", text.replace(",", ""))
    return int(nums[0]) if nums else 1


def _parse_float(text: str) -> float:
    nums = re.findall(r"[\d.]+", text)
    return float(nums[0]) if nums else 0.0


def _parse_int(text: str) -> int:
    nums = re.findall(r"\d+", text.replace(",", ""))
    return int(nums[0]) if nums else 0


def _parse_years(text: str) -> int:
    nums = re.findall(r"\d+", text)
    return int(nums[0]) if nums else 0
```

- [ ] **Step 6: Run Alibaba tests**

```bash
pytest tests/test_scrapers.py -k "alibaba" -v
```

Expected: `7 passed`

- [ ] **Step 7: Commit**

```bash
git add bot/scrapers/base.py bot/scrapers/alibaba.py tests/test_scrapers.py tests/fixtures/alibaba_results.html
git commit -m "feat: Alibaba scraper with parser"
```

---

## Task 4: 1688 Scraper

**Files:**
- Create: `sourcing-bot/bot/scrapers/c1688.py`
- Create: `sourcing-bot/tests/fixtures/c1688_results.html`

- [ ] **Step 1: Create 1688 fixture HTML**

```html
<!-- sourcing-bot/tests/fixtures/c1688_results.html -->
<!DOCTYPE html>
<html>
<body>
<div class="offer-list-row">
  <a href="https://detail.1688.com/offer/123.html" class="title">按摩枪深层肌肉放松器</a>
  <span class="price">¥68.00</span>
  <span class="quantity">最小采购量: 10件</span>
  <span class="company-name">深圳市健康科技有限公司</span>
  <span class="year">3年</span>
</div>
<div class="offer-list-row">
  <a href="https://detail.1688.com/offer/456.html" class="title">专业电动按摩枪健身器材</a>
  <span class="price">¥45.00-55.00</span>
  <span class="quantity">最小采购量: 20件</span>
  <span class="company-name">广州医疗设备厂</span>
  <span class="year">5年</span>
</div>
</body>
</html>
```

- [ ] **Step 2: Write failing tests for 1688 parser**

Add to `sourcing-bot/tests/test_scrapers.py`:

```python
def test_parse_1688_returns_suppliers():
    html = load_fixture("c1688_results.html")
    results = parse_1688_html(html, query="按摩枪", n=15)
    assert len(results) == 2
    assert results[0].platform == "1688"


def test_parse_1688_name_is_translated():
    html = load_fixture("c1688_results.html")
    results = parse_1688_html(html, query="massage gun", n=15)
    # name should be translated from Chinese to English (not empty)
    assert results[0].name != ""
    assert results[0].name != "按摩枪深层肌肉放松器"


def test_parse_1688_price():
    html = load_fixture("c1688_results.html")
    results = parse_1688_html(html, query="massage gun", n=15)
    # ¥68 at ~0.14 USD/CNY ≈ $9.52
    assert results[0].price_min > 0


def test_parse_1688_moq():
    html = load_fixture("c1688_results.html")
    results = parse_1688_html(html, query="massage gun", n=15)
    assert results[0].moq == 10
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
pytest tests/test_scrapers.py -k "1688" -v
```

Expected: `ModuleNotFoundError: No module named 'bot.scrapers.c1688'`

- [ ] **Step 4: Implement c1688.py**

```python
# sourcing-bot/bot/scrapers/c1688.py
from __future__ import annotations
import asyncio
import re
from urllib.parse import quote
from bs4 import BeautifulSoup
from playwright.async_api import async_playwright
from deep_translator import GoogleTranslator
from bot.scrapers.base import SupplierRaw

_SEARCH_URL = "https://s.1688.com/selloffer/offer_search.htm?keywords={query}"
_CNY_TO_USD = 0.138  # approximate, update periodically
_USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
_translator = GoogleTranslator(source="zh-CN", target="en")


async def scrape_1688(query: str, n: int = 15) -> list[SupplierRaw]:
    encoded = quote(query)
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(user_agent=_USER_AGENT)
        page = await context.new_page()
        try:
            await page.goto(_SEARCH_URL.format(query=encoded), timeout=30000)
            await page.wait_for_load_state("networkidle", timeout=20000)
            await asyncio.sleep(2)
            html = await page.content()
            return parse_1688_html(html, query, n)
        finally:
            await browser.close()


def parse_1688_html(html: str, query: str, n: int = 15) -> list[SupplierRaw]:
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select(".offer-list-row, [class*='offer-list'], [class*='sm-offer']")
    results = []
    for card in cards[:n]:
        try:
            title_el = card.select_one(".title, a[href*='detail.1688.com']")
            price_el = card.select_one(".price, [class*='price']")
            qty_el = card.select_one(".quantity, [class*='quantity'], [class*='min']")
            company_el = card.select_one(".company-name, [class*='company']")
            year_el = card.select_one(".year, [class*='year']")
            url_el = card.select_one("a[href*='detail.1688.com'], a[href*='1688.com']")

            raw_name = title_el.get_text(strip=True) if title_el else ""
            name = _translate(raw_name) if raw_name else "Unknown"

            raw_company = company_el.get_text(strip=True) if company_el else ""
            company = _translate(raw_company) if raw_company else "Unknown"

            price_text = price_el.get_text(strip=True) if price_el else "0"
            price_min_cny, price_max_cny = _parse_price(price_text)
            price_min = round(price_min_cny * _CNY_TO_USD, 2)
            price_max = round(price_max_cny * _CNY_TO_USD, 2)

            moq = _parse_moq(qty_el.get_text(strip=True) if qty_el else "1")
            years = _parse_years(year_el.get_text(strip=True) if year_el else "0")
            url = url_el.get("href", "") if url_el else ""

            results.append(SupplierRaw(
                platform="1688",
                name=f"{name} — {company}",
                price_min=price_min,
                price_max=price_max,
                moq=moq,
                rating=0.0,
                reviews=0,
                years_on_platform=years,
                delivery_days="7-21",
                certifications=[],
                contacts={},
                url=url,
                search_query=query,
            ))
        except Exception:
            continue
    return results


def _translate(text: str) -> str:
    try:
        return _translator.translate(text) or text
    except Exception:
        return text


def _parse_price(text: str) -> tuple[float, float]:
    text = text.replace("¥", "").replace(",", "")
    nums = re.findall(r"[\d.]+", text)
    if len(nums) >= 2:
        return float(nums[0]), float(nums[1])
    elif nums:
        v = float(nums[0])
        return v, v
    return 0.0, 0.0


def _parse_moq(text: str) -> int:
    nums = re.findall(r"\d+", text.replace(",", ""))
    return int(nums[0]) if nums else 1


def _parse_years(text: str) -> int:
    nums = re.findall(r"\d+", text)
    return int(nums[0]) if nums else 0
```

- [ ] **Step 5: Run 1688 tests**

```bash
pytest tests/test_scrapers.py -k "1688" -v
```

Expected: `4 passed`

- [ ] **Step 6: Run all scraper tests**

```bash
pytest tests/test_scrapers.py -v
```

Expected: `11 passed`

- [ ] **Step 7: Commit**

```bash
git add bot/scrapers/c1688.py tests/fixtures/c1688_results.html tests/test_scrapers.py
git commit -m "feat: 1688 scraper with Chinese translation"
```

---

## Task 5: Claude AI Analyzer

**Files:**
- Create: `sourcing-bot/bot/analyzer.py`
- Create: `sourcing-bot/tests/test_analyzer.py`

- [ ] **Step 1: Write failing tests**

```python
# sourcing-bot/tests/test_analyzer.py
import pytest
from unittest.mock import patch, MagicMock
from bot.analyzer import Analyzer
from bot.scrapers.base import SupplierRaw


def make_supplier(name="Test Co", price_min=10.0, price_max=20.0, moq=50,
                  rating=4.5, reviews=100, years=5, platform="alibaba"):
    return SupplierRaw(
        platform=platform, name=name, price_min=price_min, price_max=price_max,
        moq=moq, rating=rating, reviews=reviews, years_on_platform=years,
        delivery_days="14-21", certifications=["CE"], contacts={},
        url="https://alibaba.com/test", search_query="massage gun",
    )


MOCK_ANALYSIS_RESPONSE = """[
  {"index": 0, "score": 85, "price_vs_market": "-15%", "red_flags": [], "summary": "Reliable supplier with strong ratings."},
  {"index": 1, "score": 60, "price_vs_market": "+5%", "red_flags": ["Less than 1 year on platform"], "summary": "New supplier, proceed with caution."}
]"""

MOCK_CONTACTS_RESPONSE = '{"wechat": "supplier_wechat", "email": "info@supplier.com", "whatsapp": "+8613800000000", "phone": null}'

MOCK_TEMPLATE_RESPONSE = "Dear Supplier, I am interested in your massage gun product. Please provide pricing for 200 units. What is the lead time? Best regards."


@patch("bot.analyzer.anthropic.Anthropic")
def test_analyze_returns_ranked_list(mock_anthropic_cls):
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = MagicMock(
        content=[MagicMock(text=MOCK_ANALYSIS_RESPONSE)]
    )
    analyzer = Analyzer(api_key="test-key")
    suppliers = [make_supplier("A"), make_supplier("B", years=0, reviews=2)]
    result = analyzer.analyze(query="massage gun", suppliers=suppliers)
    assert len(result) == 2
    assert result[0]["score"] == 85
    assert result[0]["index"] == 0


@patch("bot.analyzer.anthropic.Anthropic")
def test_analyze_red_flags_present(mock_anthropic_cls):
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = MagicMock(
        content=[MagicMock(text=MOCK_ANALYSIS_RESPONSE)]
    )
    analyzer = Analyzer(api_key="test-key")
    suppliers = [make_supplier(), make_supplier("New", years=0, reviews=2)]
    result = analyzer.analyze(query="massage gun", suppliers=suppliers)
    assert result[1]["red_flags"] != []


@patch("bot.analyzer.anthropic.Anthropic")
def test_extract_contacts(mock_anthropic_cls):
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = MagicMock(
        content=[MagicMock(text=MOCK_CONTACTS_RESPONSE)]
    )
    analyzer = Analyzer(api_key="test-key")
    contacts = analyzer.extract_contacts("supplier page text here")
    assert contacts["wechat"] == "supplier_wechat"
    assert contacts["email"] == "info@supplier.com"


@patch("bot.analyzer.anthropic.Anthropic")
def test_generate_template(mock_anthropic_cls):
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = MagicMock(
        content=[MagicMock(text=MOCK_TEMPLATE_RESPONSE)]
    )
    analyzer = Analyzer(api_key="test-key")
    template = analyzer.generate_template(
        product="massage gun", quantity=200, template_type="price_inquiry"
    )
    assert "massage gun" in template.lower() or len(template) > 20


@patch("bot.analyzer.anthropic.Anthropic")
def test_analyze_handles_invalid_json(mock_anthropic_cls):
    mock_client = MagicMock()
    mock_anthropic_cls.return_value = mock_client
    mock_client.messages.create.return_value = MagicMock(
        content=[MagicMock(text="not valid json")]
    )
    analyzer = Analyzer(api_key="test-key")
    result = analyzer.analyze(query="test", suppliers=[make_supplier()])
    assert result == []
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_analyzer.py -v
```

Expected: `ModuleNotFoundError: No module named 'bot.analyzer'`

- [ ] **Step 3: Implement analyzer.py**

```python
# sourcing-bot/bot/analyzer.py
from __future__ import annotations
import json
import anthropic
from bot.scrapers.base import SupplierRaw

_MODEL = "claude-sonnet-4-6"

_ANALYSIS_PROMPT = """\
You are a B2B sourcing analyst. Analyze these supplier listings and return a JSON ranking.

Product searched: {query}

Suppliers (indexed from 0):
{suppliers_json}

For each supplier return a JSON object with:
- index: supplier index (int)
- score: 0-100 overall score based on rating, years_on_platform, reviews, certifications, price competitiveness, delivery speed
- price_vs_market: percentage vs average market price (e.g. "-15%" or "+5%")
- red_flags: list of strings — flag if: registered < 1 year, < 5 reviews, price > 40% below average, no certifications for regulated products
- summary: 1-2 sentence recommendation in Russian

Return ONLY a valid JSON array, sorted by score descending. No other text."""

_CONTACTS_PROMPT = """\
Extract contact information from this supplier page text.
Return ONLY valid JSON: {{"wechat": "...", "email": "...", "whatsapp": "...", "phone": "..."}}
Use null for fields not found.
Page text:
{page_text}"""

_TEMPLATE_TYPES = {
    "price_inquiry": "requesting pricing for a specific quantity",
    "moq_reduction": "politely asking to reduce the minimum order quantity",
    "sample_request": "requesting to order a sample before bulk purchase",
}

_TEMPLATE_PROMPT = """\
Write a short professional B2B inquiry email in English to a Chinese supplier.
Product: {product}
Quantity: {quantity} units
Purpose: {purpose}
Keep it 3-5 sentences, professional, specific. No fluff. Start with "Dear Supplier,\""""


class Analyzer:
    def __init__(self, api_key: str):
        self.client = anthropic.Anthropic(api_key=api_key)

    def analyze(self, query: str, suppliers: list[SupplierRaw]) -> list[dict]:
        if not suppliers:
            return []
        suppliers_data = [
            {
                "index": i,
                "platform": s.platform,
                "name": s.name,
                "price_min": s.price_min,
                "price_max": s.price_max,
                "moq": s.moq,
                "rating": s.rating,
                "reviews": s.reviews,
                "years_on_platform": s.years_on_platform,
                "delivery_days": s.delivery_days,
                "certifications": s.certifications,
            }
            for i, s in enumerate(suppliers)
        ]
        prompt = _ANALYSIS_PROMPT.format(
            query=query,
            suppliers_json=json.dumps(suppliers_data, ensure_ascii=False, indent=2),
        )
        try:
            response = self.client.messages.create(
                model=_MODEL,
                max_tokens=2048,
                messages=[{"role": "user", "content": prompt}],
            )
            text = response.content[0].text.strip()
            return json.loads(text)
        except (json.JSONDecodeError, Exception):
            return []

    def extract_contacts(self, page_text: str) -> dict:
        prompt = _CONTACTS_PROMPT.format(page_text=page_text[:3000])
        try:
            response = self.client.messages.create(
                model=_MODEL,
                max_tokens=256,
                messages=[{"role": "user", "content": prompt}],
            )
            return json.loads(response.content[0].text.strip())
        except Exception:
            return {"wechat": None, "email": None, "whatsapp": None, "phone": None}

    def generate_template(self, product: str, quantity: int, template_type: str) -> str:
        purpose = _TEMPLATE_TYPES.get(template_type, "general inquiry")
        prompt = _TEMPLATE_PROMPT.format(
            product=product, quantity=quantity, purpose=purpose
        )
        try:
            response = self.client.messages.create(
                model=_MODEL,
                max_tokens=512,
                messages=[{"role": "user", "content": prompt}],
            )
            return response.content[0].text.strip()
        except Exception:
            return f"Dear Supplier, I am interested in your {product}. Please provide pricing for {quantity} units."
```

- [ ] **Step 4: Run analyzer tests**

```bash
pytest tests/test_analyzer.py -v
```

Expected: `5 passed`

- [ ] **Step 5: Commit**

```bash
git add bot/analyzer.py tests/test_analyzer.py
git commit -m "feat: Claude AI analyzer with comparison, contacts, templates"
```

---

## Task 6: Landed Cost Calculator

**Files:**
- Create: `sourcing-bot/bot/calculator.py`
- Create: `sourcing-bot/tests/test_calculator.py`

- [ ] **Step 1: Write failing tests**

```python
# sourcing-bot/tests/test_calculator.py
import pytest
from bot.calculator import calculate_landed_cost


def test_basic_calculation():
    result = calculate_landed_cost(
        unit_price=15.0, quantity=100, weight_kg_per_unit=0.8
    )
    assert result["product_cost"] == 1500.0
    assert result["shipping"] > 0
    assert result["customs"] > 0
    assert result["total"] > result["product_cost"]
    assert result["unit_landed"] == round(result["total"] / 100, 2)


def test_unit_landed_cost_higher_than_unit_price():
    result = calculate_landed_cost(unit_price=10.0, quantity=50, weight_kg_per_unit=1.0)
    assert result["unit_landed"] > 10.0


def test_larger_quantity_lower_unit_landed():
    small = calculate_landed_cost(unit_price=10.0, quantity=50, weight_kg_per_unit=0.5)
    large = calculate_landed_cost(unit_price=10.0, quantity=500, weight_kg_per_unit=0.5)
    assert large["unit_landed"] < small["unit_landed"]


def test_result_has_all_fields():
    result = calculate_landed_cost(unit_price=5.0, quantity=200, weight_kg_per_unit=0.3)
    assert all(k in result for k in ["product_cost", "shipping", "customs", "total", "unit_landed"])


def test_customs_rate_applied():
    result = calculate_landed_cost(unit_price=100.0, quantity=10, weight_kg_per_unit=2.0)
    expected_customs = round((result["product_cost"] + result["shipping"]) * 0.15, 2)
    assert result["customs"] == expected_customs
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tests/test_calculator.py -v
```

Expected: `ModuleNotFoundError: No module named 'bot.calculator'`

- [ ] **Step 3: Implement calculator.py**

```python
# sourcing-bot/bot/calculator.py
_AIR_FREIGHT_USD_PER_KG = 4.5   # China → KZ/RU average
_CUSTOMS_RATE = 0.15             # 15% for KZ/RU


def calculate_landed_cost(
    unit_price: float,
    quantity: int,
    weight_kg_per_unit: float,
) -> dict:
    product_cost = round(unit_price * quantity, 2)
    shipping = round(weight_kg_per_unit * quantity * _AIR_FREIGHT_USD_PER_KG, 2)
    customs = round((product_cost + shipping) * _CUSTOMS_RATE, 2)
    total = round(product_cost + shipping + customs, 2)
    return {
        "product_cost": product_cost,
        "shipping": shipping,
        "customs": customs,
        "total": total,
        "unit_landed": round(total / quantity, 2),
    }
```

- [ ] **Step 4: Run calculator tests**

```bash
pytest tests/test_calculator.py -v
```

Expected: `5 passed`

- [ ] **Step 5: Commit**

```bash
git add bot/calculator.py tests/test_calculator.py
git commit -m "feat: landed cost calculator"
```

---

## Task 7: Bot Handlers — Search & Categories

**Files:**
- Create: `sourcing-bot/bot/handlers/search.py`

- [ ] **Step 1: Implement search.py**

```python
# sourcing-bot/bot/handlers/search.py
from __future__ import annotations
import asyncio
import os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler,
    ConversationHandler, MessageHandler, filters, ContextTypes,
)
from bot.database import Database, Supplier
from bot.scrapers.alibaba import scrape_alibaba
from bot.scrapers.c1688 import scrape_1688
from bot.analyzer import Analyzer

SELECTING_CATEGORY, SELECTING_SUBCATEGORY, SHOWING_RESULTS = range(3)
_RESULTS_PER_PLATFORM = 15


def _db(ctx: ContextTypes.DEFAULT_TYPE) -> Database:
    return ctx.application.bot_data["db"]


def _analyzer(ctx: ContextTypes.DEFAULT_TYPE) -> Analyzer:
    if "analyzer" not in ctx.application.bot_data:
        ctx.application.bot_data["analyzer"] = Analyzer(os.getenv("ANTHROPIC_API_KEY"))
    return ctx.application.bot_data["analyzer"]


async def start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "👋 Привет! Я ищу лучших поставщиков из Китая.\n\n"
        "Команды:\n"
        "/categories — выбрать категорию\n"
        "/search <запрос> — поиск любого товара\n"
        "/favorites — избранные поставщики\n"
        "/history — история поисков\n"
        "/add_category — добавить категорию"
    )


async def categories_command(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    db = _db(ctx)
    cats = db.get_categories()
    keyboard = [[InlineKeyboardButton(name, callback_data=f"cat:{name}")]
                for name in cats.keys()]
    await update.message.reply_text(
        "Выбери категорию:",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )
    return SELECTING_CATEGORY


async def category_selected(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    category = query.data.replace("cat:", "")
    ctx.user_data["category"] = category

    db = _db(ctx)
    cats = db.get_categories()
    subs = cats.get(category, [])

    keyboard = [[InlineKeyboardButton(sub, callback_data=f"sub:{sub}")]
                for sub in subs]
    keyboard.append([InlineKeyboardButton("🔍 Все сразу", callback_data="sub:__all__")])

    await query.edit_message_text(
        f"📦 *{category}*\nВыбери подкатегорию:",
        parse_mode="Markdown",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )
    return SELECTING_SUBCATEGORY


async def subcategory_selected(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    subcategory = query.data.replace("sub:", "")
    category = ctx.user_data.get("category", "")

    search_query = category if subcategory == "__all__" else subcategory
    ctx.user_data["last_query"] = search_query
    ctx.user_data["last_category"] = category
    ctx.user_data["last_subcategory"] = subcategory

    await query.edit_message_text(f"🔍 Ищу *{search_query}* на Alibaba и 1688...", parse_mode="Markdown")
    await _run_search(query.message, ctx, search_query, category, subcategory, update.effective_user.id)
    return ConversationHandler.END


async def search_command(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    if not ctx.args:
        await update.message.reply_text("Использование: /search <запрос>\nПример: /search массажное кресло")
        return
    search_query = " ".join(ctx.args)
    await update.message.reply_text(f"🔍 Ищу *{search_query}*...", parse_mode="Markdown")
    await _run_search(update.message, ctx, search_query, "", search_query, update.effective_user.id)


async def _run_search(message, ctx: ContextTypes.DEFAULT_TYPE, query: str,
                      category: str, subcategory: str, user_id: int):
    db = _db(ctx)
    analyzer = _analyzer(ctx)

    alibaba_results, c1688_results = await asyncio.gather(
        scrape_alibaba(query, _RESULTS_PER_PLATFORM),
        scrape_1688(query, _RESULTS_PER_PLATFORM),
    )

    all_raw = alibaba_results + c1688_results
    if not all_raw:
        await message.reply_text("😔 Ничего не найдено. Попробуй другой запрос.")
        return

    analysis = analyzer.analyze(query=query, suppliers=all_raw)
    if not analysis:
        await message.reply_text("⚠️ Не удалось проанализировать результаты. Попробуй снова.")
        return

    top5 = analysis[:5]
    saved_ids = []
    for item in top5:
        raw = all_raw[item["index"]]
        supplier = Supplier(
            platform=raw.platform,
            name=raw.name,
            price_min=raw.price_min,
            price_max=raw.price_max,
            moq=raw.moq,
            rating=raw.rating,
            reviews=raw.reviews,
            years_on_platform=raw.years_on_platform,
            delivery_days=raw.delivery_days,
            certifications=raw.certifications,
            contacts=raw.contacts,
            url=raw.url,
            search_query=query,
            red_flags=item.get("red_flags", []),
            avg_market_price=None,
            score=item.get("score", 0),
            summary=item.get("summary", ""),
        )
        saved = db.save_supplier(supplier)
        saved_ids.append(saved.id)

    db.save_search(
        user_id=user_id, query=query, category=category,
        subcategory=subcategory, results=[{"id": i} for i in saved_ids],
    )

    for rank, (item, sup_id) in enumerate(zip(top5, saved_ids), 1):
        raw = all_raw[item["index"]]
        flags = item.get("red_flags", [])
        flag_text = "\n".join(f"⚠️ {f}" for f in flags) if flags else "✅ Нет"
        platform_badge = "🇨🇳 Alibaba" if raw.platform == "alibaba" else "🏭 1688"
        price_str = (f"${raw.price_min:.2f}" if raw.price_min == raw.price_max
                     else f"${raw.price_min:.2f}–${raw.price_max:.2f}")
        text = (
            f"*{rank}. {raw.name}*\n"
            f"{platform_badge} | ⭐ {raw.rating} | 🏢 {raw.years_on_platform} лет\n"
            f"💰 {price_str}/шт | MOQ: {raw.moq} шт\n"
            f"🚚 {raw.delivery_days} дней\n"
            f"🚩 Флаги: {flag_text}\n"
            f"_{item.get('summary', '')}_"
        )
        keyboard = InlineKeyboardMarkup([
            [
                InlineKeyboardButton("📞 Контакты", callback_data=f"contacts:{sup_id}"),
                InlineKeyboardButton("💾 Сохранить", callback_data=f"save:{sup_id}"),
            ],
            [InlineKeyboardButton("📝 Шаблон письма", callback_data=f"template:{sup_id}")],
        ])
        await message.reply_text(text, parse_mode="Markdown", reply_markup=keyboard)


async def contacts_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sup_id = int(query.data.split(":")[1])
    db = _db(ctx)
    supplier = db.get_supplier(sup_id)
    if not supplier:
        await query.message.reply_text("Поставщик не найден.")
        return

    contacts = supplier.contacts or {}
    # Lazy extraction: if contacts empty, fetch supplier page and extract via Claude
    if not any(contacts.values()) and supplier.url:
        await query.message.reply_text("🔍 Извлекаю контакты со страницы поставщика...")
        try:
            from playwright.async_api import async_playwright
            async with async_playwright() as p:
                browser = await p.chromium.launch(headless=True)
                page = await browser.new_page()
                await page.goto(supplier.url, timeout=20000)
                await page.wait_for_load_state("networkidle", timeout=10000)
                page_text = await page.inner_text("body")
                await browser.close()
            analyzer = _analyzer(ctx)
            contacts = analyzer.extract_contacts(page_text)
            # Save extracted contacts back to DB
            with db.SessionLocal() as s:
                row = s.get(type(supplier), sup_id)
                if row:
                    row.contacts = contacts
                    s.commit()
        except Exception:
            contacts = {}

    lines = []
    if contacts.get("email"):
        lines.append(f"📧 Email: `{contacts['email']}`")
    if contacts.get("wechat"):
        lines.append(f"💬 WeChat: `{contacts['wechat']}`")
    if contacts.get("whatsapp"):
        lines.append(f"📱 WhatsApp: `{contacts['whatsapp']}`")
    if contacts.get("phone"):
        lines.append(f"📞 Телефон: `{contacts['phone']}`")
    if not lines:
        lines = ["Контакты не найдены. Перейди на страницу поставщика напрямую:", supplier.url or "нет ссылки"]
    await query.message.reply_text("\n".join(lines), parse_mode="Markdown")


async def template_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sup_id = int(query.data.split(":")[1])
    db = _db(ctx)
    supplier = db.get_supplier(sup_id)
    if not supplier:
        await query.message.reply_text("Поставщик не найден.")
        return
    analyzer = _analyzer(ctx)
    keyboard = InlineKeyboardMarkup([
        [InlineKeyboardButton("💬 Запрос цены", callback_data=f"tpl:price_inquiry:{sup_id}")],
        [InlineKeyboardButton("📦 Снизить MOQ", callback_data=f"tpl:moq_reduction:{sup_id}")],
        [InlineKeyboardButton("🧪 Запрос образца", callback_data=f"tpl:sample_request:{sup_id}")],
    ])
    await query.message.reply_text("Выбери тип письма:", reply_markup=keyboard)


async def template_type_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    _, tpl_type, sup_id_str = query.data.split(":")
    db = _db(ctx)
    analyzer = _analyzer(ctx)
    supplier = db.get_supplier(int(sup_id_str))
    if not supplier:
        await query.message.reply_text("Поставщик не найден.")
        return
    template = analyzer.generate_template(
        product=supplier.search_query or supplier.name,
        quantity=supplier.moq or 100,
        template_type=tpl_type,
    )
    await query.message.reply_text(
        f"📝 Скопируй и отправь поставщику:\n\n`{template}`",
        parse_mode="Markdown",
    )


def register_search_handlers(app: Application):
    conv = ConversationHandler(
        entry_points=[CommandHandler("categories", categories_command)],
        states={
            SELECTING_CATEGORY: [CallbackQueryHandler(category_selected, pattern="^cat:")],
            SELECTING_SUBCATEGORY: [CallbackQueryHandler(subcategory_selected, pattern="^sub:")],
        },
        fallbacks=[],
    )
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("search", search_command))
    app.add_handler(conv)
    app.add_handler(CallbackQueryHandler(contacts_callback, pattern="^contacts:"))
    app.add_handler(CallbackQueryHandler(template_callback, pattern="^template:"))
    app.add_handler(CallbackQueryHandler(template_type_callback, pattern="^tpl:"))
```

- [ ] **Step 2: Commit**

```bash
git add bot/handlers/search.py
git commit -m "feat: search and categories handlers"
```

---

## Task 8: Favorites & History Handlers

**Files:**
- Create: `sourcing-bot/bot/handlers/favorites.py`
- Create: `sourcing-bot/bot/handlers/history.py`

- [ ] **Step 1: Implement favorites.py**

```python
# sourcing-bot/bot/handlers/favorites.py
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
from bot.database import Database, VALID_STATUSES


def _db(ctx: ContextTypes.DEFAULT_TYPE) -> Database:
    return ctx.application.bot_data["db"]


async def favorites_command(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    db = _db(ctx)
    favs = db.get_user_favorites(user_id=update.effective_user.id)
    if not favs:
        await update.message.reply_text("У тебя пока нет избранных поставщиков.")
        return

    keyboard = []
    status_filter = ctx.user_data.get("fav_filter")
    for fav in favs:
        if status_filter and fav.status != status_filter:
            continue
        sup = fav.supplier
        if not sup:
            continue
        label = f"{sup.name[:30]} | {fav.status}"
        keyboard.append([InlineKeyboardButton(label, callback_data=f"fav_detail:{fav.id}")])

    filter_row = [InlineKeyboardButton(s, callback_data=f"fav_filter:{s}") for s in VALID_STATUSES]
    keyboard.append(filter_row[:3])
    keyboard.append(filter_row[3:] + [InlineKeyboardButton("Все", callback_data="fav_filter:__all__")])

    await update.message.reply_text(
        "⭐ Избранные поставщики:",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )


async def fav_filter_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    status = query.data.split(":")[1]
    ctx.user_data["fav_filter"] = None if status == "__all__" else status
    await favorites_command(update, ctx)


async def fav_detail_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    fav_id = int(query.data.split(":")[1])
    db = _db(ctx)
    favs = db.get_user_favorites(user_id=update.effective_user.id)
    fav = next((f for f in favs if f.id == fav_id), None)
    if not fav or not fav.supplier:
        await query.message.reply_text("Не найдено.")
        return
    sup = fav.supplier
    text = (
        f"*{sup.name}*\n"
        f"💰 ${sup.price_min:.2f}–${sup.price_max:.2f} | MOQ: {sup.moq}\n"
        f"⭐ {sup.rating} | 🏢 {sup.years_on_platform} лет\n"
        f"📌 Статус: *{fav.status}*"
    )
    status_buttons = [
        [InlineKeyboardButton(s, callback_data=f"fav_status:{fav.id}:{s}")]
        for s in VALID_STATUSES if s != fav.status
    ]
    await query.message.reply_text(text, parse_mode="Markdown",
                                   reply_markup=InlineKeyboardMarkup(status_buttons))


async def fav_status_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    _, fav_id_str, status = query.data.split(":")
    db = _db(ctx)
    updated = db.update_favorite_status(
        fav_id=int(fav_id_str), user_id=update.effective_user.id, status=status
    )
    if updated:
        await query.message.reply_text(f"✅ Статус обновлён: *{status}*", parse_mode="Markdown")
    else:
        await query.message.reply_text("Не удалось обновить статус.")


async def save_supplier_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    sup_id = int(query.data.split(":")[1])
    db = _db(ctx)
    fav = db.add_favorite(user_id=update.effective_user.id, supplier_id=sup_id)
    await query.message.reply_text("💾 Сохранено в избранное! Используй /favorites чтобы посмотреть.")


def register_favorites_handlers(app: Application):
    app.add_handler(CommandHandler("favorites", favorites_command))
    app.add_handler(CallbackQueryHandler(fav_filter_callback, pattern="^fav_filter:"))
    app.add_handler(CallbackQueryHandler(fav_detail_callback, pattern="^fav_detail:"))
    app.add_handler(CallbackQueryHandler(fav_status_callback, pattern="^fav_status:"))
    app.add_handler(CallbackQueryHandler(save_supplier_callback, pattern="^save:"))
```

- [ ] **Step 2: Implement history.py**

```python
# sourcing-bot/bot/handlers/history.py
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, ContextTypes
from bot.database import Database


def _db(ctx: ContextTypes.DEFAULT_TYPE) -> Database:
    return ctx.application.bot_data["db"]


async def history_command(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    db = _db(ctx)
    searches = db.get_user_history(user_id=update.effective_user.id, limit=20)
    if not searches:
        await update.message.reply_text("История поисков пуста.")
        return
    keyboard = []
    for s in searches:
        label = f"{s.query} ({s.created_at.strftime('%d.%m')})"
        keyboard.append([InlineKeyboardButton(label, callback_data=f"repeat:{s.id}")])
    await update.message.reply_text(
        "🕑 История поисков (нажми чтобы повторить):",
        reply_markup=InlineKeyboardMarkup(keyboard),
    )


async def repeat_search_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    from bot.handlers.search import _run_search
    query = update.callback_query
    await query.answer()
    search_id = int(query.data.split(":")[1])
    db = _db(ctx)
    searches = db.get_user_history(user_id=update.effective_user.id)
    search = next((s for s in searches if s.id == search_id), None)
    if not search:
        await query.message.reply_text("Поиск не найден.")
        return
    await query.message.reply_text(f"🔍 Повторяю поиск: *{search.query}*...", parse_mode="Markdown")
    await _run_search(
        query.message, ctx, search.query,
        search.category, search.subcategory, update.effective_user.id,
    )


def register_history_handlers(app: Application):
    app.add_handler(CommandHandler("history", history_command))
    app.add_handler(CallbackQueryHandler(repeat_search_callback, pattern="^repeat:"))
```

- [ ] **Step 3: Commit**

```bash
git add bot/handlers/favorites.py bot/handlers/history.py
git commit -m "feat: favorites with status flow and search history"
```

---

## Task 9: Admin Handler (Add Category)

**Files:**
- Create: `sourcing-bot/bot/handlers/admin.py`

- [ ] **Step 1: Implement admin.py**

```python
# sourcing-bot/bot/handlers/admin.py
from telegram import Update
from telegram.ext import (
    Application, CommandHandler, ConversationHandler,
    MessageHandler, filters, ContextTypes,
)
from bot.database import Database

ENTERING_NAME, ENTERING_SUBCATEGORIES = range(2)


def _db(ctx: ContextTypes.DEFAULT_TYPE) -> Database:
    return ctx.application.bot_data["db"]


async def add_category_start(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "Введи название новой категории:\n(например: Тренажёры)"
    )
    return ENTERING_NAME


async def category_name_received(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    ctx.user_data["new_category_name"] = update.message.text.strip()
    await update.message.reply_text(
        f"✅ Категория: *{ctx.user_data['new_category_name']}*\n\n"
        "Введи подкатегории через запятую:\n"
        "Пример: Беговая дорожка, Велотренажёр, Гантели",
        parse_mode="Markdown",
    )
    return ENTERING_SUBCATEGORIES


async def subcategories_received(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    name = ctx.user_data.get("new_category_name", "")
    subs = [s.strip() for s in update.message.text.split(",") if s.strip()]
    if not name or not subs:
        await update.message.reply_text("Ошибка: название или подкатегории пустые.")
        return ConversationHandler.END
    db = _db(ctx)
    db.add_category(name, subs)
    await update.message.reply_text(
        f"✅ Добавлена категория *{name}* с {len(subs)} подкатегориями:\n"
        + "\n".join(f"• {s}" for s in subs),
        parse_mode="Markdown",
    )
    return ConversationHandler.END


async def cancel(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Отменено.")
    return ConversationHandler.END


def register_admin_handlers(app: Application):
    conv = ConversationHandler(
        entry_points=[CommandHandler("add_category", add_category_start)],
        states={
            ENTERING_NAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, category_name_received)],
            ENTERING_SUBCATEGORIES: [MessageHandler(filters.TEXT & ~filters.COMMAND, subcategories_received)],
        },
        fallbacks=[CommandHandler("cancel", cancel)],
    )
    app.add_handler(conv)
```

- [ ] **Step 2: Commit**

```bash
git add bot/handlers/admin.py
git commit -m "feat: add_category admin handler"
```

---

## Task 10: Scheduler — Weekly Price Monitoring

**Files:**
- Create: `sourcing-bot/bot/scheduler.py`

- [ ] **Step 1: Implement scheduler.py**

```python
# sourcing-bot/bot/scheduler.py
from __future__ import annotations
import asyncio
import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from telegram.ext import Application
from bot.database import Database
from bot.scrapers.alibaba import scrape_alibaba
from bot.scrapers.c1688 import scrape_1688

logger = logging.getLogger(__name__)
_PRICE_CHANGE_THRESHOLD = 0.05  # 5%


async def check_price_changes(app: Application, db: Database):
    favorites = db.get_all_favorites_for_monitoring()
    if not favorites:
        return

    checked: dict[str, float] = {}

    for fav in favorites:
        supplier = fav.supplier
        if not supplier:
            continue
        query = supplier.search_query
        if not query or query in checked:
            continue

        try:
            if supplier.platform == "alibaba":
                results = await scrape_alibaba(query, n=5)
            else:
                results = await scrape_1688(query, n=5)
        except Exception as e:
            logger.error(f"Scrape failed for {query}: {e}")
            continue

        if not results:
            continue

        avg_new = sum(r.price_min for r in results) / len(results)
        avg_old = supplier.price_min or avg_new
        checked[query] = avg_new

        change_pct = (avg_new - avg_old) / avg_old if avg_old > 0 else 0
        if abs(change_pct) >= _PRICE_CHANGE_THRESHOLD:
            direction = "📈 выросла" if change_pct > 0 else "📉 снизилась"
            message = (
                f"💡 *Изменение цены*\n"
                f"Товар: {query}\n"
                f"Цена {direction} на {abs(change_pct)*100:.1f}%\n"
                f"Было: ${avg_old:.2f} → Стало: ${avg_new:.2f}"
            )
            try:
                await app.bot.send_message(
                    chat_id=fav.user_id,
                    text=message,
                    parse_mode="Markdown",
                )
            except Exception as e:
                logger.error(f"Failed to notify user {fav.user_id}: {e}")


def start_scheduler(app: Application, db: Database):
    scheduler = AsyncIOScheduler()
    scheduler.add_job(
        check_price_changes,
        trigger="cron",
        day_of_week="sun",
        hour=9,
        minute=0,
        args=[app, db],
    )
    scheduler.start()
    logger.info("Price monitoring scheduler started (every Sunday 09:00)")
```

- [ ] **Step 2: Commit**

```bash
git add bot/scheduler.py
git commit -m "feat: weekly price monitoring scheduler"
```

---

## Task 11: Integration & First Run

**Files:**
- Verify: `sourcing-bot/main.py` (уже создан в Task 1)
- Create: `sourcing-bot/.env` (из .env.example)

- [ ] **Step 1: Copy .env and fill in tokens**

```bash
cd sourcing-bot
cp .env.example .env
```

Открой `.env` и вставь:
- `TELEGRAM_TOKEN` — из @BotFather в Telegram
- `ANTHROPIC_API_KEY` — из console.anthropic.com

- [ ] **Step 2: Run all tests**

```bash
pytest tests/ -v
```

Expected: `17 passed` (database: 7, analyzer: 5, calculator: 5, scrapers: 11 — итого ~28)

- [ ] **Step 3: Install python-dotenv (нужен для main.py)**

Добавь в `requirements.txt`:
```
python-dotenv==1.0.1
```

```bash
pip install python-dotenv
```

- [ ] **Step 4: Run the bot**

```bash
python main.py
```

Expected:
```
Bot started...
Price monitoring scheduler started (every Sunday 09:00)
```

- [ ] **Step 5: Тест в Telegram**

1. Открой бота в Telegram
2. Отправь `/start` → ожидай приветственное сообщение
3. Отправь `/categories` → ожидай кнопки с категориями
4. Выбери "Массажное оборудование" → выбери "Пистолет-массажер"
5. Подожди 30–60 сек → ожидай топ-5 поставщиков

- [ ] **Step 6: Final commit**

```bash
git add .env.example requirements.txt
git commit -m "feat: integration complete, bot ready to run"
```

---

## Troubleshooting

**Alibaba/1688 возвращают пустой список:**
Сайты часто меняют CSS-классы. Запусти scraper вручную и проверь HTML:
```python
# debug_scraper.py
import asyncio
from playwright.async_api import async_playwright

async def debug():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)  # headless=False чтобы видеть браузер
        page = await browser.new_page()
        await page.goto("https://www.alibaba.com/trade/search?SearchText=massage+gun")
        await page.wait_for_load_state("networkidle")
        html = await page.content()
        with open("debug.html", "w") as f:
            f.write(html)
        await browser.close()

asyncio.run(debug())
```
Открой `debug.html`, найди CSS-класс карточки товара и обнови селектор в `parse_alibaba_html`.

**Claude API ошибки:**
Проверь баланс на console.anthropic.com. При ошибке `overloaded_error` — добавь `asyncio.sleep(5)` и retry.

**Telegram polling конфликт:**
Убедись что бот запущен только в одном месте. Удали webhook если он был: `https://api.telegram.org/bot<TOKEN>/deleteWebhook`
