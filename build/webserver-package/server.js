const express = require('express');
const mysql = require('mysql2/promise');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, 'dist')));

// Database configuration
const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'testuser',
  password: process.env.DB_PASSWORD || 'testpassword',
  database: process.env.DB_NAME || 'testdb',
  connectTimeout: 10000
};

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    server: 'webserver'
  });
});

// Database connection test endpoint
app.get('/api/db-test', async (req, res) => {
  let connection = null;
  const startTime = Date.now();
  
  try {
    console.log('Attempting to connect to database:', {
      host: dbConfig.host,
      port: dbConfig.port,
      user: dbConfig.user,
      database: dbConfig.database
    });

    connection = await mysql.createConnection(dbConfig);
    
    // Test query
    const [rows] = await connection.execute('SELECT NOW() as server_time, CONNECTION_ID() as connection_id, VERSION() as mysql_version');
    const responseTime = Date.now() - startTime;
    
    await connection.end();
    
    res.json({
      success: true,
      message: 'Database connection successful',
      data: {
        server_time: rows[0].server_time,
        connection_id: rows[0].connection_id,
        mysql_version: rows[0].mysql_version,
        response_time_ms: responseTime,
        db_config: {
          host: dbConfig.host,
          port: dbConfig.port,
          database: dbConfig.database
        }
      },
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    const responseTime = Date.now() - startTime;
    
    if (connection) {
      try {
        await connection.end();
      } catch (closeError) {
        console.error('Error closing connection:', closeError.message);
      }
    }
    
    console.error('Database connection failed:', error.message);
    
    res.status(500).json({
      success: false,
      message: 'Database connection failed',
      error: {
        code: error.code,
        message: error.message,
        errno: error.errno,
        sqlState: error.sqlState
      },
      response_time_ms: responseTime,
      db_config: {
        host: dbConfig.host,
        port: dbConfig.port,
        database: dbConfig.database
      },
      timestamp: new Date().toISOString()
    });
  }
});

// Serve React app for all other routes
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Server error:', error);
  res.status(500).json({
    success: false,
    message: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Database host: ${dbConfig.host}:${dbConfig.port}`);
});
