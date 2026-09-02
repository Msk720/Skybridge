import 'package:skybridge02/Services/app_imports.dart';

Widget appAssetImage(
  String? path, {
  double width = double.infinity,
  double height = 100,
  BoxFit fit = BoxFit.cover,
  BorderRadius? radius,
}) {
  final isNetwork = path != null &&
      (path.startsWith('http://') || path.startsWith('https://'));

  final image = (path == null || path.isEmpty)
      ? const Icon(Icons.image, color: Colors.grey)
      : isNetwork
          ? Image.network(path, width: width, height: height, fit: fit)
          : Image.asset(path, width: width, height: height, fit: fit);

  return ClipRRect(
    borderRadius: radius ?? BorderRadius.circular(8),
    child: image,
  );
}
