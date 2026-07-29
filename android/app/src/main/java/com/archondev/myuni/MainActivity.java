package com.archondev.myuni;

import android.os.Build;
import android.os.Bundle;
import android.view.Display;
import android.view.WindowManager;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                Display.Mode displayMode = getDisplay().getMode();
                Display.Mode[] modes = getDisplay().getSupportedModes();
                Display.Mode maxMode = displayMode;
                for (Display.Mode mode : modes) {
                    if (mode.getRefreshRate() > maxMode.getRefreshRate()) {
                        maxMode = mode;
                    }
                }
                WindowManager.LayoutParams params = getWindow().getAttributes();
                params.preferredDisplayModeId = maxMode.getModeId();
                getWindow().setAttributes(params);
            } catch (Exception e) {
                // Fallback if display mode retrieval fails
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                WindowManager.LayoutParams params = getWindow().getAttributes();
                params.preferredRefreshRate = 120.0f;
                getWindow().setAttributes(params);
            } catch (Exception e) {
                // Fallback
            }
        }
    }
}
