import '../../../core/network/api_client.dart';
import '../models/donation_history.dart';

class DonationHistoryRepository {
  DonationHistoryRepository(this.client);

  final ApiClient client;

  Future<List<DonationRecord>> mine() async {
    final result = await client.getMyDonations();
    return result.map(DonationRecord.fromJson).toList(growable: false);
  }

  Future<DonationRecord> findMine(String id) async {
    return DonationRecord.fromJson(await client.getMyDonation(id));
  }

  Future<DonationReceipt> issueReceipt(String id, String languageCode) async {
    return DonationReceipt.fromJson(await client.issueMyDonationReceipt(
      id,
      languageCode: languageCode,
    ));
  }
}
