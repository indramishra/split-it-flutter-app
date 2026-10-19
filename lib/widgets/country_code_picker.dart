import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CountryCodeResult {
  final String countryCode;
  final String dialCode;
  final String flag;
  final String name;

  CountryCodeResult({
    required this.countryCode,
    required this.dialCode,
    required this.flag,
    required this.name,
  });
}

class CountryCodePicker extends StatefulWidget {
  final String selectedCountryCode;

  const CountryCodePicker({
    super.key,
    required this.selectedCountryCode,
  });

  @override
  State<CountryCodePicker> createState() => _CountryCodePickerState();
}

class _CountryCodePickerState extends State<CountryCodePicker> {
  final List<CountryCodeData> _countries = [
    CountryCodeData(code: 'IN', dialCode: '+91', name: 'India', flag: '🇮🇳'),
    CountryCodeData(code: 'US', dialCode: '+1', name: 'United States', flag: '🇺🇸'),
    CountryCodeData(code: 'GB', dialCode: '+44', name: 'United Kingdom', flag: '🇬🇧'),
    CountryCodeData(code: 'CA', dialCode: '+1', name: 'Canada', flag: '🇨🇦'),
    CountryCodeData(code: 'AU', dialCode: '+61', name: 'Australia', flag: '🇦🇺'),
    CountryCodeData(code: 'DE', dialCode: '+49', name: 'Germany', flag: '🇩🇪'),
    CountryCodeData(code: 'FR', dialCode: '+33', name: 'France', flag: '🇫🇷'),
    CountryCodeData(code: 'IT', dialCode: '+39', name: 'Italy', flag: '🇮🇹'),
    CountryCodeData(code: 'ES', dialCode: '+34', name: 'Spain', flag: '🇪🇸'),
    CountryCodeData(code: 'BR', dialCode: '+55', name: 'Brazil', flag: '🇧🇷'),
    CountryCodeData(code: 'MX', dialCode: '+52', name: 'Mexico', flag: '🇲🇽'),
    CountryCodeData(code: 'JP', dialCode: '+81', name: 'Japan', flag: '🇯🇵'),
    CountryCodeData(code: 'KR', dialCode: '+82', name: 'South Korea', flag: '🇰🇷'),
    CountryCodeData(code: 'SG', dialCode: '+65', name: 'Singapore', flag: '🇸🇬'),
    CountryCodeData(code: 'MY', dialCode: '+60', name: 'Malaysia', flag: '🇲🇾'),
    CountryCodeData(code: 'ID', dialCode: '+62', name: 'Indonesia', flag: '🇮🇩'),
    CountryCodeData(code: 'TH', dialCode: '+66', name: 'Thailand', flag: '🇹🇭'),
    CountryCodeData(code: 'PH', dialCode: '+63', name: 'Philippines', flag: '🇵🇭'),
    CountryCodeData(code: 'VN', dialCode: '+84', name: 'Vietnam', flag: '🇻🇳'),
    CountryCodeData(code: 'NL', dialCode: '+31', name: 'Netherlands', flag: '🇳🇱'),
    CountryCodeData(code: 'SE', dialCode: '+46', name: 'Sweden', flag: '🇸🇪'),
    CountryCodeData(code: 'NO', dialCode: '+47', name: 'Norway', flag: '🇳🇴'),
    CountryCodeData(code: 'DK', dialCode: '+45', name: 'Denmark', flag: '🇩🇰'),
    CountryCodeData(code: 'FI', dialCode: '+358', name: 'Finland', flag: '🇫🇮'),
    CountryCodeData(code: 'PT', dialCode: '+351', name: 'Portugal', flag: '🇵🇹'),
    CountryCodeData(code: 'BE', dialCode: '+32', name: 'Belgium', flag: '🇧🇪'),
    CountryCodeData(code: 'CH', dialCode: '+41', name: 'Switzerland', flag: '🇨🇭'),
    CountryCodeData(code: 'AT', dialCode: '+43', name: 'Austria', flag: '🇦🇹'),
    CountryCodeData(code: 'IE', dialCode: '+353', name: 'Ireland', flag: '🇮🇪'),
    CountryCodeData(code: 'ZA', dialCode: '+27', name: 'South Africa', flag: '🇿🇦'),
    CountryCodeData(code: 'NG', dialCode: '+234', name: 'Nigeria', flag: '🇳🇬'),
    CountryCodeData(code: 'ET', dialCode: '+251', name: 'Ethiopia', flag: '🇪🇹'),
    CountryCodeData(code: 'EG', dialCode: '+20', name: 'Egypt', flag: '🇪🇬'),
    CountryCodeData(code: 'TR', dialCode: '+90', name: 'Turkey', flag: '🇹🇷'),
    CountryCodeData(code: 'IL', dialCode: '+972', name: 'Israel', flag: '🇮🇱'),
    CountryCodeData(code: 'AE', dialCode: '+971', name: 'United Arab Emirates', flag: '🇦🇪'),
    CountryCodeData(code: 'SA', dialCode: '+966', name: 'Saudi Arabia', flag: '🇸🇦'),
    CountryCodeData(code: 'QA', dialCode: '+974', name: 'Qatar', flag: '🇶🇦'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = _countries.firstWhere(
      (c) => c.dialCode == widget.selectedCountryCode,
      orElse: () => _countries.first,
    );

    return DropdownButton<CountryCodeData>(
      value: selected,
      isExpanded: false,
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      style: const TextStyle(color: AppTheme.charcoal),
      underline: Container(
        height: 0,
      ),
      onChanged: (newValue) {
        if (newValue != null) {
          Navigator.of(context).pop(newValue);
        }
      },
      items: _countries.map<DropdownMenuItem<CountryCodeData>>((c) {
        return DropdownMenuItem<CountryCodeData>(
          value: c,
          child: Row(
            children: [
              Text(c.flag),
              const SizedBox(width: 4),
              Text('${c.dialCode} (${c.code})', style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class CountryCodeData {
  final String code;
  final String dialCode;
  final String name;
  final String flag;

  CountryCodeData({
    required this.code,
    required this.dialCode,
    required this.name,
    required this.flag,
  });
}

// Simple mapping from country code to flag emoji
String countryCodeToFlag(String countryCode) {
  final countryCodeUpper = countryCode.toUpperCase();
  final firstLetter = countryCodeUpper.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final secondLetter = countryCodeUpper.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
}

Future<CountryCodeResult?> showCountryCodePicker({
  required BuildContext context,
  required String selectedCountryCode,
}) async {
  return showModalBottomSheet<CountryCodeResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Select Country',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.charcoal,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final c = countries[index];
                  final isSelected = c.dialCode == selectedCountryCode && c.flag.contains(getFlagFromDialCode(c.dialCode));
                  return ListTile(
                    onTap: () {
                      Navigator.of(context).pop(
                        CountryCodeResult(
                          countryCode: c.code,
                          dialCode: c.dialCode,
                          flag: getFlagFromDialCode(c.dialCode),
                          name: c.name,
                        ),
                      );
                    },
                    leading: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Text(
                        getFlagFromDialCode(c.dialCode),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      c.dialCode,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppTheme.teal, size: 18)
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Convert dial code to flag - simplified mapping
String getFlagFromDialCode(String dialCode) {
  final flagMap = {
    '+91': '🇮🇳',
    '+1': '🇺🇸', // Default to US for +1
    '+44': '🇬🇧',
    '+61': '🇦🇺',
    '+49': '🇩🇪',
    '+33': '🇫🇷',
    '+39': '🇮🇹',
    '+34': '🇪🇸',
    '+55': '🇧🇷',
    '+52': '🇲🇽',
    '+81': '🇯🇵',
    '+82': '🇰🇷',
    '+65': '🇸🇬',
    '+60': '🇲🇾',
    '+62': '🇮🇩',
    '+66': '🇹🇭',
    '+63': '🇵🇭',
    '+84': '🇻🇳',
    '+31': '🇳🇱',
    '+46': '🇸🇪',
    '+47': '🇳🇴',
    '+45': '🇩🇰',
    '+358': '🇫🇮',
    '+351': '🇵🇹',
    '+32': '🇧🇪',
    '+41': '🇨🇭',
    '+43': '🇦🇹',
    '+353': '🇮🇪',
    '+27': '🇿🇦',
    '+234': '🇳🇬',
    '+251': '🇪🇹',
    '+20': '🇪🇬',
    '+90': '🇹🇷',
    '+972': '🇮🇱',
    '+971': '🇦🇪',
    '+966': '🇸🇦',
    '+974': '🇶🇦',
  };

  if (dialCode == '+1') {
    // Return US flag for +1
    return '🇺🇸';
  }
  return flagMap[dialCode] ?? '🇺🇳';
}

// List of countries with dial codes
final List<CountryCodeData> countries = [
  CountryCodeData(code: 'IN', dialCode: '+91', name: 'India', flag: '🇮🇳'),
  CountryCodeData(code: 'US', dialCode: '+1', name: 'United States', flag: '🇺🇸'),
  CountryCodeData(code: 'CA', dialCode: '+1', name: 'Canada', flag: '🇨🇦'),
  CountryCodeData(code: 'GB', dialCode: '+44', name: 'United Kingdom', flag: '🇬🇧'),
  CountryCodeData(code: 'AU', dialCode: '+61', name: 'Australia', flag: '🇦🇺'),
  CountryCodeData(code: 'DE', dialCode: '+49', name: 'Germany', flag: '🇩🇪'),
  CountryCodeData(code: 'FR', dialCode: '+33', name: 'France', flag: '🇫🇷'),
  CountryCodeData(code: 'IT', dialCode: '+39', name: 'Italy', flag: '🇮🇹'),
  CountryCodeData(code: 'ES', dialCode: '+34', name: 'Spain', flag: '🇪🇸'),
  CountryCodeData(code: 'BR', dialCode: '+55', name: 'Brazil', flag: '🇧🇷'),
  CountryCodeData(code: 'MX', dialCode: '+52', name: 'Mexico', flag: '🇲🇽'),
  CountryCodeData(code: 'JP', dialCode: '+81', name: 'Japan', flag: '🇯🇵'),
  CountryCodeData(code: 'KR', dialCode: '+82', name: 'South Korea', flag: '🇰🇷'),
  CountryCodeData(code: 'SG', dialCode: '+65', name: 'Singapore', flag: '🇸🇬'),
  CountryCodeData(code: 'MY', dialCode: '+60', name: 'Malaysia', flag: '🇲🇾'),
  CountryCodeData(code: 'ID', dialCode: '+62', name: 'Indonesia', flag: '🇮🇩'),
  CountryCodeData(code: 'TH', dialCode: '+66', name: 'Thailand', flag: '🇹🇭'),
  CountryCodeData(code: 'PH', dialCode: '+63', name: 'Philippines', flag: '🇵🇭'),
  CountryCodeData(code: 'VN', dialCode: '+84', name: 'Vietnam', flag: '🇻🇳'),
  CountryCodeData(code: 'NL', dialCode: '+31', name: 'Netherlands', flag: '🇳🇱'),
  CountryCodeData(code: 'SE', dialCode: '+46', name: 'Sweden', flag: '🇸🇪'),
  CountryCodeData(code: 'NO', dialCode: '+47', name: 'Norway', flag: '🇳🇴'),
  CountryCodeData(code: 'DK', dialCode: '+45', name: 'Denmark', flag: '🇩🇰'),
  CountryCodeData(code: 'FI', dialCode: '+358', name: 'Finland', flag: '🇫🇮'),
  CountryCodeData(code: 'PT', dialCode: '+351', name: 'Portugal', flag: '🇵🇹'),
  CountryCodeData(code: 'BE', dialCode: '+32', name: 'Belgium', flag: '🇧🇪'),
  CountryCodeData(code: 'CH', dialCode: '+41', name: 'Switzerland', flag: '🇨🇭'),
  CountryCodeData(code: 'AT', dialCode: '+43', name: 'Austria', flag: '🇦🇹'),
  CountryCodeData(code: 'IE', dialCode: '+353', name: 'Ireland', flag: '🇮🇪'),
  CountryCodeData(code: 'ZA', dialCode: '+27', name: 'South Africa', flag: '🇿🇦'),
  CountryCodeData(code: 'NG', dialCode: '+234', name: 'Nigeria', flag: '🇳🇬'),
  CountryCodeData(code: 'ET', dialCode: '+251', name: 'Ethiopia', flag: '🇪🇹'),
  CountryCodeData(code: 'EG', dialCode: '+20', name: 'Egypt', flag: '🇪🇬'),
  CountryCodeData(code: 'TR', dialCode: '+90', name: 'Turkey', flag: '🇹🇷'),
  CountryCodeData(code: 'IL', dialCode: '+972', name: 'Israel', flag: '🇮🇱'),
  CountryCodeData(code: 'AE', dialCode: '+971', name: 'United Arab Emirates', flag: '🇦🇪'),
  CountryCodeData(code: 'SA', dialCode: '+966', name: 'Saudi Arabia', flag: '🇸🇦'),
  CountryCodeData(code: 'QA', dialCode: '+974', name: 'Qatar', flag: '🇶🇦'),
];
