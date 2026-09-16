import 'package:uuid/uuid.dart';
import '../../models/app_notification.dart';
import '../../models/debt_model.dart';
import '../../models/category_model.dart';

class NotificationService {
  static final Uuid _uuid = const Uuid();

  static List<AppNotification> checkDebtAlerts(List<DebtModel> debts) {
    final List<AppNotification> alerts = [];
    final now = DateTime.now();

    for (final debt in debts) {
      if (debt.isSettled || debt.dueDate == null) continue;

      final diffDays = debt.dueDate!.difference(now).inDays;

      if (debt.isOverdue) {
        alerts.add(AppNotification(
          id: _uuid.v4(),
          title: debt.isBorrowed ? 'تنبيه دين متأخر سداده!' : 'تنبيه سلفة متأخرة!',
          message: debt.isBorrowed
              ? 'تجاوز موعد سداد دين "${debt.personName}" بمبلغ ${debt.remainingAmount.toStringAsFixed(0)}'
              : 'تجاوز موعد استرداد سلفة "${debt.personName}" بمبلغ ${debt.remainingAmount.toStringAsFixed(0)}',
          date: now,
          type: 'debt',
        ));
      } else if (debt.isDueToday) {
        alerts.add(AppNotification(
          id: _uuid.v4(),
          title: debt.isBorrowed ? 'موعد سداد دين اليوم!' : 'موعد استحقاق سلفة اليوم!',
          message: debt.isBorrowed
              ? 'اليوم هو موعد سداد دين "${debt.personName}" بمبلغ ${debt.remainingAmount.toStringAsFixed(0)}'
              : 'اليوم موعد استحقاق استرداد سلفة "${debt.personName}" بمبلغ ${debt.remainingAmount.toStringAsFixed(0)}',
          date: now,
          type: 'debt',
        ));
      } else if (diffDays >= 0 && diffDays <= 2) {
        alerts.add(AppNotification(
          id: _uuid.v4(),
          title: debt.isBorrowed ? 'اقتراب موعد سداد دين' : 'اقتراب موعد استحقاق سلفة',
          message: 'متبقي $diffDays أيام لسداد التزام "${debt.personName}"',
          date: now,
          type: 'debt',
        ));
      }
    }

    return alerts;
  }

  static AppNotification? checkBudgetThreshold(CategoryModel category, double spentAmount) {
    if (category.budgetLimit <= 0) return null;

    final ratio = spentAmount / category.budgetLimit;
    if (ratio >= 1.0) {
      return AppNotification(
        id: _uuid.v4(),
        title: 'تجاوزت الميزانية المحددة!',
        message: 'لقد تجاوزت ميزانية تصنيف "${category.name}" بنسبة ${(ratio * 100).toInt()}%',
        date: DateTime.now(),
        type: 'budget',
      );
    } else if (ratio >= 0.85) {
      return AppNotification(
        id: _uuid.v4(),
        title: 'تنبيه اقتراب حد الميزانية!',
        message: 'استهلكت ${(ratio * 100).toInt()}% من ميزانية تصنيف "${category.name}"',
        date: DateTime.now(),
        type: 'budget',
      );
    }
    return null;
  }
}
