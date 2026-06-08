import 'package:flutter/services.dart';

class CohortInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final buffer = StringBuffer();
    // Only keep digits
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 4) {
        buffer.write(' - ');
      }
      buffer.write(digitsOnly[i]);
      if (i >= 7) break; // Limit to 8 digits total (YYYY - YYYY)
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class SchoolYearInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final buffer = StringBuffer();
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    for (int i = 0; i < digitsOnly.length; i++) {
      buffer.write(digitsOnly[i]);
      if (i == 3 && digitsOnly.length > 4) {
        buffer.write('-');
      }
      if (i >= 7) break;
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;

    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }

    final buffer = StringBuffer();
    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');

    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write(' - ');
      }
      buffer.write(digitsOnly[i]);
      if (i >= 7) break; // Limit to 8 digits (MMDDYYYY)
    }

    final string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
