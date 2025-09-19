package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class DemoApplication {

    public static void main(String[] args) {
        // Log startup time
        long startTime = System.currentTimeMillis();
        SpringApplication.run(DemoApplication.class, args);
        long endTime = System.currentTimeMillis();
        System.out.println("Application started in " + (endTime - startTime) + " ms");
    }

}