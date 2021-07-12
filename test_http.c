#include <stdio.h>
#include <stdlib.h>

// Unit testing framework
#define FAIL() printf(" failure in %s() line %d\n", __func__, __LINE__)
#define assert_test(test)                          \
    do {                                           \
        total_tests++;                             \
        printf("%d. %s: ", total_tests, __func__); \
        if (!(test)) {                             \
            printf("- ");                          \
            FAIL();                                \
            tests_failed++;                        \
        } else                                     \
            printf("+\n");                         \
    } while (0)

int total_tests = 0;
int tests_failed = 0;

int main(int argc, char* argv[])
{
    // stderr redirection
    // FILE* devnull = fopen("/dev/null", "w");
    // dup2(fileno(devnull), STDERR_FILENO);

    printf("Test results: %d / %d\n", total_tests - tests_failed, total_tests);
    return 0;
}
