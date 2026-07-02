import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton Supabase client untuk digunakan di seluruh aplikasi.
SupabaseClient get supabaseClient => Supabase.instance.client;
