import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FriendsStorage {
  static const String _key = 'user_friends_list';

  static Future<void> saveFriend(String name, String phone) async {
    final prefs = await SharedPreferences.getInstance();

    // Get existing friends
    List<String> friendsStringList = prefs.getStringList(_key) ?? [];

    // Create new friend object
    Map<String, String> newFriend = {'name': name, 'phone': phone};

    // Add to list and save
    friendsStringList.add(jsonEncode(newFriend));
    await prefs.setStringList(_key, friendsStringList);
  }

  static Future<List<Map<String, String>>> getFriends() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> friendsStringList = prefs.getStringList(_key) ?? [];

    return friendsStringList.map((friendString) {
      final Map<String, dynamic> decoded = jsonDecode(friendString);
      return {
        'name': decoded['name'].toString(),
        'phone': decoded['phone'].toString(),
      };
    }).toList();
  }
}
