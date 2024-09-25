import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart'; // Import Geolocator

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Google Maps',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MapSample(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();

  // set vị trí hiện tại khi mới vào app
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(21.0285, 105.8040), // Tọa độ của Hà Nội, Việt Nam
    zoom: 14.0,
  );

  final Set<Marker> _markers = {}; // set nơi lưu dữ liệu của địa chỉ tìm được
  final Set<Circle> _circles = {}; // set nơi lưu dữ liệu địa chỉ cần bọc hình tròn
  MapType _currentMapType = MapType.normal; // Kiểu bản đồ hiện tại
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Search'),
        backgroundColor: Colors.deepPurple,
        actions: [
          // Nút chọn kiểu bản đồ
          PopupMenuButton<MapType>(
            onSelected: (MapType type) {
              setState(() {
                _currentMapType = type; // Cập nhật kiểu bản đồ
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
              const PopupMenuItem<MapType>(
                value: MapType.normal,
                child: Text('Đường phố'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.terrain,
                child: Text('Địa hình'),
              ),
              const PopupMenuItem<MapType>(
                value: MapType.hybrid,
                child: Text('Vệ tinh'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Enter location',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchLocation,
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              mapType: _currentMapType,
              // Sử dụng kiểu bản đồ hiện tại
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _markers,
              circles: _circles,
              minMaxZoomPreference: const MinMaxZoomPreference(5, 20),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToMyLocation, // Update to my location
        label: const Text('My Location'),
        icon: const Icon(Icons.my_location),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    Position position = await _determinePosition();
    LatLng target = LatLng(position.latitude, position.longitude);

    final GoogleMapController controller = await _controller.future;
    // lia camera đến vị trí hiện tại
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: target,
        zoom: 14.0,
      ),
    ));

    _addMarker(target); // Optional: Add a marker at the current location
  }

  //tìm kiếm
  Future<void> _searchLocation() async {
    String location = _searchController.text;

    try {
      List<Location> locations = await locationFromAddress(location);
      if (locations.isNotEmpty) {
        Location result = locations.first;
        LatLng target = LatLng(result.latitude, result.longitude);

        final GoogleMapController controller = await _controller.future;
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 14.0,
          ),
        ));

        if (location.contains("quận") ||
            location.contains("huyện") ||
            location.contains("phường")) {
          _drawCircle(target);
        } else {
          _addMarker(target);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not found: $e')),
        );
      }
    }
  }

  // gán icon vị trí cho nơi được tìm kiếm
  void _addMarker(LatLng position) {
    _markers.add(
      Marker(
        markerId: const MarkerId('specific_location'),
        position: position,
        infoWindow: const InfoWindow(
          title: 'Specific Location',
          snippet: 'This is a specific location.',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    setState(() {});
  }

  // vẽ khung bao bọc khu vực được tìm kiếm
  void _drawCircle(LatLng position) {
    _circles.add(
      Circle(
        circleId: const CircleId('custom_circle'),
        center: position,
        radius: 500,
        fillColor: Colors.blue.withOpacity(0.3),
        strokeColor: Colors.blue,
        strokeWidth: 2,
      ),
    );

    setState(() {});
  }

  // hàm xác định vị trí hiện tại
  Future<Position> _determinePosition() async {
    bool serviceEnabled; // biến trạng thái dịch vụ gps
    LocationPermission permission; // quyền

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled(); // lấy trạng thái
    if (!serviceEnabled) {
      // nếu dịch vụ chưa đc bật thì báo lỗi
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // nếu quyền bị từ chối thì tiếp tục gửi yêu cầu
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // nếu quyền tiếp tục bị từ chối thì báo lỗi
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // nếu quyền bị từ chối vĩnh viễn thì ko làm gì và lập tức báo lỗi
      return Future.error('Location permissions are permanently denied.');
    }

    // When permissions are granted, return the current position
    return await Geolocator.getCurrentPosition();
    // trả về thông tin vị trí
  }

}
