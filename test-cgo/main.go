package main

/*
char * call(void) {
  return "it works";
}
*/
import "C"
import "fmt"

func main() {
	fmt.Println(C.GoString(C.call()))
}
