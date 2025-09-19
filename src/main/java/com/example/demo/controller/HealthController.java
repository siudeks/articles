package com.example.demo.controller;

import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;

@RestController
public class HealthController {

    private LocalDateTime startupTime;

    @EventListener(ApplicationReadyEvent.class)
    public void onApplicationReady() {
        this.startupTime = LocalDateTime.now();
        System.out.println("Application ready at: " + startupTime);
    }

    @GetMapping("/health")
    public String health() {
        return "OK - Started at: " + startupTime;
    }

    @GetMapping("/")
    public String home() {
        return "Hello World! Application started at: " + startupTime;
    }
}