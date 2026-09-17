import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHelper {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Current user
  static User? get currentUser => client.auth.currentUser;
  static String? get userId => currentUser?.id;
  static bool get isAuthenticated => currentUser != null;
}
