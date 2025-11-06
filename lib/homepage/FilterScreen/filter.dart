import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';

// Állapotmegőrző widget, mert a felhasználó kiválaszt dolgokat, ezeket meg kell őrizni
class Filter extends StatefulWidget {
  const Filter({Key? key}) : super(key: key);

  @override
  State<Filter> createState() => _FilterState();
}

class _FilterState extends State<Filter> {
  // Választott hal típusa (legördülőből választja ki a felhasználó)
  String? selectedFishType;

  // Súly beviteléhez TextField vezérlő
  final TextEditingController weightController = TextEditingController();

  // Kezdő és záró idő (TimePicker-rel választjuk ki)
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // Egy konkrét nap, amikor a hal fogható volt (DatePicker-rel választjuk ki)
  DateTime? selectedDate;

  // A hal típusok listája – ezek jelennek meg a DropdownButton-ben
  final List<String> fishTypes = ['Ponty', 'Csuka', 'Süllő', 'Harcsa', 'Amur'];

  // Ez a függvény időpont választásra szolgál (kezdő vagy záró)
  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startTime = picked;
        } else {
          endTime = picked;
        }
      });
    }
  }

  // Ez a függvény dátum választására szolgál
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020), // csak 2020 utáni dátumokat lehet választani
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(), // Saját appbar
      drawer: CustomDrawer(), // Saját oldalsó menü
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          // Görgethető lista az elemekhez
          children: [
            /// --- 1. Hal fajtája (Dropdown) ---
            Text(
              "Hal fajtája",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            DropdownButton<String>(
              value: selectedFishType,
              hint: Text("Válassz hal fajtát"),
              isExpanded: true, // kitölti a szélességet
              dropdownColor: const Color(0xFFE8F5E9),
              items: fishTypes.map((String fish) {
                return DropdownMenuItem<String>(value: fish, child: Text(fish));
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedFishType = newValue;
                });
              },
            ),
            const SizedBox(height: 16),

            /// --- 2. Súly mező (TextField) ---
            Text(
              "Súly (kg)",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number, // csak számokat lehet beírni
              decoration: InputDecoration(
                hintText: "Add meg a súlyt",
                border: OutlineInputBorder(), // keret
              ),
            ),
            const SizedBox(height: 16),

            /// --- 3. Időintervallum (2 gomb – TimePicker) ---
            Text(
              "Időintervallum",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(
                        255,
                        14,
                        66,
                        18,
                      ), // ← egyedi háttérszín
                      foregroundColor: Color(0xFFE8F5E9), // ← szöveg színe
                    ),
                    onPressed: () => _selectTime(context, true),
                    child: Text(
                      startTime == null
                          ? "Kezdő időpont"
                          : startTime!.format(context),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(
                        255,
                        14,
                        66,
                        18,
                      ), // ← egyedi háttérszín
                      foregroundColor: Color(0xFFE8F5E9), // ← szöveg színe
                    ),
                    onPressed: () => _selectTime(context, false),
                    child: Text(
                      endTime == null
                          ? "Záró időpont"
                          : endTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// --- 4. Dátum kiválasztása (DatePicker) ---
            Text(
              "Dátum",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(
                  255,
                  14,
                  66,
                  18,
                ), // ← egyedi háttérszín
                foregroundColor: Color(0xFFE8F5E9), // ← szöveg színe
              ),
              onPressed: () => _selectDate(context),
              child: Text(
                selectedDate == null
                    ? "Válassz dátumot"
                    : "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}",
              ),
            ),

            const SizedBox(height: 32),

            /// --- 5. Alkalmazás gomb ---
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(
                  255,
                  14,
                  66,
                  18,
                ), // ← egyedi háttérszín
                foregroundColor: Color(0xFFE8F5E9), // ← szöveg színe
              ),
              onPressed: () {
                // Itt dolgozhatod fel a kiválasztott értékeket
                print("Hal fajtája: $selectedFishType");
                print("Súly: ${weightController.text}");
                print(
                  "Időintervallum: ${startTime?.format(context)} - ${endTime?.format(context)}",
                );
                print("Dátum: $selectedDate");
              },
              child: Text("Szűrés alkalmazása"),
            ),
          ],
        ),
      ),
    );
  }
}
