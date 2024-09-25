import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'google_maps_service.dart'; // Nhập dịch vụ GoogleMapsService

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
  final GoogleMapsService _mapsService = GoogleMapsService();
  List<String> _suggestions = []; // Danh sách gợi ý
  MapType _currentMapType = MapType.normal; // Biến lưu trữ kiểu bản đồ

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(21.0285, 105.8040), // Tọa độ của Hà Nội, Việt Nam
    zoom: 14.0,
  );

  final Set<Marker> _markers = {}; // Để lưu trữ các marker

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps Search'),
        backgroundColor: Colors.deepPurple,
        actions: [
          PopupMenuButton<MapType>(
            onSelected: (MapType type) {
              setState(() {
                _currentMapType = type; // Cập nhật kiểu bản đồ hiện tại
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<MapType>>[
              const PopupMenuItem<MapType>(
                value: MapType.normal,
                child: Text('Đường phố'), // Street
              ),
              const PopupMenuItem<MapType>(
                value: MapType.terrain,
                child: Text('Địa hình'), // Terrain
              ),
              const PopupMenuItem<MapType>(
                value: MapType.hybrid,
                child: Text('Vệ tinh'), // Satellite
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
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        _getSuggestions(value);
                      } else {
                        setState(() {
                          _suggestions.clear(); // Xóa gợi ý khi ô tìm kiếm rỗng
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchLocation,
                ),
              ],
            ),
          ),
          if (_suggestions.isNotEmpty) // Hiển thị gợi ý nếu có
            SizedBox(
              height: 150, // Chiều cao của danh sách gợi ý
              child: ListView.builder(
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  return Column(
                    children: [
                      ListTile(
                        title: Text(_suggestions[index]),
                        onTap: () {
                          _searchController.text = _suggestions[index]; // Cập nhật ô tìm kiếm
                          _searchLocation(); // Tìm kiếm địa điểm
                        },
                      ),
                      if (index < _suggestions.length - 1) // Kiểm tra không phải là mục cuối cùng
                        const Divider(), // Vạch ngăn cách giữa các mục
                    ],
                  );
                },
              ),

            ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _kGooglePlex,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _markers,
              mapType: _currentMapType, // Áp dụng kiểu bản đồ đã chọn
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToMyLocation, // Cập nhật đến vị trí hiện tại
        label: const Text('My Location'),
        icon: const Icon(Icons.my_location),
      ),
    );
  }

  // Phương thức để tìm kiếm địa điểm
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

        _addMarker(target);
        setState(() {
          _suggestions.clear(); // Xóa danh sách gợi ý
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location not found: $e')),
        );
      }
    }
  }

  // Phương thức để lấy gợi ý địa điểm
  Future<void> _getSuggestions(String input) async {
    try {
      final suggestions = await _mapsService.getPlaceSuggestions(input);
      setState(() {
        _suggestions = suggestions; // Cập nhật danh sách gợi ý
      });
    } catch (e) {
      // Xử lý lỗi
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<void> _goToMyLocation() async {
    Position position = await _determinePosition();
    LatLng target = LatLng(position.latitude, position.longitude);

    final GoogleMapController controller = await _controller.future;
    // Lia camera đến vị trí hiện tại
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: target,
        zoom: 14.0,
      ),
    ));

    _addMarker(target); // Optional: Add a marker at the current location
  }

  // Phương thức để thêm marker
  void _addMarker(LatLng position) {
    _markers.add(
      Marker(
        markerId: const MarkerId('specific_location'),
        position: position,
        infoWindow: const InfoWindow(
          title: 'Specific Location',
          snippet: 'This is a specific location.',
        ),
      ),
    );

    setState(() {});
  }

  // Hàm xác định vị trí hiện tại
  Future<Position> _determinePosition() async {
    bool serviceEnabled; // Biến trạng thái dịch vụ GPS
    LocationPermission permission; // Quyền

    // Check if location services are enabled
    serviceEnabled =
        await Geolocator.isLocationServiceEnabled(); // Lấy trạng thái
    if (!serviceEnabled) {
      // Nếu dịch vụ chưa được bật thì báo lỗi
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Nếu quyền bị từ chối thì tiếp tục gửi yêu cầu
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    // When permissions are granted, return the current position
    return await Geolocator.getCurrentPosition();
  }
}
