package com.example.demo;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.Timeout;
import org.springframework.boot.test.context.SpringBootTest;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
class ResourceExhaustionTests {

    @Test
    @Timeout(value = 30, unit = TimeUnit.SECONDS)
    void shouldTriggerResourceExhaustionException() throws IOException {
        List<Socket> sockets = new ArrayList<>();
        List<ServerSocket> serverSockets = new ArrayList<>();
        
        try {
            // Create a server socket to connect to
            ServerSocket serverSocket = new ServerSocket(0); // Use any available port
            int port = serverSocket.getLocalPort();
            serverSockets.add(serverSocket);
            
            // Start accepting connections in a separate thread
            Thread serverThread = new Thread(() -> {
                try {
                    while (!Thread.currentThread().isInterrupted()) {
                        Socket clientSocket = serverSocket.accept();
                        // Keep the socket open to consume resources
                        synchronized (sockets) {
                            sockets.add(clientSocket);
                        }
                    }
                } catch (IOException e) {
                    // Expected when server socket is closed
                }
            });
            serverThread.setDaemon(true);
            serverThread.start();
            
            // Create many client connections to exhaust file descriptors
            boolean exceptionThrown = false;
            IOException lastException = null;
            
            // Based on the previous test, we know we can trigger at around 28,000 connections
            int maxConnections = Integer.parseInt(System.getProperty("test.max.connections", "35000"));
            
            for (int i = 0; i < maxConnections; i++) {
                try {
                    Socket socket = new Socket("localhost", port);
                    sockets.add(socket);
                    
                    // Log progress every 2000 connections for better performance
                    if (i % 2000 == 0) {
                        System.out.println("Created " + i + " connections");
                    }
                    
                } catch (IOException e) {
                    lastException = e;
                    exceptionThrown = true;
                    System.out.println("Resource exhaustion occurred after " + i + " connections: " + e.getMessage());
                    break;
                }
            }
            
            serverThread.interrupt();
            
            // Verify that we got the expected resource exhaustion exception
            assertTrue(exceptionThrown, "Expected IOException due to resource exhaustion");
            assertNotNull(lastException, "Expected an IOException to be thrown");
            
            // Common error messages for resource exhaustion
            String errorMessage = lastException.getMessage().toLowerCase();
            boolean isResourceExhaustion = 
                errorMessage.contains("too many open files") ||
                errorMessage.contains("connection refused") ||
                errorMessage.contains("resource temporarily unavailable") ||
                errorMessage.contains("cannot assign requested address") ||
                errorMessage.contains("no buffer space available");
                
            assertTrue(isResourceExhaustion, 
                "Exception should be related to resource exhaustion. Got: " + lastException.getMessage());
            
            System.out.println("Successfully triggered resource exhaustion with " + sockets.size() + " connections");
            
        } finally {
            // Clean up resources
            System.out.println("Cleaning up " + sockets.size() + " sockets and " + serverSockets.size() + " server sockets");
            
            for (Socket socket : sockets) {
                try {
                    if (!socket.isClosed()) {
                        socket.close();
                    }
                } catch (IOException e) {
                    // Ignore cleanup errors
                }
            }
            
            for (ServerSocket serverSocket : serverSockets) {
                try {
                    if (!serverSocket.isClosed()) {
                        serverSocket.close();
                    }
                } catch (IOException e) {
                    // Ignore cleanup errors
                }
            }
        }
    }

    @Test
    @Timeout(value = 30, unit = TimeUnit.SECONDS)
    void shouldTriggerFileDescriptorExhaustion() {
        List<ServerSocket> serverSockets = new ArrayList<>();
        
        try {
            boolean exceptionThrown = false;
            IOException lastException = null;
            
            // Try to create many server sockets to exhaust file descriptors
            // Increase the number since we saw it can handle 10,000
            int maxAttempts = Integer.parseInt(System.getProperty("test.max.sockets", "50000"));
            
            for (int i = 0; i < maxAttempts; i++) {
                try {
                    ServerSocket serverSocket = new ServerSocket(0); // Use any available port
                    serverSockets.add(serverSocket);
                    
                    // Log progress every 1000 sockets for better tracking
                    if (i % 1000 == 0) {
                        System.out.println("Created " + i + " server sockets");
                    }
                    
                } catch (IOException e) {
                    lastException = e;
                    exceptionThrown = true;
                    System.out.println("File descriptor exhaustion occurred after " + i + " server sockets: " + e.getMessage());
                    break;
                }
            }
            
            // Verify that we got the expected resource exhaustion exception
            assertTrue(exceptionThrown, "Expected IOException due to file descriptor exhaustion");
            assertNotNull(lastException, "Expected an IOException to be thrown");
            
            // Common error messages for file descriptor exhaustion
            String errorMessage = lastException.getMessage().toLowerCase();
            boolean isFileDescriptorExhaustion = 
                errorMessage.contains("too many open files") ||
                errorMessage.contains("resource temporarily unavailable") ||
                errorMessage.contains("cannot assign requested address") ||
                errorMessage.contains("address already in use") ||
                errorMessage.contains("no buffer space available");
                
            assertTrue(isFileDescriptorExhaustion, 
                "Exception should be related to file descriptor exhaustion. Got: " + lastException.getMessage());
            
            System.out.println("Successfully triggered file descriptor exhaustion with " + serverSockets.size() + " server sockets");
            
        } finally {
            // Clean up resources
            System.out.println("Cleaning up " + serverSockets.size() + " server sockets");
            
            for (ServerSocket serverSocket : serverSockets) {
                try {
                    if (!serverSocket.isClosed()) {
                        serverSocket.close();
                    }
                } catch (IOException e) {
                    // Ignore cleanup errors
                }
            }
        }
    }
}