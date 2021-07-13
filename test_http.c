#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

// Function prototype for the asm itoa
uint64_t itoa(uint64_t number, char *str_buffer, uint64_t str_buffer_len);

// Tests
void test_itoa_1(void);
void test_itoa_2(void);
void test_itoa_3(void);
void test_itoa_4(void);
void test_itoa_5(void);
void test_itoa_6(void);
void test_itoa_7(void);
void test_itoa_8(void);
void test_itoa_9(void);
void test_itoa_10(void);
void test_itoa_11(void);

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

    // Test asm implementation of itoa
    test_itoa_1();
    test_itoa_2();
    test_itoa_3();
    test_itoa_4();
    test_itoa_5();
    test_itoa_6();
    test_itoa_7();
    test_itoa_8();
    test_itoa_9();
    test_itoa_10();
    test_itoa_11();

    printf("Test results: %d / %d\n", total_tests - tests_failed, total_tests);
    return 0;
}

void test_itoa_1(void)
{
    // Test base case:
    // We have a number
    // We have a buffer bigger than the str repr of the number
    uint64_t num = 15615612358;
    char str_buf[] = {65,65,65,65,65,65,65,65,65,65,65,65,65,65,65}; // len 15
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    itoa(num, str_buf, str_buf_size);
    assert_test(!strcmp("15615612358", str_buf));
}

void test_itoa_2(void)
{
    // Test base case:
    // We have a number
    // We have a buffer bigger than the str repr of the number
    uint64_t num = 15615612358;
    char str_buf[] = {65,65,65,65,65,65,65,65,65,65,65,65,65,65,65}; // len 15
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    itoa(num, str_buf, str_buf_size);
    assert_test(strcmp("AAAAAAAAAAAAAAA", str_buf));
}

void test_itoa_3(void)
{
    // Test single digit number with large buffer
    uint64_t num = 1;
    char str_buf[] = {65,65,65,65,65,65,65,65,65,65,65,65,65,65,65}; // len 15
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    itoa(num, str_buf, str_buf_size);
    assert_test(!strcmp("1", str_buf));
}

void test_itoa_4(void)
{
    // Test single digit number with exactly sized buffer
    uint64_t num = 1;
    char str_buf[] = {65,65}; // len 2
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    itoa(num, str_buf, str_buf_size);
    assert_test(!strcmp("1", str_buf));
}

void test_itoa_5(void)
{
    // Test single digit number with buffer that is too small
    uint64_t num = 1;
    char str_buf[] = {65}; // len 1
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    uint64_t result = itoa(num, str_buf, str_buf_size);
    assert_test(!result);
}

void test_itoa_6(void)
{
    // Test single digit number with buffer that is too small
    uint64_t num = 1;
    char str_buf[] = {}; // len 0
    uint64_t str_buf_size = 0;
    uint64_t result = itoa(num, str_buf, str_buf_size);
    assert_test(!result);
}

void test_itoa_7(void)
{
    // Test edge case: 0
    uint64_t num = 0;
    char str_buf[] = {65,65}; // len 2
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    itoa(num, str_buf, str_buf_size);
    assert_test(!strcmp("0", str_buf));
}

void test_itoa_8(void)
{
    // Test return value
    uint64_t num = 0;
    char str_buf[] = {65,65}; // len 2
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    uint64_t result = itoa(num, str_buf, str_buf_size);
    assert_test(result == 1);
}

void test_itoa_9(void)
{
    // Test return value
    uint64_t num = 11;
    char str_buf[] = {65,65,65}; // len 3
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    uint64_t result = itoa(num, str_buf, str_buf_size);
    assert_test(result == 2);
}

void test_itoa_10(void)
{
    // Test return value
    uint64_t num = 123456789123456789;
    char str_buf[] = {65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65}; // len 19
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    uint64_t result = itoa(num, str_buf, str_buf_size);
    assert_test(result == 18);
}

void test_itoa_11(void)
{
    // Test return value
    uint64_t num = 1626156690;
    char str_buf[] = {65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65,65}; // len 19
    uint64_t str_buf_size = sizeof(str_buf) / sizeof(str_buf[0]);
    uint64_t result = itoa(num, str_buf, str_buf_size);
    assert_test(result == 10);
}
