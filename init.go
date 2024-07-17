package main

import(
	"fmt"
	"time"
)

func main() {
	for {
		fmt.Println("In go init")
		time.Sleep(1 * time.Second)
	}
}
