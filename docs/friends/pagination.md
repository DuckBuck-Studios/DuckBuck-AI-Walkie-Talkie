# Pagination Guide

This document explains how to effectively work with paginated results in the Relationship Service.

## Overview

The Relationship Service uses pagination for list operations to efficiently handle large datasets. Pagination is implemented through the `PaginatedRelationshipResult` class which provides both data and metadata about the pagination state.

## Paginated Methods

The following methods support pagination:

- `getFriends()`
- `getIncomingRequests()`
- `getOutgoingRequests()`
- `getBlockedUsers()`

## PaginatedRelationshipResult Structure

```dart
class PaginatedRelationshipResult {
  final List<RelationshipModel> relationships;  // Current page data
  final List<CachedProfile> profiles;           // Associated user profiles
  final int totalCount;                         // Total items across all pages
  final int currentPage;                        // Current page number (1-based)
  final int pageSize;                          // Items per page
  final bool hasNextPage;                      // More pages available
  final bool hasPreviousPage;                  // Previous pages available
}
```

## Basic Pagination Usage

### Simple Page Loading

```dart
Future<void> loadFriendsPage(int page) async {
  try {
    final result = await relationshipService.getFriends(
      page: page,
      pageSize: 20,
    );
    
    print('Loaded ${result.relationships.length} friends');
    print('Page ${result.currentPage} of ${_calculateTotalPages(result)}');
    print('Total friends: ${result.totalCount}');
    
    // Process the data
    for (final relationship in result.relationships) {
      final profile = result.profiles.firstWhere(
        (p) => p.id == relationship.friendId,
      );
      print('Friend: ${profile.displayName}');
    }
    
  } on RelationshipException catch (e) {
    print('Failed to load friends: ${e.message}');
  }
}

int _calculateTotalPages(PaginatedRelationshipResult result) {
  return (result.totalCount / result.pageSize).ceil();
}
```

### Load All Pages

```dart
Future<List<RelationshipModel>> loadAllFriends() async {
  final allFriends = <RelationshipModel>[];
  int currentPage = 1;
  bool hasMore = true;
  
  while (hasMore) {
    try {
      final result = await relationshipService.getFriends(
        page: currentPage,
        pageSize: 50, // Larger page size for efficiency
      );
      
      allFriends.addAll(result.relationships);
      
      hasMore = result.hasNextPage;
      currentPage++;
      
      // Optional: Add delay to avoid overwhelming the server
      if (hasMore) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      
    } on RelationshipException catch (e) {
      print('Failed to load page $currentPage: ${e.message}');
      break;
    }
  }
  
  return allFriends;
}
```

## Advanced Pagination Patterns

### Infinite Scroll Implementation

```dart
class InfiniteScrollFriendsList extends StatefulWidget {
  @override
  _InfiniteScrollFriendsListState createState() => _InfiniteScrollFriendsListState();
}

class _InfiniteScrollFriendsListState extends State<InfiniteScrollFriendsList> {
  final RelationshipService _relationshipService = GetIt.instance();
  final ScrollController _scrollController = ScrollController();
  
  List<RelationshipModel> _friends = [];
  Map<String, CachedProfile> _profiles = {};
  
  bool _loading = false;
  bool _hasMorePages = true;
  int _currentPage = 0;
  String? _error;
  
  static const int _pageSize = 20;
  
  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadNextPage();
    }
  }
  
  Future<void> _loadNextPage() async {
    if (_loading || !_hasMorePages) return;
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    try {
      final result = await _relationshipService.getFriends(
        page: _currentPage + 1,
        pageSize: _pageSize,
      );
      
      setState(() {
        _friends.addAll(result.relationships);
        
        // Update profiles map
        for (final profile in result.profiles) {
          _profiles[profile.id] = profile;
        }
        
        _currentPage = result.currentPage;
        _hasMorePages = result.hasNextPage;
        _loading = false;
      });
      
    } on RelationshipException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }
  
  Future<void> _refresh() async {
    setState(() {
      _friends.clear();
      _profiles.clear();
      _currentPage = 0;
      _hasMorePages = true;
      _error = null;
    });
    
    await _loadNextPage();
  }
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _friends.length + (_hasMorePages || _loading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _friends.length) {
            if (_error != null) {
              return _buildErrorWidget();
            }
            return _buildLoadingWidget();
          }
          
          final relationship = _friends[index];
          final profile = _profiles[relationship.friendId];
          
          return _buildFriendTile(relationship, profile);
        },
      ),
    );
  }
  
  Widget _buildLoadingWidget() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
  
  Widget _buildErrorWidget() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Failed to load more friends',
            style: TextStyle(color: Colors.red),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadNextPage,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}
```

