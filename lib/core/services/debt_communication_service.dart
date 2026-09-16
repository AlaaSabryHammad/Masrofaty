import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_helper.dart';
import '../../models/debt_model.dart';

class DebtCommunicationService {
  static String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static String generateReminderText(DebtModel debt, String currency) {
    final remainingStr = CurrencyFormatter.format(debt.remainingAmount, symbol: currency);
    final dueStr = debt.dueDate != null ? DateHelper.formatDate(debt.dueDate!) : 'قريباً';

    if (debt.isLent) {
      return '''السلام عليكم ورحمة الله وبركاته،
أخي الكريم ${debt.personName}، أرجو أن تكون بأفضل حال.
تذكير ودي بخصوص السلفة المالية المتبقية:
• المبلغ المتبقي: $remainingStr
• موعد الاستحقاق: $dueStr
شاكراً ومقدراً لتعاونكم الكريم.''';
    } else {
      return '''السلام عليكم ورحمة الله وبركاته،
أخي الكريم ${debt.personName}، أرجو أن تكون بأفضل حال.
إشعار متابعة بخصوص الدين المستحق لكم:
• المبلغ المتبقي: $remainingStr
• موعد السداد المحدد: $dueStr
أفيدكم بأنه سيتم السداد في الموعد المحدد بإذن الله.''';
    }
  }

  static String generateStatement(DebtModel debt, String currency) {
    final buffer = StringBuffer();
    buffer.writeln('════════════════════════════════');
    buffer.writeln('📋 سند كشف حساب مالي - تطبيق مصروفاتي');
    buffer.writeln('════════════════════════════════');
    buffer.writeln('• الطرف المعني: ${debt.personName}');
    if (debt.phone != null && debt.phone!.isNotEmpty) {
      buffer.writeln('• رقم التواصل: ${debt.phone}');
    }
    buffer.writeln('• نوع المعاملة: ${debt.isLent ? "سلفة مستحقة (أموال لك)" : "دين مالي (التزام عليك)"}');
    buffer.writeln('• تاريخ الإنشاء: ${DateHelper.formatDate(debt.createdDate)}');
    if (debt.dueDate != null) {
      buffer.writeln('• موعد الاستحقاق: ${DateHelper.formatDate(debt.dueDate!)} (${DateHelper.getRelativeDueStatus(debt.dueDate)})');
    }
    buffer.writeln('────────────────────────────────');
    buffer.writeln('💰 إجمالي المبلغ: ${CurrencyFormatter.format(debt.totalAmount, symbol: currency)}');
    buffer.writeln('✅ إجمالي المسدد: ${CurrencyFormatter.format(debt.paidAmount, symbol: currency)} (${(debt.progress * 100).toInt()}%)');
    buffer.writeln('⏳ المبلغ المتبقي: ${CurrencyFormatter.format(debt.remainingAmount, symbol: currency)}');
    buffer.writeln('📊 الحالة: ${debt.isSettled ? "مسدد بالكامل" : (debt.isOverdue ? "متأخر" : "نشط")}');
    buffer.writeln('────────────────────────────────');

    if (debt.payments.isNotEmpty) {
      buffer.writeln('📑 سجل الدفعات المسددة:');
      for (int i = 0; i < debt.payments.length; i++) {
        final p = debt.payments[i];
        final note = p.notes != null && p.notes!.isNotEmpty ? ' - ${p.notes}' : '';
        buffer.writeln('${i + 1}. ${CurrencyFormatter.format(p.amount, symbol: currency)} بتاريخ ${DateHelper.formatShort(p.date)}$note');
      }
      buffer.writeln('────────────────────────────────');
    }

    if (debt.notes != null && debt.notes!.isNotEmpty) {
      buffer.writeln('📝 ملاحظات: ${debt.notes}');
      buffer.writeln('────────────────────────────────');
    }

    buffer.writeln('تم الإصدار عبر تطبيق مصروفاتي');
    return buffer.toString();
  }

  static Future<bool> sendWhatsAppReminder(DebtModel debt, String currency) async {
    final text = generateReminderText(debt, currency);
    final encodedText = Uri.encodeComponent(text);

    Uri uri;
    if (debt.phone != null && debt.phone!.trim().isNotEmpty) {
      final phone = _cleanPhone(debt.phone!);
      uri = Uri.parse('https://wa.me/$phone?text=$encodedText');
    } else {
      uri = Uri.parse('https://api.whatsapp.com/send?text=$encodedText');
    }

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Future<bool> makePhoneCall(String phone) async {
    final clean = _cleanPhone(phone);
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }

  static Future<void> copyStatementToClipboard(DebtModel debt, String currency) async {
    final statement = generateStatement(debt, currency);
    await Clipboard.setData(ClipboardData(text: statement));
  }
}
