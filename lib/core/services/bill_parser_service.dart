class ParsedBillResult {
  final double? amount;
  final String? merchant;
  final String categoryId;
  final bool isExpense;
  final bool isAtmWithdrawal;
  final String? bankName;
  final String? cardLastDigits;
  final String operationType; // 'expense', 'income', 'atm_withdrawal', 'transfer'
  final String rawText;

  ParsedBillResult({
    this.amount,
    this.merchant,
    required this.categoryId,
    required this.isExpense,
    this.isAtmWithdrawal = false,
    this.bankName,
    this.cardLastDigits,
    this.operationType = 'expense',
    required this.rawText,
  });
}

class BillParserService {
  static ParsedBillResult parse(String text) {
    final cleanText = text.trim();
    double? extractedAmount;
    String? extractedMerchant;
    String matchedCategory = 'cat_other_exp';
    bool isExpense = true;
    bool isAtmWithdrawal = false;
    String operationType = 'expense';
    String? bankName;
    String? cardLastDigits;

    final lower = cleanText.toLowerCase();

    // Detect ATM cash withdrawal
    if (cleanText.contains('سحب نقدي') ||
        cleanText.contains('سحب صراف') ||
        cleanText.contains('صراف آلي') ||
        cleanText.contains('صراف') ||
        lower.contains('atm cash') ||
        lower.contains('cash withdrawal') ||
        lower.contains('atm-w/d') ||
        lower.contains('atm withdrawal')) {
      isAtmWithdrawal = true;
      isExpense = false;
      operationType = 'atm_withdrawal';
      matchedCategory = 'cat_other_exp';
    }
    // Detect if income/deposit
    else if (cleanText.contains('إيداع') ||
        cleanText.contains('حوالة واردة') ||
        cleanText.contains('راتب') ||
        cleanText.contains('اضافة رصيد') ||
        cleanText.contains('إضافة رصيد') ||
        lower.contains('deposit') ||
        lower.contains('salary') ||
        lower.contains('credit') ||
        lower.contains('received')) {
      isExpense = false;
      operationType = 'income';
      matchedCategory = 'cat_salary';
    }

    // Amount extraction regex
    final amountRegex1 = RegExp(
      r'(?:مبلغ|بقيمة|بمبلغ|شراء|خصم|سحب|إيداع|SAR|EGP|USD|ر\.س|ج\.م|\$)\s*:?\s*([\d,]+(?:\.\d{1,2})?)',
      caseSensitive: false,
    );
    final amountRegex2 = RegExp(
      r'([\d,]+(?:\.\d{1,2})?)\s*(?:SAR|EGP|USD|ر\.س|ج\.م|\$)',
      caseSensitive: false,
    );
    final generalNumberRegex = RegExp(r'(\d+(?:\.\d{1,2})?)');

    final match1 = amountRegex1.firstMatch(cleanText);
    final match2 = amountRegex2.firstMatch(cleanText);

    if (match1 != null) {
      final numStr = match1.group(1)?.replaceAll(',', '');
      extractedAmount = double.tryParse(numStr ?? '');
    } else if (match2 != null) {
      final numStr = match2.group(1)?.replaceAll(',', '');
      extractedAmount = double.tryParse(numStr ?? '');
    } else {
      final match3 = generalNumberRegex.firstMatch(cleanText);
      if (match3 != null) {
        extractedAmount = double.tryParse(match3.group(1) ?? '');
      }
    }

    // Card digits extraction
    final cardRegex = RegExp(
      r'(?:بطاقة|مدى|فيزا|ماستركارد|حساب|card)\D{0,15}(\d{4})',
      caseSensitive: false,
    );
    final cardMatch = cardRegex.firstMatch(cleanText);
    if (cardMatch != null) {
      cardLastDigits = cardMatch.group(1);
    }

    // Bank identification
    if (cleanText.contains('الراجحي') || lower.contains('rajhi')) {
      bankName = 'مصرف الراجحي';
    } else if (cleanText.contains('الأهلي') || lower.contains('snb') || lower.contains('alahli')) {
      bankName = 'البنك الأهلي SNB';
    } else if (cleanText.contains('الإنماء') || lower.contains('inma')) {
      bankName = 'مصرف الإنماء';
    } else if (cleanText.contains('الرياض') || lower.contains('riyad')) {
      bankName = 'بنك الرياض';
    } else if (cleanText.contains('البلاد') || lower.contains('bilad')) {
      bankName = 'بنك البلاد';
    } else if (cleanText.contains('الجزيرة') || lower.contains('jazira')) {
      bankName = 'بنك الجزيرة';
    } else if (cleanText.contains('stc pay') || cleanText.contains('stcpay') || cleanText.contains('اس تي سي')) {
      bankName = 'STC Pay';
    } else if (lower.contains('urpay')) {
      bankName = 'UrPay';
    } else if (cleanText.contains('مصر') || lower.contains('banque misr')) {
      bankName = 'بنك مصر';
    }

    // Merchant / Place Extraction
    final merchantRegex = RegExp(
      r'(?:لدى|من|في|متجر|شركة|إلى|عند)\s+([^\n,.\d]{2,30})',
      caseSensitive: false,
    );
    final merchantMatch = merchantRegex.firstMatch(cleanText);
    if (merchantMatch != null) {
      extractedMerchant = merchantMatch.group(1)?.trim();
    }

    // Category deduction by keywords
    if (isAtmWithdrawal) {
      extractedMerchant = extractedMerchant ?? 'سحب نقدي صراف آلي';
    } else if (isExpense) {
      if (cleanText.contains('سوبرماركت') ||
          cleanText.contains('تموين') ||
          cleanText.contains('بنده') ||
          cleanText.contains('العثيم') ||
          cleanText.contains('مطعم') ||
          cleanText.contains('كافيه') ||
          cleanText.contains('ماكدونالدز') ||
          cleanText.contains('بيك') ||
          lower.contains('restaurant') ||
          lower.contains('cafe') ||
          lower.contains('market') ||
          lower.contains('coffee')) {
        matchedCategory = 'cat_food';
      } else if (cleanText.contains('محطة') ||
          cleanText.contains('ساسكو') ||
          cleanText.contains('وقود') ||
          cleanText.contains('بنزين') ||
          cleanText.contains('اوبر') ||
          cleanText.contains('أوبر') ||
          cleanText.contains('كريم') ||
          lower.contains('uber') ||
          lower.contains('careem') ||
          lower.contains('fuel') ||
          lower.contains('gas')) {
        matchedCategory = 'cat_transport';
      } else if (cleanText.contains('كهرباء') ||
          cleanText.contains('مياه') ||
          cleanText.contains('اتصالات') ||
          cleanText.contains('stc') ||
          cleanText.contains('موبايلي') ||
          cleanText.contains('زين') ||
          cleanText.contains('فاتورة') ||
          lower.contains('bill') ||
          lower.contains('telecom')) {
        matchedCategory = 'cat_bills';
      } else if (cleanText.contains('صيدلية') ||
          cleanText.contains('مستشفى') ||
          cleanText.contains('نهدي') ||
          cleanText.contains('دواء') ||
          cleanText.contains('عيادة') ||
          lower.contains('pharmacy') ||
          lower.contains('hospital') ||
          lower.contains('medical')) {
        matchedCategory = 'cat_health';
      } else if (cleanText.contains('أمازون') ||
          cleanText.contains('نون') ||
          cleanText.contains('شراء') ||
          cleanText.contains('تسوق') ||
          cleanText.contains('مول') ||
          lower.contains('amazon') ||
          lower.contains('noon') ||
          lower.contains('shopping')) {
        matchedCategory = 'cat_shopping';
      }
    }

    return ParsedBillResult(
      amount: extractedAmount,
      merchant: extractedMerchant ??
          (isAtmWithdrawal
              ? 'سحب نقدي صراف'
              : (isExpense ? 'مشتريات بنكية' : 'إيداع مالي')),
      categoryId: matchedCategory,
      isExpense: isExpense,
      isAtmWithdrawal: isAtmWithdrawal,
      bankName: bankName,
      cardLastDigits: cardLastDigits,
      operationType: operationType,
      rawText: cleanText,
    );
  }
}
