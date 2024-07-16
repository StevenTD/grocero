// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:dynamic_color/dynamic_color.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  //await Hive.deleteBoxFromDisk('shopping_box');
  await Hive.openBox('shopping_box');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Grocero',
        darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: darkDynamic), // standard dark theme
        themeMode: ThemeMode.system, // device controls theme
        theme: ThemeData(useMaterial3: true, colorScheme: lightDynamic
            // primarySwatch: Colors.green,
            ),
        home: const HomePage(),
      );
    });
  }
}

// Home Page
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _items = [];
  double currentTotal = 0.0;

  final _shoppingBox = Hive.box('shopping_box');

  @override
  void initState() {
    super.initState();
    _refreshItems(); // Load data when app starts
  }

  double getTotalPrice() {
    double totalPrice = 0.0;
    for (var item in _shoppingBox.values) {
      if (item.containsKey('total_price')) {
        totalPrice += item['total_price'];
      }
    }
    return totalPrice;
  }

  // Get all items from the database
  void _refreshItems() {
    final data = _shoppingBox.keys.map((key) {
      final value = _shoppingBox.get(key);
      return {
        "key": key,
        "name": value["name"],
        "quantity": value['quantity'],
        "price": value['price'],
        "total_price": value['total_price'],
      };
    }).toList();

    setState(() {
      _items = data.reversed.toList();
      // we use "reversed" to sort items in order from the latest to the oldest
    });
  }

  void calculateCurrent() {
    String quantityText = _quantityController.text ?? '0';
    String totalPriceText = _priceController.text ?? '0';

    double quantity;
    double totalPrice;

    try {
      print('$quantityText * $totalPriceText');
      quantity = double.parse(quantityText);
      totalPrice = double.parse(totalPriceText);
    } catch (e) {
      // Handle the error here
      setState(() {
        currentTotal = 0.0;
      });
      // You can set default values or show an error message to the user.
      return; // Exit the function early if parsing fails
    }
    setState(() {
      currentTotal = quantity * totalPrice;
    });

    print(currentTotal.toString());
  }

  // Create new item
  Future<void> _createItem(Map<String, dynamic> newItem) async {
    await _shoppingBox.add(newItem);
    _refreshItems(); // update the UI
  }

  // Retrieve a single item from the database by using its key
  // Our app won't use this function but I put it here for your reference
  Map<String, dynamic> _readItem(int key) {
    final item = _shoppingBox.get(key);
    return item;
  }

  // Update a single item
  Future<void> _updateItem(int itemKey, Map<String, dynamic> item) async {
    await _shoppingBox.put(itemKey, item);
    _refreshItems(); // Update the UI
  }

  // Delete a single item
  Future<void> _deleteItem(int itemKey) async {
    await _shoppingBox.delete(itemKey);
    _refreshItems(); // update the UI

    // Display a snackbar
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An item has been deleted')));
  }

  // TextFields' controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();

  // This function will be triggered when the floating button is pressed
  // It will also be triggered when you want to update an item
  void _showForm(
    BuildContext ctx,
    int? itemKey,
    Function calculateTotal2,
  ) async {
    // itemKey == null -> create new item
    // itemKey != null -> update an existing item

    if (itemKey != null) {
      final existingItem =
          _items.firstWhere((element) => element['key'] == itemKey);
      _nameController.text = existingItem['name'];
      _quantityController.text = existingItem['quantity'];
      _priceController.text = existingItem['price'];
    }

    double calculateTotal(double price, double qty) {
      try {
        return price * qty;
      } catch (e) {
        return 0;
      }
    }

    calculateTotal2();

    showModalBottomSheet(
        context: ctx,
        elevation: 5,
        isScrollControlled: true,
        builder: (_) => StatefulBuilder(
              builder: (context, StateSetter myState) => Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(ctx).viewInsets.bottom,
                    top: 15,
                    left: 15,
                    right: 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(hintText: 'Name'),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    TextField(
                      onChanged: (_) {
                        calculateTotal2();
                        myState(
                          () {},
                        );
                      },
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter
                            .digitsOnly // Only allow digits
                      ],
                      decoration: const InputDecoration(hintText: 'Quantity'),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    TextField(
                      onChanged: (_) {
                        calculateTotal2();
                        myState(
                          () {},
                        );
                      },
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true), // Allows decimal input
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')), // Allow digits and a period
                      ],
                      decoration: const InputDecoration(hintText: 'Price'),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    Row(
                      children: [
                        Text(
                          'Current Total: ${NumberFormat.currency(
                            // Use your desired locale
                            symbol:
                                '\₱ ', // Change the currency symbol as needed
                          ).format(currentTotal)}',
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            // Save new item
                            if (itemKey == null) {
                              _createItem({
                                "name": _nameController.text,
                                "quantity": _quantityController.text,
                                "price": _priceController.text,
                                "total_price": currentTotal
                              });
                            }

                            // update an existing item
                            if (itemKey != null) {
                              _updateItem(itemKey, {
                                'name': _nameController.text.trim(),
                                'quantity': _quantityController.text.trim(),
                                "price": _priceController.text.trim(),
                                "total_price": currentTotal
                              });
                            }

                            // Clear the text fields
                            _nameController.text = '';
                            _quantityController.text = '';
                            _priceController.text = '';
                            Navigator.of(context)
                                .pop(); // Close the bottom sheet
                          },
                          child:
                              Text(itemKey == null ? 'Create New' : 'Update'),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 15,
                    )
                  ],
                ),
              ),
            ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Container(
            padding: const EdgeInsets.all(5.0),
            child: Text(
              NumberFormat.currency(
                // Use your desired locale
                symbol: '\₱ ', // Change the currency symbol as needed
              ).format(getTotalPrice()),
              style: const TextStyle(fontSize: 30.0),
            ),
          ),
        ],
        title: const Text('Budget'),
      ),

      body: _items.isEmpty
          ? const Center(
              child: Text(
                'No Data',
                style: TextStyle(fontSize: 30),
              ),
            )
          : ListView.builder(
              // the list of items
              itemCount: _items.length,
              itemBuilder: (_, index) {
                final currentItem = _items[index];
                return Card(
                  // color: Colors.orange.shade100,
                  margin: const EdgeInsets.all(10),
                  elevation: 3,
                  child: ListTile(
                      title: Text(
                        currentItem['name'] +
                            ' (Price: ${currentItem['price']}) = ${NumberFormat.currency(
                              // Use your desired locale
                              symbol: '\₱ ',
                            ).format(currentItem['total_price'])}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('Qty: ${currentItem['quantity']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button
                          IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () {
                                return _showForm(context, currentItem['key'],
                                    () {
                                  calculateCurrent();
                                });
                              }),
                          // Delete button
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteItem(currentItem['key']),
                          ),
                        ],
                      )),
                );
              }),
      // Add new item button
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, null, () {
          calculateCurrent();
        }),
        child: const Icon(Icons.add),
      ),
    );
  }
}
