# VFPWebServer 0.3.0 Developer Preview (Visual FoxPro 9)

یک سرور HTTP برای Visual FoxPro 9 با فریمورکی به سبک FastAPI.

با این سرور، API وب را با خود فاکس‌پرو می‌نویسید: آدرس‌ها، پارامترها و مدل‌ها را تعریف می‌کنید؛ سرور درخواست‌ها را اعتبارسنجی می‌کند، نتیجه را به JSON تبدیل می‌کند و مستندات تعاملی را در `/docs` منتشر می‌کند. برنامه‌های فاکس‌پروی سمت کاربر (فرانت‌اند) با کتابخانه کلاینت همراه بسته به API وصل می‌شوند.

نسخه 0.3.0-preview - Copyright (c) 2026 Ramin Orak, Aryana Software - [raminorak.com](https://raminorak.com)

نسخه انگلیسی این راهنما: `README.md`

## دانلود

آخرین نسخه را از صفحه [Releases](https://github.com/raminok/vfp-webserver-release/releases) بگیرید:

| فایل | برای |
|---|---|
| `VFPWebServer-<version>-Setup.exe` | نصب‌کننده (پیشنهادی) |
| `VFPWebServer-<version>.zip` | سرور بدون نصب: از حالت فشرده خارج کنید و `VFPWebServer.exe` را اجرا کنید |
| `VFPWSClient-<version>.zip` | کتابخانه کلاینت برای برنامه‌های فرانت‌اند فاکس‌پرو |

ویندوز ممکن است برای فایل تازه دانلودشده پیام «Windows protected your PC» نشان دهد: More info و بعد Run anyway را بزنید.

## محتوای این مخزن

| مسیر | محتوا |
|---|---|
| `Apps\Template\` | قالب شروع برنامه خودتان |
| `Apps\Samples\` | برنامه‌های نمونه (کالاها، دفترچه تلفن، قطعات) |
| `Apps\AppDemo\` | نمونه برنامه دوفایلی که به صورت `.app` ساخته می‌شود |
| `Clients\` | کتابخانه کلاینت `VFPWSClient.prg`، راهنما و مثال آن |
| `README_FRAMEWORK.md` | مرجع کامل فریمورک (انگلیسی) |
| `test_api.ps1` | تست خودکار برنامه نمونه |

خود سرور به صورت برنامه کامپایل‌شده عرضه می‌شود و سورس آن منتشر نمی‌شود. سؤال‌ها و گزارش خطا: [Issues](https://github.com/raminok/vfp-webserver-release/issues).

## امکانات

- سرور HTTP مستقیم روی Winsock، با آیکون در System Tray و داشبورد زنده (اتصال‌ها، ترافیک، Endpointها، Request Inspector، Log)
- Routeها با پارامترهای Path، Query، Header، Form و Body از نوع JSON
- مدل‌ها با اعتبارسنجی؛ خطای `422` با همان قالب FastAPI
- تولید خودکار OpenAPI 3.0، Swagger UI در `/docs` و ReDoc در `/redoc`
- جواب‌های JSON، HTML، متنی، فایل و Redirect
- API Key جداگانه برای هر برنامه کلاینت (فقط Hash آن ذخیره می‌شود)
- رمز مدیر اختیاری برای تنظیمات سرور (PBKDF2-SHA256)
- بارگذاری برنامه توسعه‌دهنده به صورت کامپایل‌شده (`.fxp` یا `.app`) و بارگذاری دوباره با هر Start
- برنامه نمونه داخل خود EXE: بدون هیچ فایل کناری، `/docs` آماده تست است
- کتابخانه کلاینت برای فرانت‌اند فاکس‌پرو: HTTP، JSON و تبدیل لیست به Cursor

## اولین اجرا

فقط خود `VFPWebServer.exe` لازم است. در اولین اجرا، کنار EXE این‌ها ساخته می‌شوند:

```
Config\              تنظیمات و جدول API Keyها
Logs\                Log برنامه
Apps\Samples\        app.prg و app.fxp (برنامه نمونه)
```

تنظیم پیش‌فرض برنامه همان `Apps\Samples\app.fxp` است؛ پس با زدن Start، صفحه `http://localhost:8080/docs` همه Endpointهای نمونه را نشان می‌دهد. نمونه داده‌هایش را در `Apps\Samples\Data` می‌سازد. فایل‌های موجود هیچ‌وقت بازنویسی نمی‌شوند و اگر پوشه نمونه پاک شود، در اجرای بعدی دوباره ساخته می‌شود.

EXE همیشه در پوشه خودش کار می‌کند؛ فرقی نمی‌کند از میان‌بر، خط فرمان یا Task Scheduler اجرا شود.

## شروع سریع

1. `VFPWebServer.exe` را اجرا کنید و Start Server بزنید.
2. `http://localhost:8080/docs` را باز کنید: برنامه نمونه آماده است.
3. برنامه خودتان: بخش بعد.

## برنامه خودتان، قدم به قدم

برنامه نمونه در `Apps\Samples` نشان می‌دهد همه چیز چطور کار می‌کند. API شما یک برنامه جداست که می‌نویسید، کامپایل می‌کنید و به سرور معرفی می‌کنید. خود EXE سرور هیچ‌وقت تغییر نمی‌کند.

### ۱. پوشه بسازید

`Apps\Template` را در یک پوشه جدید کپی کنید و فایل را تغییر نام دهید، مثلاً:

```
Apps\Orders\orders.prg
```

هر پوشه‌ای قابل استفاده است (حتی بیرون از `Apps`)؛ برای هر برنامه یک پوشه. فایل‌های داده در پوشه `Data` داخل همان پوشه قرار می‌گیرند.

### ۲. Routeها را در `ConfigureApp` تعریف کنید

در `ConfigureApp` مشخص می‌کنید API چه چیزهایی دارد: مدل‌ها (شکل JSON ورودی) و Routeها (آدرس، Handler و پارامترها).

```foxpro
PROCEDURE ConfigureApp
    LPARAMETERS toApp
    LOCAL loModel, loRoute

    toApp.RequireVersion("0.3")
    toApp.cTitle = "Orders API"

    loModel = toApp.Model("OrderIn")
    loModel.Field("customer", "str", .T., .NULL., "min_length=1;max_length=50")
    loModel.Field("amount", "float", .T., .NULL., "ge=0")

    loRoute = toApp.Get("/orders/{id}", "OrdersHandler.GetOrder")
    loRoute.Path("id", "int")

    loRoute = toApp.Get("/orders", "OrdersHandler.ListOrders")
    loRoute.Query("customer", "str", .F., "")

    loRoute = toApp.Post("/orders", "OrdersHandler.AddOrder")
    loRoute.Body("order", "OrderIn")
    loRoute.StatusCode(201)
ENDPROC
```

کدام نوع پارامتر: **کدام رکورد؟** Path (`/orders/15`) - **چه داده‌ای ذخیره شود؟** Body (JSON) - **چطور نشان بده؟** Query (`?customer=ali`، جستجو، فیلتر، صفحه‌بندی).

### ۳. Handlerها را بنویسید

هر Route یک متد از کلاس Handler شما را صدا می‌زند. پارامترها با `LPARAMETERS` و به همان ترتیب تعریف می‌رسند و هر چه `RETURN` شود به JSON تبدیل می‌شود.

```foxpro
DEFINE CLASS OrdersHandler AS VFPWSHandler

    PROCEDURE GetOrder
        LPARAMETERS tnId
        LOCAL loOrder
        Ord_Open()
        SELECT * FROM orders WHERE id = tnId INTO CURSOR curOrder
        IF _TALLY = 0
            THROW HTTPException(404, "Order not found")
        ENDIF
        loOrder = THIS.Row("curOrder")
        USE IN curOrder
        RETURN loOrder
    ENDPROC

ENDDEFINE

PROCEDURE Ord_Open
    IF NOT USED("orders")
        USE (AppPath("Data\orders.dbf")) IN 0 SHARED AGAIN ALIAS orders
    ENDIF
ENDPROC
```

- `AppPath("Data\orders.dbf")` یعنی پوشه برنامه شما؛ به پوشه جاری تکیه نکنید.
- جدول‌ها را `SHARED` باز کنید تا برنامه‌های دسکتاپ هم‌زمان کار کنند.
- برای Procedureهای کمکی پیشوند بگذارید (`Ord_...`) تا با سرور تداخل نکنند.
- Handlerها را سریع نگه دارید: سرور هر بار به یک درخواست جواب می‌دهد.
- نام متغیرها را تک‌حرفی A تا J نگذارید؛ این‌ها نام ناحیه‌های کاری فاکس‌پرو هستند.

### ۴. کامپایل کنید

سرور فقط برنامه کامپایل‌شده را اجرا می‌کند. در محیط VFP:

```foxpro
COMPILE Apps\Orders\orders.prg
```

نتیجه فایل `orders.fxp` است. اگر فایل `orders.err` ساخته شد، خطاهای کامپایل در آن است. برنامه چندفایلی به صورت `.app` ساخته می‌شود (`README_FRAMEWORK.md`، بخش «Application files: .fxp or .app»).

### ۵. برنامه را به سرور معرفی کنید

در Settings > Application دکمه Browse را بزنید، `Apps\Orders\orders.fxp` را انتخاب کنید و Save بزنید. همین تنظیم در `Config\server.ini`:

```ini
[App]
Program=Apps\Orders\orders.fxp
```

از این به بعد برنامه شما به جای نمونه اجرا می‌شود. برای برگشت به نمونه، دوباره `Apps\Samples\app.fxp` را انتخاب کنید.

### ۶. Start بزنید و نتیجه را ببینید

Start Server را بزنید (اگر روشن است: Stop و بعد Start). پیام Tray و خط اول زبانه API Endpoints نتیجه را نشان می‌دهند:

| پیام | معنی |
|---|---|
| `loaded Apps\Orders\orders.fxp (3 routes)` | آماده است |
| `WARNING: orders.prg is newer than orders.fxp` | سورس را تغییر داده‌اید ولی کامپایل نکرده‌اید |
| `NOT LOADED - file not found` | مسیر اشتباه در Settings > Application |
| `NOT LOADED - ... is source code` | فایل `.prg` انتخاب شده؛ `.fxp` را انتخاب کنید |
| `NOT LOADED - error ...` | خطا در `ConfigureApp`: پیام، شماره خط و نام Procedure |

اگر برنامه بارگذاری نشود، سرور با Endpointهای System (`/api/health` و ...) روشن می‌شود تا شبکه قابل بررسی بماند.

### ۷. تست کنید

`http://localhost:8080/docs` را باز کنید. همه Routeهایی که تعریف کرده‌اید با پارامترهایشان آنجا هستند و Try it out یک درخواست واقعی می‌فرستد. ورودی نامعتبر، بدون هیچ کدی از طرف شما، با `422` و نام فیلد مشکل‌دار جواب داده می‌شود.

### ۸. تغییر بدهید و تکرار کنید

`orders.prg` را ویرایش کنید، `COMPILE` بزنید و سرور را Stop و Start کنید. بستن برنامه یا Build دوباره سرور لازم نیست.

### ۹. امنیت

- Settings > Require an API key را روشن کنید و در API Keys برای هر برنامه کلاینت یک کلید بسازید. کلاینت‌ها کلید را در هدر `X-Api-Key` می‌فرستند.
- Settings > Set Password... تنظیمات سرور را روی کامپیوتر سرور محافظت می‌کند.

### ۱۰. تحویل

به مشتری `VFPWebServer.exe` و پوشه برنامه‌تان (`Apps\Orders` با `orders.fxp` و `Data`) را بدهید و یک بار Settings > Application را روی کامپیوتر او تنظیم کنید. دادن سورس `.prg` لازم نیست.

برنامه‌های فرانت‌اند با `Clients\VFPWSClient.prg` به API شما وصل می‌شوند (راهنما: `Clients\README_CLIENT.md`).

## رفتار پنجره و Tray

- کلیک روی X داشبورد را با یک انیمیشن و پیام به Tray می‌فرستد؛ سرور متوقف نمی‌شود.
- دوبار کلیک روی آیکون Tray داشبورد را باز می‌کند.
- کلیک راست منو را باز می‌کند: وضعیت سرور، Start یا Stop Server، Dashboard، Settings (Server Address and Port...، API Keys...)، Quick Links، Check for Updates، About، Exit.
- اگر رمز مدیر تعیین شده باشد، Stop Server، Exit، Settings، API Keys و Check for Updates رمز می‌خواهند. بعد از رمز درست، این کارها ۵ دقیقه بدون رمز انجام می‌شوند و پس از ۵ رمز اشتباه، پنجره رمز ۶۰ ثانیه قفل می‌شود. اگر رمز فراموش شد، خط `AdminPassword` را از بخش `[Security]` در `Config\server.ini` پاک کنید.
- از هر پوشه فقط یک نسخه برنامه اجرا می‌شود؛ اجرای دوباره، داشبورد نسخه در حال اجرا را نشان می‌دهد.

## امنیت شبکه

Bind Address پیش‌فرض `0.0.0.0` است و روی همه کارت‌های شبکه گوش می‌دهد. برای تست فقط روی همین کامپیوتر از `127.0.0.1` استفاده کنید. پیش از باز کردن سرور روی شبکه، API Key را روشن کنید و پورت را در فایروال ویندوز فقط برای شبکه‌های مورد اعتماد باز کنید. سرور فقط HTTP است؛ برای HTTPS آن را پشت IIS، nginx یا Caddy قرار دهید.

## محدودیت‌های این Preview

- سرور تک‌نخی است: یک Handler کند، بقیه درخواست‌ها را معطل می‌کند.
- برای هر پوشه سرور یک برنامه؛ برای برنامه دوم، پوشه سرور را کپی کنید و پورت دیگری بدهید.
- هنوز موجود نیست: آپلود فایل (`multipart`)، `Depends`، Middleware، CORS، Background Tasks، مدل‌های تودرتو.
- حالت `.app` و بیرون نوشتن برنامه نمونه از داخل EXE باید روی نسخه دقیق VFP9 و Windows شما آزمایش شود.

## مجوز

| بخش | مجوز |
|---|---|
| برنامه VFPWebServer، نصب‌کننده و مستندات | Freeware برای استفاده غیرتجاری، بدون هیچ ضمانتی (AS IS) - `LICENSE.txt`. استفاده تجاری مجوز می‌خواهد: sales@aryanasoftware.ca |
| `Clients\` (کتابخانه کلاینت) | MIT - `Clients\LICENSE.txt` |
| `Apps\` (قالب و نمونه‌ها) | MIT - `Apps\LICENSE.txt` |

برنامه‌هایی که با VFPWebServer می‌سازید و اجرا می‌کنید متعلق به خودتان است. متن حقوقی معتبر، متن انگلیسی `LICENSE.txt` است.

## نیازمندی‌ها

- Windows 7 یا جدیدتر
- Runtime فاکس‌پرو 9 برای اجرای سرور (داخل نصب‌کننده و فایل zip هست)
- Visual FoxPro 9 SP2 برای کامپایل برنامه‌های خودتان
- متن فارسی و عربی: Code Page ویندوز 1256 (تنظیم Language for non-Unicode programs)
