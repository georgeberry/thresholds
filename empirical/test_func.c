#include <stdio.h>

int main () {
  int i ;

  for (i = 0; i < 10; i++) {

    printf("%i\n", i);
    if (i == 2) {
      break;
    }
  }
  printf("%i\n", i);

  return 1;
}
