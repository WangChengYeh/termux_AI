package com.termux.app.fragments.settings.termux;

import android.content.Context;
import android.os.Bundle;

import androidx.annotation.Keep;
import androidx.preference.PreferenceFragmentCompat;
import androidx.preference.PreferenceManager;

import com.termux.R;

@Keep
public class AIPreferencesFragment extends PreferenceFragmentCompat {

    @Override
    public void onCreatePreferences(Bundle savedInstanceState, String rootKey) {
        Context context = getContext();
        if (context == null) return;

        setPreferencesFromResource(R.xml.termux_ai_preferences, rootKey);
    }

    @Override
    public void onResume() {
        super.onResume();
        
        Context context = getContext();
        if (context == null) return;

        PreferenceManager.setDefaultValues(context, R.xml.termux_ai_preferences, false);
    }
}