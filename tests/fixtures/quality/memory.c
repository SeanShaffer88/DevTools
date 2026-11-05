#include <stdlib.h>
int main(void) { volatile int n = 8; char *p = (char*)malloc(8); p[0] = 1;
#ifdef OVERFLOW
p[n] = 42;
#endif
free(p); return 0; }
