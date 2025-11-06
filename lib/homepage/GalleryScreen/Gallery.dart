import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';

class Gallery extends StatelessWidget {
  const Gallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: const Center(child: Text("Itt vannak a képek")),
      bottomNavigationBar: Container(
        height: 60,
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 14, 66, 18).withOpacity(0.9),
          border: Border(
            top: BorderSide(color: AppTheme.textColor.withOpacity(0.3)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Bal oldali gomb - Filter
            Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: TextButton(
                onPressed: () {}, // Üres függvény most
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, color: AppTheme.textColor),
                    SizedBox(width: 8),
                    Text(
                      'Filter',
                      style: TextStyle(
                        color: AppTheme.textColor,
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Jobb oldali gomb - My Map
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: TextButton(
                onPressed: () {}, // Üres függvény most
                child: Text(
                  'My Map',
                  style: TextStyle(
                    color: AppTheme.textColor,
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
