AS = nasm
ASFLAGS = -felf64 -w+all -g -F Dwarf
CFLAGS = -Wall -g -F Dwarf
TARGET = httpd

.PHONY: stripped
stripped: $(TARGET)
	strip $(TARGET)

$(TARGET): $(TARGET).o main.o itoa.o logging.o
	ld -o $(TARGET) $(TARGET).o main.o itoa.o logging.o

$(TARGET).o: $(TARGET).s
	$(AS) $(ASFLAGS) -o $(TARGET).o $(TARGET).s

itoa.o: itoa.s
	$(AS) $(ASFLAGS) -o itoa.o itoa.s

logging.o: logging.s
	$(AS) $(ASFLAGS) -o logging.o logging.s

main.o: main.s
	$(AS) $(ASFLAGS) -o main.o main.s

.PHONY: clean
clean:
	rm $(TARGET).o $(TARGET)

.PHONY: test
test: $(TARGET).o itoa.o logging.o test_http.c
	gcc $(CFLAGS) -o test_http test_http.c $(TARGET).o itoa.o logging.o
	./test_http
