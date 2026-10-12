# debian-bootstrap

تجهيز وتقوية سيرفر **Debian 12** بشكل قابل للتكرار (idempotent) مع تسجيل كامل وإمكانية
التشغيل التجريبي (`--dry-run`).

الطبقة المنطقية مكتوبة بـ **Python** (قراءة الإعداد، التسجيل، dry-run، ترتيب المراحل)،
والعمليات النظامية مكتوبة بـ **bash** في سكربتات مستقلة قابلة للقراءة والتدقيق.

## ما الذي يفعله

1. **user** — إنشاء مستخدم sudo غير root مع مفتاح SSH.
2. **ssh** — تعطيل دخول root والمصادقة بكلمة المرور، والتحقق من صحّة الإعداد قبل reload.
3. **ufw** — جدار ناري: رفض الوارد افتراضياً، السماح بالمنافذ 22/80/443، ثم التفعيل.
4. **fail2ban** — حماية sshd من محاولات التخمين.
5. **updates** — تحديثات أمنية تلقائية عبر `unattended-upgrades`.
6. **docker** — تثبيت Docker Engine و Compose v2 من المستودع الرسمي.
7. **swap** — إنشاء swapfile وتثبيته في `fstab` وضبط `vm.swappiness`.
8. **time** — ضبط المنطقة الزمنية وتفعيل NTP.
9. **systemd** — تثبيت قوالب وحدات systemd في `/etc/systemd/system`.

كل مرحلة **تفحص الحالة أولاً** ولا تغيّر شيئاً إن كان مضبوطاً مسبقاً، فإعادة التشغيل آمنة.

## المتطلبات

- Debian 12 (bookworm) نظيف.
- Python 3.11+ (Debian 12 يتضمن 3.11). الكود يعتمد على `tomllib` المتوفر منذ 3.11.
- صلاحيات root (شغّل عبر `sudo`).

## الإعداد

```bash
cp config/bootstrap.example.toml config/bootstrap.toml
$EDITOR config/bootstrap.toml
```

أهم القيم: `[user].name` و`ssh_public_key`/`ssh_public_key_path`، ومنافذ `[ufw]`، وحجم
`[swap].size`، و`[time].timezone`.

## التشغيل

```bash
# عرض المراحل المتاحة
sudo ./bootstrap.sh --list

# معاينة كاملة دون أي تغيير على النظام (موصى به أولاً)
sudo ./bootstrap.sh --dry-run

# التنفيذ الكامل
sudo ./bootstrap.sh

# مراحل محدّدة / مستثناة
sudo ./bootstrap.sh --only docker
sudo ./bootstrap.sh --skip docker,swap
sudo ./bootstrap.sh --config config/bootstrap.toml -v
```

## المخرجات والسجلات

- كل تشغيل يكتب سجلاً في `logs/bootstrap-<timestamp>.log`.
- السكربتات تطبع سطوراً مباشرة إلى الطرفية وتضيفها للسجل أيضاً.

## أمان

- لا تُخزَّن أي أسرار في المستودع؛ مفتاح SSH يُقرأ من الملف المحدد ويُكتب بصلاحيات `0600`.
- ملفات SSH تُنشأ بـ `0700`/`0600` ومملوكة للمستخدم الهدف.
- `sshd_config` يُتحقق منه بـ `sshd -t` قبل أي reload، ويُؤخذ نسخة احتياطية من أي ملف يُستبدل
  بصيغة `<file>.bak.<timestamp>`.

## الاختبار المحلي

```bash
python -m pip install -e ".[dev]"
pytest
bash -n bootstrap.sh scripts/*.sh scripts/lib/*.sh
```

## الرخصة

MIT — انظر [LICENSE](LICENSE).
