package com.splitwise.clone.splitwise_app

// FlutterFragmentActivity is required by google_sign_in_android v7+ which uses
// the Android Credential Manager API. Credential Manager requires a
// FragmentActivity host; FlutterActivity (AppCompatActivity) is not sufficient
// and will cause Google Sign-In to fail silently.
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
