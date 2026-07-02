import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengekspos singleton Supabase client untuk digunakan di seluruh aplikasi.
///
/// Pastikan [Supabase.initialize()] sudah dipanggil di [main.dart]
/// sebelum mengakses [supabaseClient].
SupabaseClient get supabaseClient => Supabase.instance.client;
