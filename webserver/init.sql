-- Initialize test database with sample data
USE testdb;

-- Create a simple test table
CREATE TABLE IF NOT EXISTS connection_tests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    test_name VARCHAR(255) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) DEFAULT 'success',
    details TEXT
);

-- Insert sample data
INSERT INTO connection_tests (test_name, details) VALUES 
('Initial Test', 'Database initialized successfully'),
('Connection Test', 'Server can connect to database'),
('API Test', 'API endpoints are functional');

-- Create a table for storing application logs
CREATE TABLE IF NOT EXISTS app_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    level VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(100),
    metadata JSON
);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON testdb.* TO 'testuser'@'%';
