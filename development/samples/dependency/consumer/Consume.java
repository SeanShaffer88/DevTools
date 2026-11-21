import org.devtools.math.Squares;
public final class Consume {
    public static void main(String[] args) {
        if (Squares.square(7) != 49) throw new AssertionError("packed dependency failed");
        try { Squares.square(50000); throw new AssertionError("overflow accepted"); } catch (ArithmeticException expected) { }
        System.out.println("Packed JAR consumption passed");
    }
}
