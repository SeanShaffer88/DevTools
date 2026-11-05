package __PACKAGE__;
import android.app.Activity;
import android.os.Bundle;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.view.MotionEvent;
import android.view.View;
public final class MainActivity extends Activity {
    @Override public void onCreate(Bundle state) { super.onCreate(state); setContentView(new GameView(this)); }
    private static final class GameView extends View {
        private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
        private int score = 0;
        private final float density;
        GameView(Context context) { super(context); density = getResources().getDisplayMetrics().density; setContentDescription("Tap The Circle To Score"); }
        @Override protected void onDraw(Canvas canvas) {
            canvas.drawColor(Color.rgb(245,247,250));
            paint.setColor(Color.rgb(23,38,59)); paint.setTextSize(24*density);
            canvas.drawText("__NAME__",24*density,52*density,paint);
            canvas.drawText("Score: "+score,24*density,96*density,paint);
            paint.setColor(Color.rgb(48,105,221)); canvas.drawCircle(getWidth()/2f,getHeight()/2f,48*density,paint);
            paint.setColor(Color.rgb(23,38,59)); paint.setTextSize(18*density);
            canvas.drawText("Tap The Circle",24*density,getHeight()-48*density,paint);
        }
        @Override public boolean onTouchEvent(MotionEvent event) {
            if(event.getAction()==MotionEvent.ACTION_UP) {
                float dx=event.getX()-getWidth()/2f,dy=event.getY()-getHeight()/2f;
                if(dx*dx+dy*dy<=48*48*density*density && score<Integer.MAX_VALUE) { score++; invalidate(); }
                performClick(); return true;
            }
            return true;
        }
        @Override public boolean performClick() { super.performClick(); return true; }
    }
}
