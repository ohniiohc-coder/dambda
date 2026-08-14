import 'package:flutter/material.dart';
import '../state/locale_state.dart';
import '../theme/app_theme.dart';

class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  static const _languages = <String, String>{
    'ko': '한국어',
    'en': 'English',
    'ja': '日本語',
    'zh': '中文',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Language',
      onSelected: (code) => localeState.setLocale(Locale(code)),
      itemBuilder: (context) => _languages.entries
          .map(
            (entry) => PopupMenuItem<String>(
              value: entry.key,
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: localeState.locale.languageCode == entry.key
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value),
                ],
              ),
            ),
          )
          .toList(),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.language, size: 19, color: AppColors.textPrimary),
            SizedBox(width: 5),
            Text(
              'Language',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
