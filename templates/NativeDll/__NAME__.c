#include "__NAME__.h"
#include <limits.h>
/* Clamp overflow so all int inputs have defined behavior. */
int __NAME___Add(int left, int right) {
    if (right > 0 && left > INT_MAX - right) return INT_MAX;
    if (right < 0 && left < INT_MIN - right) return INT_MIN;
    return left + right;
}
