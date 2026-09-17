import 'package:flutter/material.dart';
import 'package:kupon_office_admin/app/theme/app_theme.dart';

/// Modelo de província de Angola.
class Province {
  final String name;
  final String code;
  final double? centerLat;
  final double? centerLng;
  final double zoom;

  const Province({
    required this.name,
    required this.code,
    this.centerLat,
    this.centerLng,
    this.zoom = 9,
  });
}

/// As 18 províncias de Angola (ordem alfabética).
const kProvinces = [
  Province(name: 'Bengo',           code: 'BGO', centerLat:  -9.1069, centerLng:  13.7300, zoom:  8.5),
  Province(name: 'Benguela',        code: 'BGU', centerLat: -12.5763, centerLng:  13.4055, zoom:  8.5),
  Province(name: 'Bié',             code: 'BIE', centerLat: -12.3500, centerLng:  17.0000, zoom:  8.0),
  Province(name: 'Cabinda',         code: 'CAB', centerLat:  -5.0000, centerLng:  12.2000, zoom:  9.5),
  Province(name: 'Cuando Cubango',  code: 'CCG', centerLat: -16.3333, centerLng:  18.6667, zoom:  7.0),
  Province(name: 'Cuanza Norte',    code: 'CNO', centerLat:  -9.0500, centerLng:  15.0833, zoom:  8.5),
  Province(name: 'Cuanza Sul',      code: 'CSU', centerLat: -10.8333, centerLng:  14.9167, zoom:  8.0),
  Province(name: 'Cunene',          code: 'CNN', centerLat: -16.6000, centerLng:  15.6167, zoom:  8.0),
  Province(name: 'Huambo',          code: 'HUA', centerLat: -12.7756, centerLng:  15.7394, zoom:  9.0),
  Province(name: 'Huíla',           code: 'HUI', centerLat: -14.9167, centerLng:  14.9167, zoom:  8.0),
  Province(name: 'Luanda',          code: 'LDA', centerLat:  -8.8390, centerLng:  13.2894, zoom: 11.5),
  Province(name: 'Lunda Norte',     code: 'LNO', centerLat:  -8.6500, centerLng:  20.4167, zoom:  7.5),
  Province(name: 'Lunda Sul',       code: 'LSU', centerLat: -10.0000, centerLng:  20.3833, zoom:  7.5),
  Province(name: 'Malanje',         code: 'MAL', centerLat:  -9.5400, centerLng:  16.3400, zoom:  8.5),
  Province(name: 'Moxico',          code: 'MOX', centerLat: -13.5000, centerLng:  20.3333, zoom:  7.0),
  Province(name: 'Namibe',          code: 'NMB', centerLat: -15.1961, centerLng:  12.1522, zoom:  8.5),
  Province(name: 'Uíge',            code: 'UIG', centerLat:  -7.6086, centerLng:  15.0614, zoom:  8.5),
  Province(name: 'Zaire',           code: 'ZAI', centerLat:  -6.2667, centerLng:  14.2333, zoom:  8.5),
];

/// Widget dropdown reutilizável para selecionar uma província.
class ProvinceDropdown extends StatelessWidget {
  final String? selectedProvince;
  final ValueChanged<String?> onChanged;

  const ProvinceDropdown({
    super.key,
    this.selectedProvince,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedProvince,
      hint: const Text('Selecione a Província'),
      icon: const Icon(Icons.arrow_drop_down),
      decoration: InputDecoration(
        hintText: 'Selecione a Província',
        prefixIcon: Icon(Icons.location_on, color: AppTheme.onSurfaceVariant),
        filled: true,
        fillColor: const Color(0xFF0E0E0E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primaryContainer, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: kProvinces.map((p) {
        return DropdownMenuItem<String>(
          value: p.name,
          child: Text(p.name, style: TextStyle(fontSize: 14)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
