package org.devtools.offlineapp;
import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
public final class MainActivity extends Activity {
    private int count;
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        if (saved != null) count = saved.getInt("count", 0);
        LinearLayout column = new LinearLayout(this); column.setOrientation(LinearLayout.VERTICAL); column.setPadding(32, 32, 32, 32);
        TextView label = new TextView(this); label.setTextSize(24); label.setText("Count: " + count); label.setAccessibilityLiveRegion(View.ACCESSIBILITY_LIVE_REGION_POLITE); column.addView(label);
        Button button = new Button(this); button.setText("Increment"); button.setOnClickListener(new View.OnClickListener() { @Override public void onClick(View view) { if (count < 1000000) count++; label.setText("Count: " + count); } }); column.addView(button);
        setContentView(column);
    }
    @Override protected void onSaveInstanceState(Bundle out) { out.putInt("count", count); super.onSaveInstanceState(out); }
}
