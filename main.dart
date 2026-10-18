import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(SehatakApp(prefs: prefs));
}

class SehatakApp extends StatefulWidget {
  const SehatakApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<SehatakApp> createState() => _SehatakAppState();
}

class _SehatakAppState extends State<SehatakApp> {
  late bool _darkMode = widget.prefs.getBool('darkMode') ?? false;
  late String _language = widget.prefs.getString('language') ?? 'ar';

  Future<void> _setDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await widget.prefs.setBool('darkMode', value);
  }

  Future<void> _setLanguage(String value) async {
    setState(() => _language = value);
    await widget.prefs.setString('language', value);
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _language == 'ar';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'صحتك | Sehatak',
      locale: Locale(_language),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F73)),
        scaffoldBackgroundColor: const Color(0xFFF4F8F6),
        cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20)))),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), filled: true),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF45C6B4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: ProfileGate(
          prefs: widget.prefs,
          isArabic: isArabic,
          darkMode: _darkMode,
          onDarkModeChanged: _setDarkMode,
          onLanguageChanged: _setLanguage,
        ),
      ),
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.prefs,
    required this.isArabic,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.onLanguageChanged,
  });

  final SharedPreferences prefs;
  final bool isArabic;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _ready = false;
  bool _hasProfile = false;
  String _name = '';
  double _height = 0;
  double _weight = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    _hasProfile = widget.prefs.getBool('profileSaved') ?? false;
    _name = widget.prefs.getString('name') ?? '';
    _height = widget.prefs.getDouble('height') ?? 0;
    _weight = widget.prefs.getDouble('weight') ?? 0;
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _saveProfile(String name, double height, double weight) async {
    await widget.prefs.setBool('profileSaved', true);
    await widget.prefs.setString('name', name);
    await widget.prefs.setDouble('height', height);
    await widget.prefs.setDouble('weight', weight);
    if (mounted) {
      setState(() {
        _hasProfile = true;
        _name = name;
        _height = height;
        _weight = weight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasProfile) {
      return OnboardingScreen(
        isArabic: widget.isArabic,
        onSave: _saveProfile,
        onLanguageChanged: widget.onLanguageChanged,
      );
    }
    return MainHomeScreen(
      prefs: widget.prefs,
      isArabic: widget.isArabic,
      name: _name,
      height: _height,
      weight: _weight,
      darkMode: widget.darkMode,
      onDarkModeChanged: widget.onDarkModeChanged,
      onLanguageChanged: widget.onLanguageChanged,
      onEditProfile: () async {
        await widget.prefs.setBool('profileSaved', false);
        if (mounted) setState(() => _hasProfile = false);
      },
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.isArabic,
    required this.onSave,
    required this.onLanguageChanged,
  });
  final bool isArabic;
  final Future<void> Function(String, double, double) onSave;
  final ValueChanged<String> onLanguageChanged;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  late String _language = widget.isArabic ? 'ar' : 'en';
  String _belief = 'none';
  bool _saving = false;

  String get tTitle => widget.isArabic ? 'لنبدأ رحلتك الصحية' : 'Start your wellness journey';
  String get tName => widget.isArabic ? 'الاسم (اختياري)' : 'Name (optional)';
  String get tHeight => widget.isArabic ? 'الطول بالسنتيمتر' : 'Height in cm';
  String get tWeight => widget.isArabic ? 'الوزن بالكيلوجرام' : 'Weight in kg';
  String get tSave => widget.isArabic ? 'حفظ ومتابعة' : 'Save and continue';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String? _numberValidator(String? value, double min, double max, String label) {
    final n = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
    if (n == null) return widget.isArabic ? 'أدخل $label بصورة صحيحة' : 'Enter a valid $label';
    if (n < min || n > max) {
      return widget.isArabic ? 'القيمة يجب أن تكون بين $min و$max' : 'Value must be between $min and $max';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        _nameCtrl.text.trim(),
        double.parse(_heightCtrl.text.trim().replaceAll(',', '.')),
        double.parse(_weightCtrl.text.trim().replaceAll(',', '.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.isArabic ? 'تعذر حفظ البيانات. حاول مرة أخرى.' : 'Could not save your details. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isArabic ? 'إعداد الملف الشخصي' : 'Set up your profile')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              const Icon(Icons.eco_rounded, size: 68, color: Colors.teal),
              const SizedBox(height: 12),
              Text(tTitle, textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                widget.isArabic ? 'بياناتك محفوظة على هذا الجهاز فقط في هذا الإصدار.' : 'In this version, your information is saved on this device only.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              DropdownButtonFormField<String>(
                value: _language,
                decoration: InputDecoration(labelText: widget.isArabic ? 'لغة التطبيق' : 'App language', border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'ar', child: const Text('العربية')),
                  DropdownMenuItem(value: 'en', child: const Text('English')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _language = v);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(labelText: tName, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.person_outline)),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 14),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _heightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: tHeight, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.height)),
                      validator: (v) => _numberValidator(v, 80, 250, widget.isArabic ? 'الطول' : 'height'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _weightCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: tWeight, border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.monitor_weight_outlined)),
                      validator: (v) => _numberValidator(v, 20, 350, widget.isArabic ? 'الوزن' : 'weight'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _belief,
                decoration: InputDecoration(labelText: widget.isArabic ? 'تفضيل المحتوى (اختياري)' : 'Content preference (optional)', border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'none', child: Text(widget.isArabic ? 'بدون تفضيل' : 'No preference')),
                  DropdownMenuItem(value: 'islam', child: Text(widget.isArabic ? 'محتوى إسلامي' : 'Islamic content')),
                  DropdownMenuItem(value: 'christian', child: Text(widget.isArabic ? 'محتوى مسيحي' : 'Christian content')),
                ],
                onChanged: (v) => setState(() => _belief = v ?? 'none'),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : () async {
                  widget.onLanguageChanged(_language);
                  await _submit();
                },
                icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline),
                label: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(tSave)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({
    super.key,
    required this.prefs,
    required this.isArabic,
    required this.name,
    required this.height,
    required this.weight,
    required this.darkMode,
    required this.onDarkModeChanged,
    required this.onLanguageChanged,
    required this.onEditProfile,
  });
  final SharedPreferences prefs;
  final bool isArabic;
  final String name;
  final double height;
  final double weight;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback onEditProfile;

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _index = 0;
  late int _water = widget.prefs.getInt('water') ?? 0;
  late int _waterGoal = widget.prefs.getInt('waterGoal') ?? 8;
  late int _workoutsDone = widget.prefs.getInt('workoutsDone') ?? 0;
  late List<String> _history = widget.prefs.getStringList('history') ?? [];

  bool get ar => widget.isArabic;
  String tr(String arText, String enText) => ar ? arText : enText;

  Future<void> _changeWater(int delta) async {
    final next = (_water + delta).clamp(0, 20);
    setState(() => _water = next);
    await widget.prefs.setInt('water', next);
  }

  Future<void> _completeWorkout(String name) async {
    _workoutsDone++;
    _history.insert(0, '${DateTime.now().toLocal().toString().substring(0, 16)} — $name');
    if (_history.length > 30) _history = _history.take(30).toList();
    await widget.prefs.setInt('workoutsDone', _workoutsDone);
    await widget.prefs.setStringList('history', _history);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(ar: ar, name: widget.name, water: _water, waterGoal: _waterGoal,
          workoutsDone: _workoutsDone, height: widget.height, weight: widget.weight, onWaterChange: _changeWater),
      WorkoutsTab(ar: ar, onComplete: _completeWorkout),
      FoodTab(ar: ar),
      SettingsTab(
        ar: ar,
        darkMode: widget.darkMode,
        waterGoal: _waterGoal,
        history: _history,
        onDarkModeChanged: widget.onDarkModeChanged,
        onLanguageChanged: widget.onLanguageChanged,
        onGoalChanged: (v) async {
          setState(() => _waterGoal = v);
          await widget.prefs.setInt('waterGoal', v);
        },
        onEditProfile: widget.onEditProfile,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: tr('الرئيسية', 'Home')),
          NavigationDestination(icon: const Icon(Icons.fitness_center), label: tr('التمارين', 'Workouts')),
          NavigationDestination(icon: const Icon(Icons.restaurant_menu), label: tr('الغذاء', 'Food')),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), label: tr('الإعدادات', 'Settings')),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.ar, required this.name, required this.water, required this.waterGoal, required this.workoutsDone, required this.height, required this.weight, required this.onWaterChange});
  final bool ar;
  final String name;
  final int water;
  final int waterGoal;
  final int workoutsDone;
  final double height;
  final double weight;
  final ValueChanged<int> onWaterChange;

  String _bmiLabel() {
    if (height <= 0 || weight <= 0) return '—';
    return (weight / ((height / 100) * (height / 100))).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final quotesAr = ['﴿ وَأَن لَيْسَ لِلْإِنسَانِ إِلَّا مَا سَعَى ﴾', 'العقل السليم في الجسم السليم', 'خطوة صغيرة كل يوم تصنع فرقاً'];
    final quotesEn = ['Small steps every day make a difference.', 'Consistency is more important than perfection.', 'Take care of your body; it is your home.'];
    final quote = (ar ? quotesAr : quotesEn)[Random().nextInt(3)];
    final displayName = name.isEmpty ? (ar ? 'صديق الصحة' : 'Wellness friend') : name;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Text(ar ? 'مرحباً $displayName 🌱' : 'Welcome, $displayName 🌱',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(ar ? 'ابدأ اليوم بخطوة بسيطة نحو صحة أفضل.' : 'Start today with one small step toward better health.'),
        const SizedBox(height: 18),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(padding: const EdgeInsets.all(18), child: Text(quote, style: Theme.of(context).textTheme.titleMedium)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _MetricCard(icon: Icons.monitor_weight_outlined, title: ar ? 'مؤشر كتلة الجسم' : 'BMI', value: _bmiLabel(), subtitle: ar ? 'تقدير توعوي' : 'Informational estimate')),
          const SizedBox(width: 12),
          Expanded(child: _MetricCard(icon: Icons.fitness_center, title: ar ? 'التمارين' : 'Workouts', value: '$workoutsDone', subtitle: ar ? 'تمرين مسجل' : 'logged workouts')),
        ]),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.water_drop, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(child: Text(ar ? 'متتبع المياه' : 'Water tracker', style: Theme.of(context).textTheme.titleLarge)),
                Text('$water / $waterGoal'),
              ]),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: waterGoal == 0 ? 0 : (water / waterGoal).clamp(0, 1).toDouble(), minHeight: 8),
              const SizedBox(height: 8),
              Text(ar ? 'كل إضافة تمثل كوباً تقريبياً. احتياج الماء يختلف حسب الشخص والطقس والنشاط.' : 'Each entry represents an approximate glass. Water needs vary by person, weather and activity.'),
              const SizedBox(height: 10),
              Row(children: [
                OutlinedButton.icon(onPressed: water > 0 ? () => onWaterChange(-1) : null, icon: const Icon(Icons.remove), label: Text(ar ? 'إنقاص' : 'Remove')),
                const Spacer(),
                FilledButton.icon(onPressed: water < 20 ? () => onWaterChange(1) : null, icon: const Icon(Icons.add), label: Text(ar ? 'إضافة كوب' : 'Add glass')),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.icon, required this.title, required this.value, required this.subtitle});
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Colors.teal, size: 28),
        const SizedBox(height: 10),
        Text(title),
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ]),
    ),
  );
}

