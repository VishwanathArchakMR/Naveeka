// lib/services/offline_maps_service.dart

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'maps_service.dart' show MapBounds, WebMercator; // reuse projection/tile helpers
import '../models/coordinates.dart';

/// Supported tile formats for offline storage.
enum OfflineTileFormat { png, jpg, webp, pbf }

extension OfflineTileFormatX on OfflineTileFormat {
  String get fileExtension {
    switch (this) {
      case OfflineTileFormat.png:
        return 'png';
      case OfflineTileFormat.jpg:
        return 'jpg';
      case OfflineTileFormat.webp:
        return 'webp';
      case OfflineTileFormat.pbf:
        return 'pbf';
    }
  }

  String get contentType {
    switch (this) {
      case OfflineTileFormat.png:
        return 'image/png';
      case OfflineTileFormat.jpg:
        return 'image/jpeg';
      case OfflineTileFormat.webp:
        return 'image/webp';
      case OfflineTileFormat.pbf:
        return 'application/x-protobuf';
    }
  }
}

/// XYZ tile coordinate.
@immutable
class TileCoord {
  const TileCoord({required this.z, required this.x, required this.y});

  final int z;
  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is TileCoord && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'z$z/$x/$y';
}

/// Definition of an offline region to download.
@immutable
class OfflineRegionDefinition {
  const OfflineRegionDefinition({
    required this.id,
    required this.name,
    required this.bounds,
    required this.minZoom,
    required this.maxZoom,
    this.format = OfflineTileFormat.png,
    this.averageTileSizeBytes, // optional estimate to improve size prediction
    this.maxBytes, // optional per-region budget
    this.metadata = const <String, String>{},
  }) : assert(minZoom >= 0 && maxZoom >= minZoom);

  final String id;
  final String name;
  final MapBounds bounds;
  final int minZoom;
  final int maxZoom;
  final OfflineTileFormat format;
  final int? averageTileSizeBytes;
  final int? maxBytes;
  final Map<String, String> metadata;

  OfflineRegionDefinition copyWith({
    String? id,
    String? name,
    MapBounds? bounds,
    int? minZoom,
    int? maxZoom,
    OfflineTileFormat? format,
    int? averageTileSizeBytes,
    int? maxBytes,
    Map<String, String>? metadata,
  }) {
    return OfflineRegionDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      bounds: bounds ?? this.bounds,
      minZoom: minZoom ?? this.minZoom,
      maxZoom: maxZoom ?? this.maxZoom,
      format: format ?? this.format,
      averageTileSizeBytes: averageTileSizeBytes ?? this.averageTileSizeBytes,
      maxBytes: maxBytes ?? this.maxBytes,
      metadata: metadata ?? this.metadata,
    );
  }
}

/// Progress snapshot for a running download.
@immutable
class OfflineDownloadProgress {
  const OfflineDownloadProgress({
    required this.regionId,
    required this.totalTiles,
    required this.downloadedTiles,
    required this.totalBytes,
    required this.state,
    this.error,
  });

  final String regionId;
  final int totalTiles;
  final int downloadedTiles;
  final int totalBytes;
  final OfflineDownloadState state;
  final String? error;

  double get fraction => totalTiles == 0 ? 0.0 : (downloadedTiles / totalTiles).clamp(0.0, 1.0);

  @override
  String toString() =>
      'OfflineDownloadProgress(region=$regionId state=$state tiles=$downloadedTiles/$totalTiles bytes=$totalBytes err=$error)';
}

enum OfflineDownloadState { idle, estimating, downloading, paused, completed, failed, canceled }

/// Abstraction for tile storage backends (filesystem folders, MBTiles, custom DB).
abstract class TileStore {
  Future<void> initRegion(OfflineRegionDefinition def);

  /// Return whether a tile already exists.
  Future<bool> hasTile(String regionId, TileCoord t);

  /// Persist a tile’s bytes.
  Future<void> putTile(String regionId, TileCoord t, List<int> bytes, {String? contentType});

  /// Read a tile’s bytes (optional for verification).
  Future<List<int>?> getTile(String regionId, TileCoord t);

  /// Remove an entire region and its tiles.
  Future<void> deleteRegion(String regionId);

