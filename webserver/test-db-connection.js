// データベース接続テスト用スクリプト
const mysql = require('mysql2/promise');
require('dotenv').config();

const dbConfig = {
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'testuser',
  password: process.env.DB_PASSWORD || 'testpassword',
  database: process.env.DB_NAME || 'testdb',
  connectTimeout: 10000
};

async function testConnection() {
  console.log('🔍 データベース接続テストを開始...');
  console.log('接続設定:', {
    host: dbConfig.host,
    port: dbConfig.port,
    user: dbConfig.user,
    database: dbConfig.database
  });

  let connection = null;
  
  try {
    const startTime = Date.now();
    connection = await mysql.createConnection(dbConfig);
    
    const [rows] = await connection.execute('SELECT NOW() as server_time, CONNECTION_ID() as connection_id, VERSION() as mysql_version');
    const responseTime = Date.now() - startTime;
    
    console.log('✅ データベース接続成功!');
    console.log('サーバー時刻:', rows[0].server_time);
    console.log('接続ID:', rows[0].connection_id);
    console.log('MySQLバージョン:', rows[0].mysql_version);
    console.log('応答時間:', responseTime + 'ms');
    
    await connection.end();
    process.exit(0);
    
  } catch (error) {
    console.error('❌ データベース接続失敗:');
    console.error('エラーコード:', error.code);
    console.error('エラーメッセージ:', error.message);
    console.error('エラー番号:', error.errno);
    
    if (connection) {
      try {
        await connection.end();
      } catch (closeError) {
        console.error('接続クローズエラー:', closeError.message);
      }
    }
    
    process.exit(1);
  }
}

testConnection();