class WorkoutsTab extends StatelessWidget {
  const WorkoutsTab({super.key, required this.ar, required this.onComplete});
  final bool ar;
  final Future<void> Function(String) onComplete;

  @override
  Widget build(BuildContext context) {
    final workouts = ar
        ? [('القرفصاء', 'تقوية عضلات الساقين', '3 مجموعات × 10 تكرارات', Icons.accessibility_new), ('المشي', 'نشاط خفيف مناسب لكثير من الأشخاص', '10 دقائق', Icons.directions_walk), ('تمرين الضغط', 'تقوية الجزء العلوي من الجسم', '2 مجموعات حسب القدرة', Icons.fitness_center)]
        : [('Squats', 'Strengthen leg muscles', '3 sets × 10 reps', Icons.accessibility_new), ('Walking', 'Light activity suitable for many people', '10 minutes', Icons.directions_walk), ('Push-ups', 'Strengthen the upper body', '2 sets as able', Icons.fitness_center)];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(ar ? 'التمارين الرياضية' : 'Workouts', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text(ar ? 'اختر نشاطاً يناسب لياقتك. توقف إذا شعرت بألم أو دوار.' : 'Choose an activity suited to your fitness. Stop if you feel pain or dizziness.'),
      const SizedBox(height: 16),
      for (final w in workouts)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(radius: 26, child: Icon(w.$4)),
            title: Text(w.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('${w.$2}\n${w.$3}')),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: ar ? 'تسجيل الإنجاز' : 'Log completion',
              icon: const Icon(Icons.check_circle_outline, color: Colors.teal),
              onPressed: () async {
                await onComplete(w.$1);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'تم تسجيل التمرين!' : 'Workout logged!')));
                }
              },
            ),
          ),
        ),
    ]);
  }
}

