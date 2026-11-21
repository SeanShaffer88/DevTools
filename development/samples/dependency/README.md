# Packed Java Dependency

Library API: org.devtools.math.Squares.square(int), with Math.multiplyExact overflow rejection. Build the library class using the saved JDK, package it into a standard ZIP-based JAR with the original Node builder, then compile and run consumer/Consume.java from a separate directory with only the JAR on its library classpath. The consumer checks a valid square and overflow rejection. It never compiles the library source alongside the consumer.

Source and library license: ../LICENSE. The sample uses Java 8 source/target syntax with an actual Java 21 compiler/runtime. It does not certify arbitrary Java 8 API compatibility.
