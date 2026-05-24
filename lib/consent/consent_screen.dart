import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.onDecision});

  final void Function(bool accepted) onDecision;

  static const String shortText =
      'Az alkalmazás fotókat, helyadatokat és használati információkat gyűjthet (pl. helymeghatározás, feltöltött képek, analitika). Ezeket az alkalmazás működtetéséhez és a szolgáltatás biztosításához használjuk.';

  static const String detailedPolicy = '''
Adatkezelési tájékoztató

1) Bevezetés
Ez a tájékoztató ismerteti, milyen adatokat gyűjtünk, miért és hogyan használjuk fel azokat.

2) Adatkezelő
Gedő Loránd, elérhetőség: gedolorand@gmail.com.

3) Mely adatokat gyűjtjük és miért
- Helyadatok (GPS): a fotók helyének megjelenítéséhez és helyalapú szolgáltatásokhoz.
- Feltöltött képek és metaadatok: a felhasználó tartalmainak tárolásához és megjelenítéséhez.
- Azonosítók / user ID: hitelesítés és jogosultság-kezelés.
- Analitikai adatok: alkalmazás fejlesztéséhez és hibakereséshez.

4) Adatmegosztás és harmadik felek
Használhatunk szolgáltatókat (pl. Firebase) az adatok tárolására és feldolgozására.

5) Adatmegőrzés
A felhasználói tartalmak törölhetők felhasználói kérésre.

6) A jogok
Hozzáférés, helyesbítés, törlés, adathordozhatóság. Kapcsolat: gedolorand@gmail.com (Gedő Loránd).

7) Biztonság
Titkosítás átvitel közben, hozzáférés-szabályozás.

8) Kapcsolat
Kérdések: gedolorand@gmail.com (Gedő Loránd).

Utolsó frissítés: 2026-05-22
''';

  Future<void> _setConsent(bool value) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('consentGiven', value);
  }

  void _accept(BuildContext context) async {
    await _setConsent(true);
    onDecision(true);
  }

  void _decline(BuildContext context) async {
    await _setConsent(false);
    onDecision(false);
  }

  void _showDetailed(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Részletes adatkezelés'),
        content: SingleChildScrollView(child: Text(detailedPolicy)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('Bezár'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: const Text('Adatkezelési hozzájárulás'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Text(shortText, style: TextStyle(color: AppTheme.textColor)),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              onPressed: () => _accept(context),
              child: const Text('Elfogadom'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _decline(context),
              child: const Text('Elutasítom'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _showDetailed(context),
              child: const Text('Részletes adatkezelés'),
            ),
            const SizedBox(height: 12),
            const Spacer(),
            Text(
              'Megjegyzés: ha elutasítod a gyűjtést, néhány szolgáltatás (helymegosztás, analitika) korlátozva lehet.',
              style: TextStyle(color: AppTheme.textColor.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
