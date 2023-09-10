#include <stdio.h>
#include <time.h>

int main() {
  struct timespec ts = {.tv_sec = 0, .tv_nsec = 100e6L};
  for (;;) {
    if (nanosleep(&ts, &ts) < 0) {
      return 1;
    }
    printf("init: running...\n");
  }
}