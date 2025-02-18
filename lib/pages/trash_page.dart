import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};

  Future<void> _restoreItems(List<String> ids) async {
    try {
      final batch = _firestore.batch();
      
      for (String id in ids) {
        final docRef = _firestore.collection('todos').doc(id);
        batch.update(docRef, {'isDeleted': false});
      }

      await batch.commit();

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ids.length} items restored'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring items: $e')),
        );
      }
    }
  }

  Future<void> _deletePermanently(List<String> ids) async {
    try {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Permanent Deletion'),
          content: const Text(
            'Are you sure you want to permanently delete these items? This action cannot be undone.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      final batch = _firestore.batch();
      
      for (String id in ids) {
        final docRef = _firestore.collection('todos').doc(id);
        batch.delete(docRef);
      }

      await batch.commit();

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ids.length} items permanently deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting items: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (_isSelectionMode) ...[
            Text('${_selectedItems.length} selected  ', 
              style: Theme.of(context).textTheme.bodyLarge),
            IconButton(
              icon: const Icon(Icons.restore),
              onPressed: _selectedItems.isEmpty 
                ? null 
                : () => _restoreItems(_selectedItems.toList()),
              tooltip: 'Restore selected items',
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _selectedItems.isEmpty 
                ? null 
                : () => _deletePermanently(_selectedItems.toList()),
              tooltip: 'Delete selected permanently',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isSelectionMode = false;
                  _selectedItems.clear();
                });
              },
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('todos')
            .where('userId', isEqualTo: currentUser?.uid)
            .where('isDeleted', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final todos = snapshot.data?.docs ?? [];

          if (todos.isEmpty) {
            return const Center(child: Text('Trash is empty'));
          }

          return ListView.builder(
            itemCount: todos.length,
            itemBuilder: (context, index) {
              final doc = todos[index];
              final todo = doc.data() as Map<String, dynamic>;
              final id = doc.id;
              final isSelected = _selectedItems.contains(id);

              return ListTile(
                title: Text(todo['title'] as String),
                leading: _isSelectionMode
                    ? Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedItems.add(id);
                            } else {
                              _selectedItems.remove(id);
                            }
                            if (_selectedItems.isEmpty) {
                              _isSelectionMode = false;
                            }
                          });
                        },
                      )
                    : null,
                trailing: _isSelectionMode
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.restore),
                            onPressed: () => _restoreItems([id]),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever),
                            onPressed: () => _deletePermanently([id]),
                          ),
                        ],
                      ),
                onLongPress: () {
                  setState(() {
                    _isSelectionMode = true;
                    _selectedItems.add(id);
                  });
                },
                onTap: _isSelectionMode
                    ? () {
                        setState(() {
                          if (isSelected) {
                            _selectedItems.remove(id);
                          } else {
                            _selectedItems.add(id);
                          }
                          if (_selectedItems.isEmpty) {
                            _isSelectionMode = false;
                          }
                        });
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }
} 