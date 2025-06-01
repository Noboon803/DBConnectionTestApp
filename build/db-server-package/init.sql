-- Initialize test database with sample data
CREATE TABLE IF NOT EXISTS connection_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    connection_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_info VARCHAR(255),
    status VARCHAR(50)
);

-- Insert sample data
INSERT INTO connection_logs (client_info, status) VALUES 
('Initial setup', 'success'),
('Test connection from webserver', 'success'),
('Health check', 'success');

-- Create a test table for connection verification
CREATE TABLE IF NOT EXISTS server_info (
    id INT AUTO_INCREMENT PRIMARY KEY,
    server_name VARCHAR(100),
    server_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO server_info (server_name, server_type) VALUES 
('test-mysql-db', 'mysql'),
('db-server-ec2', 'mysql');

-- Grant necessary permissions
GRANT ALL PRIVILEGES ON testdb.* TO 'testuser'@'%';
FLUSH PRIVILEGES;
