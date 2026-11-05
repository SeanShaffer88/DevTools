package __PACKAGE__;
import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.widget.TextView;
public final class MainActivity extends Activity {
    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        TextView content = new TextView(this);
        content.setText("__NAME__\n\nApp Is Ready");
        content.setTextSize(24);
        content.setTextColor(Color.rgb(23, 38, 59));
        content.setBackgroundColor(Color.rgb(245, 247, 250));
        int padding = (int)(24 * getResources().getDisplayMetrics().density);
        content.setPadding(padding, padding, padding, padding);
        setContentView(content);
    }
}