  /// List stored regions’ identifiers.
  Future<List<String>> listRegionIds();
}

/// Simple filesystem TileStore: stores tiles at <root>/<regionId>/<z>/<x>/<y>.<ext>
class FileTileStore implements TileStore {
  FileTileStore({required this.rootDirectoryPath});

  final String rootDirectoryPath;

  Directory get _rootDir => Directory(rootDirectoryPath);

  Future<Directory> _regionDir(String regionId) async {
    final d = Directory('${_rootDir.path}/$regionId');
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  @override
  Future<void> initRegion(OfflineRegionDefinition def) async {
    await _regionDir(def.id);
    // Optional: persist metadata.json for the region
    final metaFile = File('${_rootDir.path}/${def.id}/metadata.json');
    final meta = <String, dynamic>{
      'id': def.id,
      'name': def.name,
      'minZoom': def.minZoom,
      'maxZoom': def.maxZoom,
      'format': def.format.fileExtension,
      'bounds': def.bounds.bbox,
      'metadata': def.metadata,
    };
    await metaFile.writeAsString(const JsonEncoder.withIndent('  ').convert(meta));
  }

  @override
  Future<bool> hasTile(String regionId, TileCoord t) async {
    final dir = await _regionDir(regionId);
    final file = File('${dir.path}/${t.z}/${t.x}/${t.y}');
    // We don't know extension here; check common ones
    for (final ext in const ['png', 'jpg', 'webp', 'pbf']) {
      final f = File('${file.path}.$ext');
      if (await f.exists()) return true;
    }
    return false;
  }

  @override
  Future<void> putTile(String regionId, TileCoord t, List<int> bytes, {String? contentType}) async {
    // Choose extension from content type if provided, fallback to common by sniffing header minimally
    String ext = 'png';
    if (contentType != null) {
      if (contentType.contains('jpeg')) ext = 'jpg';
      if (contentType.contains('webp')) ext = 'webp';
      if (contentType.contains('protobuf') || contentType.contains('pbf')) ext = 'pbf';
      if (contentType.contains('png')) ext = 'png';
    }
    final dir = await _regionDir(regionId);
    final zDir = Directory('${dir.path}/${t.z}');
    if (!await zDir.exists()) await zDir.create();
    final xDir = Directory('${zDir.path}/${t.x}');
    if (!await xDir.exists()) await xDir.create();
    final f = File('${xDir.path}/${t.y}.$ext');
    await f.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> getTile(String regionId, TileCoord t) async {
    final dir = await _regionDir(regionId);
    for (final ext in const ['png', 'jpg', 'webp', 'pbf']) {
      final f = File('${dir.path}/${t.z}/${t.x}/${t.y}.$ext');
      if (await f.exists()) return f.readAsBytes();
    }
    return null;
  }

  @override
  Future<void> deleteRegion(String regionId) async {
    final dir = Directory('${_rootDir.path}/$regionId');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  @override
  Future<List<String>> listRegionIds() async {
    if (!await _rootDir.exists()) return const <String>[];
    final entries = await _rootDir.list().toList();
    return entries.whereType<Directory>().map((d) => d.uri.pathSegments.isEmpty ? '' : d.uri.pathSegments.last.replaceAll('/', '')).where((s) => s.isNotEmpty).toList(growable: false);
  }
}

/// Pluggable HTTP tile downloader abstraction.
abstract class TileDownloader {
  Future<List<int>> fetchTile({
    required String template, // e.g. https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png
    required TileCoord tile,
    List<String> subdomains = const <String>['a', 'b', 'c'],
    Map<String, String> headers = const <String, String>{},
  });
}

/// Minimal HttpClient-based downloader (no external deps).
class HttpClientTileDownloader implements TileDownloader {
  HttpClientTileDownloader({this.client});

  final HttpClient? client;

  @override
  Future<List<int>> fetchTile({
    required String template,
    required TileCoord tile,
    List<String> subdomains = const <String>['a', 'b', 'c'],
    Map<String, String> headers = const <String, String>{},
  }) async {
    String url = template
        .replaceAll('{z}', tile.z.toString())
        .replaceAll('{x}', tile.x.toString())
        .replaceAll('{y}', tile.y.toString());
    if (url.contains('{s}') && subdomains.isNotEmpty) {
      final s = subdomains[(tile.x + tile.y) % subdomains.length];
      url = url.replaceAll('{s}', s);
    }
    final c = client ?? HttpClient();
    final req = await c.getUrl(Uri.parse(url));
    headers.forEach(req.headers.add);
    final res = await req.close();
    if (res.statusCode == 200) {
      final bytes = await consolidateHttpClientResponseBytes(res);
      if (client == null) {
        c.close(force: true);
      }
      return bytes;
    }
    if (client == null) {
      c.close(force: true);
    }
    throw HttpException('Tile HTTP ${res.statusCode}', uri: Uri.parse(url));
  }
}

/// Controller for a running download task (pause/resume/cancel + progress stream).
class OfflineDownloadController {
  OfflineDownloadController._(this.regionId, this._progress);

  final String regionId;
  final StreamController<OfflineDownloadProgress> _progress;

  final _pause = ValueNotifier<bool>(false);
  final _cancel = ValueNotifier<bool>(false);

  Stream<OfflineDownloadProgress> get stream => _progress.stream;

  void pause() => _pause.value = true;
  void resume() => _pause.value = false;
  void cancel() => _cancel.value = true;

  bool get isPaused => _pause.value;
  bool get isCanceled => _cancel.value;

  void dispose() {
    _progress.close();
    _pause.dispose();
    _cancel.dispose();
  }
}

/// Core offline maps service: tile math, estimation, and downloading.
class OfflineMapsService {
  const OfflineMapsService({
    required TileStore store,
    required TileDownloader downloader,
  })  : _store = store,
        _downloader = downloader;

  final TileStore _store;
  final TileDownloader _downloader;

  /// Compute XYZ tiles for a bounds and zoom.
  List<TileCoord> tilesForBoundsZoom(MapBounds bounds, int z) {
    final sw = bounds.southWest;
    final ne = bounds.northEast;

    final tl = WebMercator.lonLatToTile(
      // top-left: lat=NE.lat, lng=SW.lng
      Coordinates(latitude: ne.latitude, longitude: sw.longitude),
      z,
    );
    final br = WebMercator.lonLatToTile(
      // bottom-right: lat=SW.lat, lng=NE.lng
      Coordinates(latitude: sw.latitude, longitude: ne.longitude),
      z,
    );

    final tiles = <TileCoord>[];
    for (int x = tl.x; x <= br.x; x++) {
      for (int y = tl.y; y <= br.y; y++) {
        tiles.add(TileCoord(z: z, x: x, y: y));
      }
    }
    return tiles;
  }

  /// Compute all tiles for a region across zoom levels.
  List<TileCoord> tilesForRegion(OfflineRegionDefinition def) {
    final all = <TileCoord>[];
    for (int z = def.minZoom; z <= def.maxZoom; z++) {
      all.addAll(tilesForBoundsZoom(def.bounds, z));
    }
    // Deduplicate in case of numeric overlaps (normally not needed)
    final set = LinkedHashSet<TileCoord>.from(all);
    return set.toList(growable: false);
  }

  /// Estimate tiles and total bytes based on an average tile size hint.
  ({int tileCount, int estimatedBytes}) estimate(OfflineRegionDefinition def) {
    final tiles = tilesForRegion(def);
    final count = tiles.length;
    final avg = (def.averageTileSizeBytes ?? _defaultAvgBytes(def.format));
    final estimated = count * avg;
    return (tileCount: count, estimatedBytes: estimated);
  }

  int _defaultAvgBytes(OfflineTileFormat f) {
    switch (f) {
      case OfflineTileFormat.png:
        return 25000; // ~25 KB
      case OfflineTileFormat.jpg:
        return 15000; // ~15 KB
      case OfflineTileFormat.webp:
        return 12000; // ~12 KB
      case OfflineTileFormat.pbf:
        return 8000; // ~8 KB vector tile (highly variable)
    }
  }

  /// Start downloading an offline region into the TileStore.
  /// - template: e.g. https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png
  /// - concurrency: number of parallel HTTP requests
  /// - skipExisting: if true, tiles already present in store won't be fetched again
  OfflineDownloadController downloadRegion({
    required OfflineRegionDefinition def,
    required String template,
    List<String> subdomains = const <String>['a', 'b', 'c'],
    Map<String, String> headers = const <String, String>{},
    int concurrency = 8,
    bool skipExisting = true,
  }) {
    final controller = StreamController<OfflineDownloadProgress>.broadcast();
    final task = OfflineDownloadController._(def.id, controller);

    () async {
      try {
        controller.add(OfflineDownloadProgress(
          regionId: def.id,
          totalTiles: 0,
          downloadedTiles: 0,
          totalBytes: 0,
          state: OfflineDownloadState.estimating,
        ));

        await _store.initRegion(def);

        final tiles = tilesForRegion(def);
        final total = tiles.length;
        int done = 0;
        int bytes = 0;

        controller.add(OfflineDownloadProgress(
          regionId: def.id,
          totalTiles: total,
          downloadedTiles: 0,
          totalBytes: 0,
          state: OfflineDownloadState.downloading,
        ));

        // Simple semaphore to bound concurrency.
        final q = <Future<void>>[];
        final it = tiles.iterator;

        Future<void> worker() async {
          while (true) {
            if (task.isCanceled) return;

            // Pause loop
            while (task.isPaused && !task.isCanceled) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
            if (task.isCanceled) return;

            // Next tile
            TileCoord? t;
            // Critical section
            if (it.moveNext()) {
              t = it.current;
            } else {
              break;
            }

            if (skipExisting && await _store.hasTile(def.id, t)) {
              done++;
              controller.add(OfflineDownloadProgress(
                regionId: def.id,
                totalTiles: total,
                downloadedTiles: done,
                totalBytes: bytes,
                state: OfflineDownloadState.downloading,
              ));
              continue;
            }

            try {
              final data = await _downloader.fetchTile(
                template: template,
                tile: t,
                subdomains: subdomains,
                headers: headers,
              );
              await _store.putTile(def.id, t, data, contentType: def.format.contentType);
              bytes += data.length;
              done++;
              controller.add(OfflineDownloadProgress(
                regionId: def.id,
                totalTiles: total,
                downloadedTiles: done,
                totalBytes: bytes,
                state: OfflineDownloadState.downloading,
              ));

              if (def.maxBytes != null && bytes > def.maxBytes!) {
                throw StateError('Region exceeded maxBytes limit (${def.maxBytes}).');
              }
            } catch (e) {
              // On error, continue but mark failure if canceled later; for strict mode, throw.
              // Here we surface the error message with current snapshot.
              controller.add(OfflineDownloadProgress(
                regionId: def.id,
                totalTiles: total,
                downloadedTiles: done,
                totalBytes: bytes,
                state: OfflineDownloadState.downloading,
                error: e.toString(),
              ));
            }
          }
        }

        for (int i = 0; i < math.max(1, concurrency); i++) {
          q.add(worker());
        }
        await Future.wait(q);

        if (task.isCanceled) {
          controller.add(OfflineDownloadProgress(
            regionId: def.id,
            totalTiles: total,
            downloadedTiles: done,
            totalBytes: bytes,
            state: OfflineDownloadState.canceled,
          ));
          return;
        }

        controller.add(OfflineDownloadProgress(
          regionId: def.id,
          totalTiles: total,
          downloadedTiles: done,
          totalBytes: bytes,
          state: done >= total ? OfflineDownloadState.completed : OfflineDownloadState.failed,
          error: done >= total ? null : 'Some tiles failed to download',
        ));
      } catch (e) {
        controller.add(OfflineDownloadProgress(
          regionId: def.id,
          totalTiles: 0,
          downloadedTiles: 0,
          totalBytes: 0,
          state: OfflineDownloadState.failed,
          error: e.toString(),
        ));
      } finally {
        await controller.close();
      }
    }();

    return task;
  }

  /// Remove a region and all its tiles.
  Future<void> deleteRegion(String regionId) => _store.deleteRegion(regionId);

  /// List stored region IDs.
  Future<List<String>> listRegions() => _store.listRegionIds();
}
