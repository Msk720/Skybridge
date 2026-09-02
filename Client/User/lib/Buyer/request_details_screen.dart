import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skybridge02/Services/open_link.dart';

class RequestDetailsScreen extends StatefulWidget {
  static const routeName = '/requestDetails';
  const RequestDetailsScreen({super.key});

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  Map<String, dynamic>? request;
  Map<String, dynamic>? productDetails;
  bool loading = true;
  int currentIndex = 0;
  final PageController _pageController = PageController(viewportFraction: 0.95);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Expecting arguments: { 'request': { ... } }
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    request =
        args != null ? Map<String, dynamic>.from(args['request'] ?? {}) : null;
    _fetchProductDetails();
  }

  Future<void> _fetchProductDetails() async {
    if (request == null || request!['id'] == null) {
      setState(() {
        productDetails = request;
        loading = false;
      });
      return;
    }

    setState(() => loading = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('shoppingRequests')
          .doc(request!['id']);
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data()!;
        setState(() {
          productDetails = {...data, 'id': snap.id};
        });
      } else {
        // If doc missing, fallback to passed request info
        setState(() {
          productDetails = request;
        });
      }
    } catch (e, st) {
      // ignore errors but log
      debugPrint('Error fetching product details: $e\n$st');
      setState(() {
        productDetails = request;
      });
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _handleRemove() async {
    if (productDetails == null || productDetails!['id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Request id missing')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('shoppingRequests')
          .doc(productDetails!['id'])
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request deleted successfully')),
      );
      // navigate back to dashboard — change route name as per your app
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      debugPrint('Error deleting request: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  void _handleEdit() {
    if (productDetails == null) return;
    // navigate to EditRequest screen, pass request object (adjust route name if different)
    Navigator.pushNamed(
      context,
      '/editRequest',
      arguments: {'request': productDetails},
    );
  }

  Widget _buildDots(List<dynamic> images) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(images.length, (i) {
        final active = i == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: active ? 12 : 8,
          height: active ? 12 : 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFED6C30) : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final display = productDetails ?? request ?? {};
    final images = List<String>.from(
      (display['images'] ??
              display['imagesList'] ??
              display['pictures'] ??
              display['images'] ??
              []) as List? ??
          [],
    );
    final name = display['name'] ?? display['title'] ?? 'Product';
    final status = display['status'] ?? display['stat'] ?? 'Unknown';

    // compute price fields defensively
    double parseDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    final price = parseDouble(display['price']);
    final qty = parseDouble(display['quantity'] ?? display['qty'] ?? 1);
    final travelerReward = parseDouble(
      display['travelerReward'] ?? display['traveler_reward'],
    );
    final totalPrice = display['totalPrice'] ?? (price * qty + travelerReward);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 237, 233, 233),
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: const Color(0xFFED6C30),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProductDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Status: $status',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Image carousel (PageView)
              if (images.isNotEmpty)
                SizedBox(
                  height: 300,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          onPageChanged: (i) =>
                              setState(() => currentIndex = i),
                          itemBuilder: (_, idx) {
                            final img = images[idx];
                            return Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  img,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  loadingBuilder: (ctx, child, prog) {
                                    if (prog == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 64,
                                        color: Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDots(images),
                    ],
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, size: 64, color: Colors.grey),
                  ),
                ),

              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              if (loading)
                const Center(child: CircularProgressIndicator())
              else ...[
                Text(
                  'Product Details:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Category: ${productDetails?['category'] ?? 'N/A'}'),
                const SizedBox(height: 4),
                Text(
                  'From: ${productDetails?['fromCountry'] ?? ''}, ${productDetails?['fromCity'] ?? ''}',
                ),
                const SizedBox(height: 4),
                Text(
                  'To: ${productDetails?['toCountry'] ?? ''}, ${productDetails?['toCity'] ?? ''}',
                ),
                const SizedBox(height: 4),
                Text('Needed by: ${productDetails?['date'] ?? ''}'),
                const SizedBox(height: 10),
                Text(
                  'Price Details:',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Price of Product: \$${price.toStringAsFixed(2)}'),
                Text('Quantity: ${qty.toStringAsFixed(0)}'),
                Text(
                  'Total Product Price: \$${(price * qty).toStringAsFixed(2)}',
                ),
                Text('Traveler Reward: \$${travelerReward.toStringAsFixed(2)}'),
                Text(
                  'Total: \$${(totalPrice is num ? (totalPrice).toString() : totalPrice.toString())}',
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    final url = productDetails?['link'] ?? request?['link'];
                    openLink(context, url?.toString());
                  },
                  child: Text(
                    'Go to website',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Edit / Remove buttons when status == Requested
              if ((productDetails?['status'] ??
                      productDetails?['stat'] ??
                      request?['status']) ==
                  'Requested') ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFED6C30),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _handleRemove,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                        ),
                        child: const Text('Remove'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Trip requests header
              if ((productDetails?['trips'] ?? request?['trips']) != null) ...[
                Text(
                  'Trip Requests:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildTripCards(
                  List.from(
                    productDetails?['trips'] ?? request?['trips'] ?? [],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTripCards(List<dynamic> trips) {
    if (trips.isEmpty) {
      return [const Text('No trip requests found')];
    }
    return trips.map((t) {
      // Determine when to show card per your RN logic:
      // isShowCard = (request.status != "Requested" && trip.status === "accepted") || request.status === 'Requested'
      final reqStatus = productDetails?['status'] ?? request?['status'] ?? '';
      final tripStatus = t['status'] ?? t['stat'] ?? '';
      final isShow = (reqStatus != 'Requested' && tripStatus == 'accepted') ||
          reqStatus == 'Requested';
      if (!isShow) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TripSearchCard(cardDetails: Map<String, dynamic>.from(t)),
      );
    }).toList();
  }
}

/// Simple placeholder for TripSearchCard — replace with your project widget
class TripSearchCard extends StatelessWidget {
  final Map<String, dynamic> cardDetails;
  const TripSearchCard({super.key, required this.cardDetails});

  @override
  Widget build(BuildContext context) {
    final from = cardDetails['fromLocation'] ?? cardDetails['from'] ?? '';
    final to = cardDetails['toLocation'] ?? cardDetails['to'] ?? '';
    final name =
        '${cardDetails['firstName'] ?? ''} ${cardDetails['lastName'] ?? ''}'
            .trim();
    final status = cardDetails['status'] ?? cardDetails['stat'] ?? '';
    final weight = cardDetails['availableWeight'] ?? '';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        title: Text('$from → $to'),
        subtitle: Text(
          'By: ${name.isEmpty ? (cardDetails['userId'] ?? '') : name}\nWeight: $weight',
        ),
        trailing: Text(status),
      ),
    );
  }
}
