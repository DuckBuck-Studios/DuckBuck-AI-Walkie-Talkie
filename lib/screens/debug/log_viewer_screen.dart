import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/native_debug_logger.dart';
import '../../widgets/animated_background.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  bool _isLoading = true;
  String _logContent = '';
  Map<String, dynamic>? _logJson;
  String _searchQuery = '';
  int _selectedSessionIndex = -1;
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load the logs from the native layer
      final logContent = await NativeDebugLogger.readDebugLog();
      
      // Parse JSON if valid
      Map<String, dynamic>? logJson;
      try {
        logJson = json.decode(logContent);
      } catch (e) {
        logJson = null;
      }

      setState(() {
        _logContent = logContent;
        _logJson = logJson;
        _isLoading = false;
        if (_logJson != null && _logJson!.containsKey('app_sessions')) {
          _sessions = _logJson!['app_sessions'];
          if (_sessions.isNotEmpty) {
            _selectedSessionIndex = _sessions.length - 1;
          }
        }
      });
    } catch (e) {
      setState(() {
        _logContent = 'Error loading logs: $e';
        _isLoading = false;
      });
    }
  }

  // Create a new log session
  Future<void> _createNewSession() async {
    await NativeDebugLogger.startNewSession('Manual creation from LogViewer');
    await _loadLogs();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New log session created')),
    );
  }

  // Clear all logs
  Future<void> _clearLogs() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Logs?'),
        content: const Text(
          'This will permanently delete all log entries. This action cannot be undone.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading indicator
              setState(() {
                _isLoading = true;
              });
              
              // Clear logs
              final success = await NativeDebugLogger.clearLogs();
              
              // Reload logs
              await _loadLogs();
              
              // Show feedback
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All logs cleared successfully')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to clear logs'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Get the current selected session events
  List<dynamic> _getSessionEvents() {
    if (_selectedSessionIndex < 0 || _selectedSessionIndex >= _sessions.length) {
      return [];
    }
    
    final session = _sessions[_selectedSessionIndex];
    if (session is Map && session.containsKey('events')) {
      return session['events'] ?? [];
    }
    return [];
  }

  // Filter events based on search query
  List<dynamic> _getFilteredEvents() {
    final events = _getSessionEvents();
    if (_searchQuery.isEmpty) {
      return events;
    }
    
    final lowerQuery = _searchQuery.toLowerCase();
    return events.where((event) {
      if (event is! Map) return false;
      
      // Search in tag, message, and data
      final tag = event['tag']?.toString().toLowerCase() ?? '';
      final message = event['message']?.toString().toLowerCase() ?? '';
      final data = event['data']?.toString().toLowerCase() ?? '';
      
      return tag.contains(lowerQuery) || 
             message.contains(lowerQuery) || 
             data.contains(lowerQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        opacity: 0.03,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(context),
              
              // Search bar
              _buildSearchBar(),
              
              // Session selector
              if (_sessions.isNotEmpty) _buildSessionSelector(),
              
              // Log content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4A76A)))
                    : _logJson == null
                        ? _buildRawLogView()
                        : _buildStructuredLogView(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Clear logs button
          FloatingActionButton.small(
            heroTag: "btnClear",
            backgroundColor: Colors.red,
            onPressed: _clearLogs,
            tooltip: "Clear all logs",
            child: const Icon(Icons.delete_forever, color: Colors.white),
          ),
          const SizedBox(height: 16),
          // New session button
          FloatingActionButton(
            heroTag: "btnNew",
            backgroundColor: const Color(0xFFD4A76A),
            onPressed: _createNewSession,
            tooltip: "Add new session",
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFD4A76A).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
            color: const Color(0xFFD4A76A),
          ),
          const Expanded(
            child: Text(
              'Debug Logs',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD4A76A),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
            color: const Color(0xFFD4A76A),
          ),
        ],
      ),
    ).animate()
      .fadeIn()
      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search logs...',
          prefixIcon: const Icon(Icons.search, color: Color(0xFFD4A76A)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildSessionSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];
          final isSelected = index == _selectedSessionIndex;
          
          // Get session info
          final sessionId = session['session_id'] ?? 'Unknown';
          final startedAt = session['started_at'] ?? '';
          final sessionReason = session['reason'] ?? 'Unknown';
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedSessionIndex = index;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFD4A76A) 
                    : const Color(0xFFD4A76A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFFD4A76A),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Session ${index + 1} (${sessionReason.split('_')[0]})',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8B4513),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildRawLogView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(
        _logContent,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildStructuredLogView() {
    final filteredEvents = _getFilteredEvents();
    
    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'No log events found in this session'
                  : 'No results found for "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEvents.length,
      itemBuilder: (context, index) {
        // Display events in reverse order (newest first)
        final event = filteredEvents[filteredEvents.length - 1 - index];
        return _buildEventCard(event);
      },
    );
  }

  Widget _buildEventCard(Map<dynamic, dynamic> event) {
    final timestamp = event['timestamp'] ?? '';
    final tag = event['tag'] ?? '';
    final message = event['message'] ?? '';
    final data = event['data'];
    
    // Color based on tag type
    Color tagColor = const Color(0xFF8B4513);
    if (tag.toString().contains('Error') || tag.toString().contains('error')) {
      tagColor = Colors.red;
    } else if (tag.toString().contains('Agora')) {
      tagColor = Colors.blue;
    } else if (tag.toString().contains('FCM')) {
      tagColor = Colors.green;
    } else if (tag.toString().contains('Service')) {
      tagColor = Colors.purple;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tagColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: tagColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF8B4513),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          timestamp,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        children: [
          if (data != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const Text(
                    'Additional Data:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8B4513),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_mapDataToWidgets(data)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _mapDataToWidgets(Map<dynamic, dynamic> data) {
    return data.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.key}: ',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF8B4513),
              ),
            ),
            Expanded(
              child: Text(
                entry.value.toString(),
                style: TextStyle(
                  color: entry.value.toString().contains('error') 
                      ? Colors.red 
                      : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
} 