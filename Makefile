AS = nasm
ASFLAGS = -felf64 -w+all -g -F Dwarf
TARGET = httpd

.PHONY: stripped
stripped: $(TARGET)
	strip $(TARGET)

$(TARGET): $(TARGET).o
	ld -o $(TARGET) $(TARGET).o

$(TARGET).o: $(TARGET).s
	$(AS) $(ASFLAGS) -o $(TARGET).o $(TARGET).s

.PHONY: clean
clean:
	rm $(TARGET).o $(TARGET)

.PHONY: test
test: $(TARGET).o test_http.c
	gcc -o test_http test_http.c $(TARGET).o
	./test_http