class FoodTab extends StatelessWidget {
  const FoodTab({super.key, required this.ar});
  final bool ar;

  @override
  Widget build(BuildContext context) {
    final meals = ar
        ? [('الفطور', 'شوفان بالحليب وفاكهة', 'مثال تقريبي: 300–400 سعر حراري'), ('الغداء', 'دجاج أو بقوليات مع أرز وخضروات', 'مثال تقريبي: 450–650 سعر حراري'), ('العشاء', 'زبادي أو بيض مع خبز وخضروات', 'مثال تقريبي: 250–400 سعر حراري'), ('وجبة خفيفة', 'ثمرة فاكهة أو حفنة مكسرات', 'حسب الكمية والاحتياج')]
        : [('Breakfast', 'Oats with milk and fruit', 'Approx. example: 300–400 kcal'), ('Lunch', 'Chicken or legumes with rice and vegetables', 'Approx. example: 450–650 kcal'), ('Dinner', 'Yogurt or eggs with bread and vegetables', 'Approx. example: 250–400 kcal'), ('Snack', 'A piece of fruit or a handful of nuts', 'Depends on portion and needs')];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(ar ? 'أفكار غذائية متوازنة' : 'Balanced meal ideas', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(ar ? 'هذه أمثلة عامة وليست خطة طبية أو احتياجاً محسوباً لك.' : 'These are general examples, not a medical plan or personalized calorie target.'),
      const SizedBox(height: 16),
      for (final meal in meals)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.restaurant, color: Colors.teal, size: 30),
            title: Text(meal.$1, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('${meal.$2}\n${meal.$3}')),
            isThreeLine: true,
          ),
        ),
    ]);
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    super.key,
    required this.ar,
    required this.darkMode,
    required this.waterGoal,
    required this.history,
    required this.onDarkModeChanged,
    required this.onLanguageChanged,
    required this.onGoalChanged,
    required this.onEditProfile,
  });
  final bool ar;
  final bool darkMode;
  final int waterGoal;
  final List<String> history;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<int> onGoalChanged;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(ar ? 'الإعدادات' : 'Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      SwitchListTile(
        secondary: const Icon(Icons.dark_mode_outlined),
        title: Text(ar ? 'الوضع الداكن' : 'Dark mode'),
        value: darkMode,
        onChanged: onDarkModeChanged,
      ),
      ListTile(
        leading: const Icon(Icons.language),
        title: Text(ar ? 'لغة التطبيق' : 'App language'),
        subtitle: Text(ar ? 'العربية' : 'English'),
        trailing: DropdownButton<String>(
          value: ar ? 'ar' : 'en',
          items: const [
            DropdownMenuItem(value: 'ar', child: Text('العربية')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: (v) { if (v != null) onLanguageChanged(v); },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.water_drop_outlined),
        title: Text(ar ? 'هدف أكواب الماء' : 'Water glass goal'),
        subtitle: Text('$waterGoal'),
        trailing: DropdownButton<int>(
          value: waterGoal,
          items: [6, 8, 10, 12].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
          onChanged: (v) { if (v != null) onGoalChanged(v); },
        ),
      ),
      ListTile(
        leading: const Icon(Icons.history),
        title: Text(ar ? 'سجل التمارين' : 'Workout history'),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(ar ? 'سجل التمارين' : 'Workout history'),
            content: SizedBox(
              width: 360,
              child: history.isEmpty
                  ? Text(ar ? 'لم تسجل أي تمارين بعد.' : 'No workouts logged yet.')
                  : ListView(shrinkWrap: true, children: history.map((item) => ListTile(dense: true, leading: const Icon(Icons.check_circle_outline), title: Text(item))).toList()),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(ar ? 'إغلاق' : 'Close'))],
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(ar ? 'تعديل الملف الشخصي' : 'Edit profile'),
        onTap: onEditProfile,
      ),
      const Divider(),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          ar
              ? 'تنبيه: التطبيق للتوعية والعادات الصحية العامة، ولا يغني عن استشارة مختص. بيانات الخطوات المعروضة تجريبية وليست من حساس الهاتف.'
              : 'Note: This app provides general wellness guidance and does not replace professional advice. Displayed step data is sample data, not measured by your phone.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ]);
  }
}