### Cursor-Based Pagination (Alternative Implementation)

```dart
class CursorPaginatedFriendsList {
  final RelationshipService _relationshipService;
  
  List<RelationshipModel> _friends = [];
  String? _nextCursor;
  bool _hasMore = true;
  
  CursorPaginatedFriendsList(this._relationshipService);
  
  Future<void> loadNextPage() async {
    if (!_hasMore) return;
    
    try {
      // Note: This assumes the API supports cursor-based pagination
      // You may need to modify the service to support cursors
      final result = await _relationshipService.getFriendsWithCursor(
        cursor: _nextCursor,
        limit: 20,
      );
      
      _friends.addAll(result.relationships);
      _nextCursor = result.nextCursor;
      _hasMore = result.hasMore;
      
    } on RelationshipException catch (e) {
      print('Failed to load friends: ${e.message}');
      rethrow;
    }
  }
  
  void reset() {
    _friends.clear();
    _nextCursor = null;
    _hasMore = true;
  }
}
```

### Bidirectional Pagination

```dart
class BidirectionalPaginationController {
  final RelationshipService _relationshipService;
  
  List<RelationshipModel> _friends = [];
  Map<String, CachedProfile> _profiles = {};
  
  int _currentPage = 1;
  int _totalPages = 0;
  int _pageSize = 20;
  
  BidirectionalPaginationController(this._relationshipService);
  
  Future<void> goToPage(int page) async {
    if (page < 1) return;
    
    try {
      final result = await _relationshipService.getFriends(
        page: page,
        pageSize: _pageSize,
      );
      
      _friends = result.relationships;
      _profiles.clear();
      
      for (final profile in result.profiles) {
        _profiles[profile.id] = profile;
      }
      
      _currentPage = result.currentPage;
      _totalPages = (result.totalCount / result.pageSize).ceil();
      
    } on RelationshipException catch (e) {
      print('Failed to load page $page: ${e.message}');
      rethrow;
    }
  }
  
  Future<void> nextPage() async {
    if (hasNextPage) {
      await goToPage(_currentPage + 1);
    }
  }
  
  Future<void> previousPage() async {
    if (hasPreviousPage) {
      await goToPage(_currentPage - 1);
    }
  }
  
  Future<void> firstPage() async {
    await goToPage(1);
  }
  
  Future<void> lastPage() async {
    if (_totalPages > 0) {
      await goToPage(_totalPages);
    }
  }
  
  bool get hasNextPage => _currentPage < _totalPages;
  bool get hasPreviousPage => _currentPage > 1;
  
  String get pageInfo => '$_currentPage of $_totalPages';
  
  List<int> get availablePages {
    if (_totalPages <= 7) {
      return List.generate(_totalPages, (i) => i + 1);
    }
    
    // Show first page, current page ± 2, and last page
    final pages = <int>{};
    
    pages.add(1);
    
    for (int i = _currentPage - 2; i <= _currentPage + 2; i++) {
      if (i >= 1 && i <= _totalPages) {
        pages.add(i);
      }
    }
    
    pages.add(_totalPages);
    
    return pages.toList()..sort();
  }
}
```

## Performance Optimization

### Caching Strategy

```dart
class CachedPaginationService {
  final RelationshipService _relationshipService;
  final Map<String, PaginatedRelationshipResult> _cache = {};
  final Duration _cacheExpiry = Duration(minutes: 5);
  
  CachedPaginationService(this._relationshipService);
  
  Future<PaginatedRelationshipResult> getFriends({
    int page = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'friends_${page}_$pageSize';
    
    // Check cache first
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      final age = DateTime.now().difference(cached.cachedAt);
      
      if (age < _cacheExpiry) {
        return cached;
      }
    }
    
    // Fetch from service
    final result = await _relationshipService.getFriends(
      page: page,
      pageSize: pageSize,
    );
    
    // Add timestamp and cache
    final cachedResult = CachedPaginatedResult(
      relationships: result.relationships,
      profiles: result.profiles,
      totalCount: result.totalCount,
      currentPage: result.currentPage,
      pageSize: result.pageSize,
      hasNextPage: result.hasNextPage,
      hasPreviousPage: result.hasPreviousPage,
      cachedAt: DateTime.now(),
    );
    
    _cache[cacheKey] = cachedResult;
    
    // Clean up old cache entries
    _cleanupCache();
    
    return cachedResult;
  }
  
  void invalidateCache() {
    _cache.clear();
  }
  
  void _cleanupCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, value) {
      final age = now.difference(value.cachedAt);
      return age > _cacheExpiry;
    });
  }
}

class CachedPaginatedResult extends PaginatedRelationshipResult {
  final DateTime cachedAt;
  
  CachedPaginatedResult({
    required List<RelationshipModel> relationships,
    required List<CachedProfile> profiles,
    required int totalCount,
    required int currentPage,
    required int pageSize,
    required bool hasNextPage,
    required bool hasPreviousPage,
    required this.cachedAt,
  }) : super(
    relationships: relationships,
    profiles: profiles,
    totalCount: totalCount,
    currentPage: currentPage,
    pageSize: pageSize,
    hasNextPage: hasNextPage,
    hasPreviousPage: hasPreviousPage,
  );
}
```

