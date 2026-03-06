#!/bin/bash
sed -i -E 's/const (Text\(.*\))/\1/g' lib/auth/screens/login_screen.dart
sed -i -E 's/const (Text.*)$/\1/g' lib/auth/screens/reset_password_screen.dart
sed -i -E 's/const (Text.*)$/\1/g' lib/user/screens/add_expense_screen.dart
sed -i -E 's/const (Icon.*)$/\1/g' lib/user/screens/add_expense_screen.dart
sed -i -E 's/const (EdgeInsets.*)$/\1/g' lib/user/screens/tabs/dashboard_tab.dart
sed -i -E 's/const (Center\(.*Text.*)$/\1/g' lib/user/screens/tabs/dashboard_tab.dart
sed -i -E 's/const (Center\(.*Text.*)$/\1/g' lib/user/screens/tabs/groups_tab.dart
sed -i -E 's/const (Center\(.*Text.*)$/\1/g' lib/user/screens/tabs/add_friends_tab.dart
sed -i -E 's/const (Icon.*)$/\1/g' lib/auth/screens/login_screen.dart
