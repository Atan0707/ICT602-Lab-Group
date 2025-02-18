import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'trash_page.dart';

class TodoListPage extends StatefulWidget {
  const TodoListPage({super.key});

  @override
  State<TodoListPage> createState() => _TodoListPageState();
}

class _TodoListPageState extends State<TodoListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {};
  final _todoController = TextEditingController();
  bool _isEditing = false;
  String? _editingId;

  @override
  void dispose() {
    _todoController.dispose();
    super.dispose();
  }

  Future<void> _addTodo() async {
    if (_todoController.text.isEmpty) return;

    try {
      await _firestore.collection('todos').add({
        'title': _todoController.text,
        'userId': currentUser?.uid,
        'isCompleted': false,
        'isDeleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _todoController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding todo: $e')),
        );
      }
    }
  }

  Future<void> _updateTodo(String id) async {
    if (_todoController.text.isEmpty) return;

    try {
      await _firestore.collection('todos').doc(id).update({
        'title': _todoController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _todoController.clear();
      setState(() {
        _isEditing = false;
        _editingId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating todo: $e')),
        );
      }
    }
  }

  Future<void> _deleteTodo(String id, {bool permanent = false}) async {
    try {
      if (permanent) {
        // Show confirmation dialog
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text('Are you sure you want to permanently delete this item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        await _firestore.collection('todos').doc(id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todo permanently deleted')),
          );
        }
      } else {
        // Temporary delete (soft delete)
        await _firestore.collection('todos').doc(id).update({
          'isDeleted': true,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todo moved to trash')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting todo: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelected({bool permanent = false}) async {
    try {
      if (permanent) {
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text('Are you sure you want to permanently delete selected items?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        for (String id in _selectedItems) {
          await _firestore.collection('todos').doc(id).delete();
        }
      } else {
        for (String id in _selectedItems) {
          await _firestore.collection('todos').doc(id).update({
            'isDeleted': true,
          });
        }
      }

      setState(() {
        _selectedItems.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(permanent
                ? 'Selected items permanently deleted'
                : 'Selected items moved to trash'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting todos: $e')),
        );
      }
    }
  }

  Future<void> _deleteMultipleTodos(List<String> ids, {bool permanent = false}) async {
    try {
      final batch = _firestore.batch();
      
      if (permanent) {
        // Show confirmation dialog
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Deletion'),
            content: const Text('Are you sure you want to permanently delete these items?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        // Add delete operations to batch
        for (String id in ids) {
          final docRef = _firestore.collection('todos').doc(id);
          batch.delete(docRef);
        }
      } else {
        // Soft delete - mark as deleted
        for (String id in ids) {
          final docRef = _firestore.collection('todos').doc(id);
          batch.update(docRef, {'isDeleted': true});
        }
      }

      // Commit the batch
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(permanent 
              ? '${ids.length} items permanently deleted' 
              : '${ids.length} items moved to trash'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting todos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        actions: [
          if (!_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TrashPage()),
                );
              },
              tooltip: 'View trash',
            ),
          if (_isSelectionMode) ...[
            Text('${_selectedItems.length} selected  ', 
              style: Theme.of(context).textTheme.bodyLarge),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _selectedItems.isEmpty 
                ? null 
                : () => _deleteMultipleTodos(_selectedItems.toList(), permanent: false),
              tooltip: 'Move selected to trash',
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever),
              onPressed: _selectedItems.isEmpty 
                ? null 
                : () => _deleteMultipleTodos(_selectedItems.toList(), permanent: true),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _todoController,
                    decoration: InputDecoration(
                      hintText: _isEditing ? 'Edit todo' : 'Add new todo',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_isEditing) {
                      _updateTodo(_editingId!);
                    } else {
                      _addTodo();
                    }
                  },
                  child: Text(_isEditing ? 'Update' : 'Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('todos')
                  .where('userId', isEqualTo: currentUser?.uid)
                  .where('isDeleted', isEqualTo: false)
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
                  return const Center(child: Text('No todos yet'));
                }

                if (isTablet) {
                  // Grid view for tablets
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 3,
                    ),
                    itemCount: todos.length,
                    itemBuilder: (context, index) => _buildTodoItem(todos[index]),
                  );
                } else {
                  // List view for phones
                  return ListView.builder(
                    itemCount: todos.length,
                    itemBuilder: (context, index) => _buildTodoItem(todos[index]),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoItem(DocumentSnapshot doc) {
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
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _editingId = id;
                      _todoController.text = todo['title'] as String;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteTodo(id, permanent: false),
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
  }
}