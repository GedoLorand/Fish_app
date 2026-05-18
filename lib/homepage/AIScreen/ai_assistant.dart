import 'package:flutter/material.dart';
import 'package:login_fish_app/homepage/Header/global_header.dart';
import 'package:login_fish_app/homepage/Header/custom_drawer.dart';
import 'package:login_fish_app/homepage/Initial/initialType.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({Key? key}) : super(key: key);

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen>
  with SingleTickerProviderStateMixin {
  bool _isDayMode = false; // false = night (current), true = day (light background)
  String? selectedFishType;
  final TextEditingController speciesController = TextEditingController();
  final TextEditingController questionController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  List<String> dynamicFishSuggestions = [];
  bool _micEnabled = false;
  bool _speciesLocked = false; // when user typed a message

  bool _showHelper = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  bool _messageLocked = false; // when user selected/typed species

  final List<String> fishTypes = ['Ponty', 'Csuka', 'Süllő', 'Harcsa', 'Amur'];
  TextEditingController? _autocompleteController;
  bool _autocompleteListenerAttached = false;

  void _onAutocompleteChanged() {
    final t = _autocompleteController?.text ?? '';
    if (speciesController.text != t) speciesController.text = t;
    final has = t.trim().isNotEmpty;
    if (has != _messageLocked) setState(() => _messageLocked = has);
  }

  @override
  void initState() {
    super.initState();
    _loadDynamicSpecies();
    speciesController.addListener(_onSpeciesChanged);
    questionController.addListener(_onQuestionChanged);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.99, end: 1.01).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  void _onSpeciesChanged() {
    final has = speciesController.text.trim().isNotEmpty;
    if (has != _messageLocked) setState(() => _messageLocked = has);
    if (has && _showHelper) setState(() => _showHelper = false);
  }

  void _onQuestionChanged() {
    final has = questionController.text.trim().isNotEmpty;
    if (has != _speciesLocked) setState(() => _speciesLocked = has);
    if (has && _showHelper) setState(() => _showHelper = false);
  }

  Future<void> _loadDynamicSpecies() async {
    try {
      final q = await FirebaseFirestore.instance
          .collectionGroup('images')
          .get();
      final set = <String>{};
      for (final doc in q.docs) {
        final data = doc.data();
        final s = data['species'];
        if (s is String && s.trim().isNotEmpty) set.add(s.trim());
      }
      setState(() => dynamicFishSuggestions = set.toList()..sort());
    } catch (_) {
      // ignore errors; fallback to hardcoded list
    }
  }

  void _addMessage(String role, String text) {
    setState(() {
      _messages.insert(0, {'role': role, 'text': text});
      if (_messages.isNotEmpty && _showHelper) _showHelper = false;
    });
  }

  void _askAiGeneral() {
    final q = questionController.text.trim();
    if (q.isEmpty) {
      _addMessage('assistant', 'Kérlek írj be egy kérdést.');
      return;
    }
    _addMessage('user', q);
    _addMessage(
      'assistant',
      'Válasz a következő kérdésre: "$q"\n(Helykitöltő válasz)',
    );
    questionController.clear();
  }

  void _askAiAboutSpecies() {
    final typed = speciesController.text.trim();
    final species = (selectedFishType != null && selectedFishType!.isNotEmpty)
        ? selectedFishType!
        : (typed.isNotEmpty ? typed : null);
    if (species == null) {
      _addMessage('assistant', 'Kérlek válassz vagy írj be egy halfajtát.');
      return;
    }
    _addMessage('user', 'Kérdés a halfajtáról: $species');
    _addMessage(
      'assistant',
      '$species — Részletes információk (helykitöltő):\n- Jellemzők: ...\n- Élőhely: ...\n- Fogási tippek: ...',
    );
    setState(() => _messageLocked = true);
  }

  Future<void> _showSpeciesPicker(
    BuildContext context,
    List<String> source,
    Color textColor,
  ) async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: ListView.separated(
            itemCount: source.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = source[i];
              return ListTile(
                title: Text(s, style: TextStyle(color: textColor)),
                onTap: () => Navigator.of(context).pop(s),
              );
            },
          ),
        );
      },
    );
    if (pick != null)
      setState(() {
        selectedFishType = pick;
        speciesController.text = pick;
        _messageLocked = true;
        _showHelper = false;
      });

    // Ensure Autocomplete's internal controller also reflects the picked value
    if (pick != null && _autocompleteController != null) {
      _autocompleteController!.text = pick;
      _autocompleteController!.selection = TextSelection.collapsed(
        offset: pick.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _isDayMode ? Colors.white : AppTheme.surfaceColor;
    final textColor = _isDayMode ? Colors.black87 : AppTheme.textColor;
    final surfaceColor = _isDayMode ? Colors.grey.shade200 : AppTheme.surfaceColor;
    final primaryColor = AppTheme.primaryColor;

    final source = dynamicFishSuggestions.isNotEmpty
        ? dynamicFishSuggestions
        : fishTypes;
    return Scaffold(
      backgroundColor: bgColor,
      appBar: GlobalHeader(),
      drawer: CustomDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            final double messagesMax = (maxHeight * 0.35)
                .clamp(120.0, 360.0)
                .toDouble();
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'AI Asszisztens',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: _isDayMode ? 'Nappali mód' : 'Éjjeli mód',
                              icon: Icon(
                                _isDayMode ? Icons.wb_sunny : Icons.nights_stay,
                                color: textColor,
                                size: 20,
                              ),
                              onPressed: () => setState(() => _isDayMode = !_isDayMode),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Centered AI icon with vertical padding
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Image.asset(
                            'assets/icon/chatbot.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Species row
                      Row(
                        children: [
                          Expanded(
                            child: Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                final q = textEditingValue.text.toLowerCase();
                                if (q.isEmpty) return const Iterable<String>.empty();
                                return source.where((s) => s.toLowerCase().contains(q));
                              },
                              onSelected: (s) => setState(() {
                                selectedFishType = s;
                                speciesController.text = s;
                                if (_autocompleteController != null) _autocompleteController!.text = s;
                                _messageLocked = true;
                              }),
                              fieldViewBuilder: (
                                context,
                                controller,
                                focusNode,
                                onEditingComplete,
                              ) {
                                _autocompleteController = controller;
                                if (!_autocompleteListenerAttached) {
                                  controller.addListener(_onAutocompleteChanged);
                                  _autocompleteListenerAttached = true;
                                }
                                return TextField(
                                  enabled: !_speciesLocked,
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    hintText: 'Halfaj megadása',
                                    border: OutlineInputBorder(),
                                  ),
                                );
                              },
                              optionsViewBuilder: (context, onSelectedCallback, options) {
                                final opts = options.toList();
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxHeight: 220,
                                        maxWidth: MediaQuery.of(context).size.width - 100,
                                      ),
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: opts.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, index) {
                                          final s = opts[index] as String;
                                          return ListTile(
                                            title: Text(s, style: TextStyle(color: textColor)),
                                            onTap: () { onSelectedCallback(s); },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Lista megnyitása',
                            icon: Icon(Icons.list, color: textColor),
                            onPressed: _speciesLocked ? null : () => _showSpeciesPicker(context, source, textColor),
                          ),
                          IconButton(
                            tooltip: 'Törlés',
                            icon: Icon(
                              Icons.clear,
                              color: textColor.withOpacity(0.6),
                            ),
                            onPressed: () => setState(() {
                              selectedFishType = null;
                              speciesController.clear();
                              if (_autocompleteController != null) _autocompleteController!.clear();
                              _messageLocked = false;
                            }),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),
                      // Show apply button when species field contains text
                      if (_messageLocked) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                selectedFishType = speciesController.text
                                    .trim();
                                _messageLocked = true;
                              });
                              FocusScope.of(context).unfocus();
                            },
                            child: const Text('Alkalmazás'),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Question input
                      Text(
                        'Kérdezz az AI-tól',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        enabled: !_messageLocked,
                        controller: questionController,
                        decoration: InputDecoration(
                          hintText: _messageLocked
                              ? 'Lezárva: előbb töröld a halfajta mezőt'
                              : 'Írd be a kérdésedet az AI-hoz',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.send,
                              color: primaryColor,
                            ),
                            onPressed: _messageLocked ? null : _askAiGeneral,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Helper pulsing box shown while the chat is empty and inputs untouched
                      if (_showHelper) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: ScaleTransition(
                            scale: _pulseAnim,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                color: surfaceColor.withOpacity(0.20),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: textColor.withOpacity(0.10)),
                              ),
                              child: Text(
                                'Az AI bot segítségével az első mezőben megadhatjuk a halfajtát és egy általános leírást kaphatunk a szokásairól, méretéről, valamint élőhelyéről. Ha szeretnénk, a második mezőben kérdezhetünk és kommunikálhatunk az AI-val.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.95)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (_messages.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Válaszok',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: messagesMax,
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            reverse: true,
                            itemCount: _messages.length,
                            itemBuilder: (context, i) {
                              final m = _messages[i];
                              final isUser = m['role'] == 'user';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Align(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isUser
                                          ? primaryColor.withOpacity(
                                              0.9,
                                            )
                                          : surfaceColor.withOpacity(
                                              0.04,
                                            ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: textColor.withOpacity(
                                          0.04,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      m['text'] ?? '',
                                      style: TextStyle(
                                        color: textColor.withOpacity(
                                          isUser ? 0.95 : 0.9,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      const SizedBox.shrink(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    speciesController.removeListener(_onSpeciesChanged);
    questionController.removeListener(_onQuestionChanged);
    if (_autocompleteController != null && _autocompleteListenerAttached) {
      _autocompleteController!.removeListener(_onAutocompleteChanged);
    }
    _pulseController.dispose();
    speciesController.dispose();
    questionController.dispose();
    super.dispose();
  }
}