### Preloading Strategy

```dart
class PreloadingPaginationService {
  final RelationshipService _relationshipService;
  final Map<int, PaginatedRelationshipResult> _preloadedPages = {};
  
  PreloadingPaginationService(this._relationshipService);
  
  Future<PaginatedRelationshipResult> getFriendsWithPreload({
    int page = 1,
    int pageSize = 20,
  }) async {
    // Return cached page if available
    if (_preloadedPages.containsKey(page)) {
      final result = _preloadedPages[page]!;
      
      // Preload adjacent pages in background
      _preloadAdjacentPages(page, pageSize);
      
      return result;
    }
    
    // Load requested page
    final result = await _relationshipService.getFriends(
      page: page,
      pageSize: pageSize,
    );
    
    _preloadedPages[page] = result;
    
    // Preload next page in background
    if (result.hasNextPage) {
      _preloadPage(page + 1, pageSize);
    }
    
    return result;
  }
  
  Future<void> _preloadAdjacentPages(int currentPage, int pageSize) async {
    final futures = <Future>[];
    
    // Preload previous page
    if (currentPage > 1 && !_preloadedPages.containsKey(currentPage - 1)) {
      futures.add(_preloadPage(currentPage - 1, pageSize));
    }
    
    // Preload next page
    if (!_preloadedPages.containsKey(currentPage + 1)) {
      futures.add(_preloadPage(currentPage + 1, pageSize));
    }
    
    // Don't wait for preloading to complete
    unawaited(Future.wait(futures));
  }
  
  Future<void> _preloadPage(int page, int pageSize) async {
    try {
      final result = await _relationshipService.getFriends(
        page: page,
        pageSize: pageSize,
      );
      
      _preloadedPages[page] = result;
      
      // Limit cache size
      if (_preloadedPages.length > 10) {
        final oldestKey = _preloadedPages.keys.first;
        _preloadedPages.remove(oldestKey);
      }
      
    } catch (e) {
      // Ignore preloading errors
      print('Failed to preload page $page: $e');
    }
  }
  
  void clearCache() {
    _preloadedPages.clear();
  }
}
```

## Best Practices

### 1. Choose Appropriate Page Sizes
```dart
// Good: Reasonable page sizes for different contexts
const int MOBILE_PAGE_SIZE = 20;     // Mobile list views
const int DESKTOP_PAGE_SIZE = 50;    // Desktop tables
const int SEARCH_PAGE_SIZE = 10;     // Search results
const int EXPORT_PAGE_SIZE = 1000;   // Bulk operations
```

### 2. Handle Empty States
```dart
Widget buildFriendsList(PaginatedRelationshipResult result) {
  if (result.totalCount == 0) {
    return EmptyStateWidget(
      title: 'No friends yet',
      subtitle: 'Start connecting with other users',
      action: ElevatedButton(
        onPressed: () => navigateToUserSearch(),
        child: Text('Find Friends'),
      ),
    );
  }
  
  return ListView.builder(
    itemCount: result.relationships.length,
    itemBuilder: (context, index) => buildFriendTile(result, index),
  );
}
```

### 3. Provide Loading States
```dart
Widget buildPaginatedList() {
  return Column(
    children: [
      Expanded(
        child: ListView.builder(
          itemCount: _friends.length + (_hasMorePages ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _friends.length) {
              return LoadingIndicator();
            }
            return FriendTile(friend: _friends[index]);
          },
        ),
      ),
      if (_loading && _friends.isEmpty)
        Center(child: CircularProgressIndicator()),
    ],
  );
}
```

### 4. Error Recovery
```dart
Future<void> loadPageWithRetry(int page, {int maxRetries = 3}) async {
  int attempts = 0;
  
  while (attempts < maxRetries) {
    try {
      final result = await relationshipService.getFriends(page: page);
      // Handle success
      return;
      
    } on RelationshipException catch (e) {
      attempts++;
      
      if (e.code == RelationshipErrorCode.networkError && attempts < maxRetries) {
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(seconds: pow(2, attempts).toInt()));
        continue;
      }
      
      // Final failure
      throw e;
    }
  }
}
```
