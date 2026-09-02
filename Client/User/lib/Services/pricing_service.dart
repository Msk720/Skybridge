import 'dart:math';

class PricingService {
  static const double baseFee = 1.5;
  static const double perKgRate = 1.2;

  static const double extraItemFee = 0.5;
  static const double minReward = 3.0;

  static Map<String, double> calculate({
    required double price,
    required int quantity,
    required double weight,
    required String fromCountry,
    required String toCountry,
    required String preference,
  }) {
    final qty = max(1, quantity);
    final itemTotal = price * qty;
    final weightTotal = weight * qty;

    final distanceCost = (fromCountry == toCountry) ? 1 : 5;

    final weightCost = weightTotal * perKgRate;
    final valueCost = itemTotal * 0.05;
    final itemBonus = (qty - 1) * extraItemFee;

    double reward = baseFee + distanceCost + weightCost + valueCost + itemBonus;

    if (preference.toLowerCase() == 'risky') {
      double riskFactor;

      if (itemTotal <= 50) {
        riskFactor = 1.1;
      } else if (itemTotal <= 200) {
        riskFactor = 1.2;
      } else if (itemTotal <= 500) {
        riskFactor = 1.3;
      } else {
        riskFactor = 1.4;
      }

      reward *= riskFactor;
    }

    double maxRewardPercent;
    if (itemTotal <= 50) {
      maxRewardPercent = 0.2;
    } else if (itemTotal <= 200) {
      maxRewardPercent = 0.3;
    } else if (itemTotal <= 500) {
      maxRewardPercent = 0.4;
    } else {
      maxRewardPercent = 0.5;
    }

    reward = max(reward, minReward);
    reward = min(reward, itemTotal * maxRewardPercent);

    final finalReward = reward.ceilToDouble();
    final total = itemTotal + finalReward;
    double round2(double val) => double.parse(val.toStringAsFixed(2));

    return {
      "itemPrice": round2(itemTotal),
      "travelerReward": finalReward,
      "totalPrice": round2(total),
    };
  }
}
