#include <iostream>
#include <string>

int main(int argc, char** argv) {
    const std::string who = argc > 1 ? argv[1] : "world";
    std::cout << "Hello, " << who << " (C++" << __cplusplus / 100 % 100 << ")\n";
    return 0;
}
