AS = nasm
ASFLAGS = -felf64 -w+all -D LOG_IPS
DEBUGASFLAGS = -felf64 -w+all -g -F Dwarf -D DEBUG -D LOG_IPS
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
	rm *.o $(TARGET)

.PHONY: debug
debug: $(TARGET).s main.s itoa.s logging.s
	$(AS) $(DEBUGASFLAGS) -o $(TARGET).o $(TARGET).s
	$(AS) $(DEBUGASFLAGS) -o itoa.o itoa.s
	$(AS) $(DEBUGASFLAGS) -o logging.o logging.s
	$(AS) $(DEBUGASFLAGS) -o main.o main.s
	ld -o $(TARGET) $(TARGET).o main.o itoa.o logging.o

.PHONY: test
test: $(TARGET).o itoa.o logging.o test_http.c
	gcc $(CFLAGS) -o test_http test_http.c $(TARGET).o itoa.o logging.o
	./test_http
