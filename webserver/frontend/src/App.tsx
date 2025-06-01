import { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

interface DbTestResult {
  success: boolean;
  message: string;
  data?: {
    server_time: string;
    connection_id: number;
    mysql_version: string;
    response_time_ms: number;
    db_config: {
      host: string;
      port: number;
      database: string;
    };
  };
  error?: {
    code: string;
    message: string;
    errno: number;
    sqlState: string;
  };
  response_time_ms?: number;
  db_config?: {
    host: string;
    port: number;
    database: string;
  };
  timestamp: string;
}

interface HealthResult {
  status: string;
  timestamp: string;
  server: string;
}

function App() {
  const [dbResult, setDbResult] = useState<DbTestResult | null>(null);
  const [healthResult, setHealthResult] = useState<HealthResult | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [lastChecked, setLastChecked] = useState<Date | null>(null);

  const testDbConnection = async () => {
    setIsLoading(true);
    try {
      const response = await axios.get<DbTestResult>('/api/db-test');
      setDbResult(response.data);
      setLastChecked(new Date());
    } catch (error) {
      if (axios.isAxiosError(error) && error.response) {
        setDbResult(error.response.data);
      } else {
        setDbResult({
          success: false,
          message: 'Network error or server unavailable',
          error: {
            code: 'NETWORK_ERROR',
            message: error instanceof Error ? error.message : 'Unknown error',
            errno: 0,
            sqlState: ''
          },
          timestamp: new Date().toISOString()
        });
      }
      setLastChecked(new Date());
    } finally {
      setIsLoading(false);
    }
  };

  const checkHealth = async () => {
    try {
      const response = await axios.get<HealthResult>('/api/health');
      setHealthResult(response.data);
    } catch (error) {
      setHealthResult({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        server: 'unknown'
      });
    }
  };

  useEffect(() => {
    checkHealth();
    testDbConnection();
    
    // Auto-refresh every 30 seconds
    const interval = setInterval(() => {
      checkHealth();
      testDbConnection();
    }, 30000);
    
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="app">
      <div className="container">
        <header className="header">
          <h1>🔗 EC2 Database Connection Tester</h1>
          <p className="subtitle">
            このアプリケーションは、WebサーバーEC2からDBサーバーEC2への接続をテストします
          </p>
        </header>

        <div className="status-grid">
          {/* Web Server Status */}
          <div className="status-card">
            <div className="status-header">
              <h3>🖥️ Webサーバー状態</h3>
              <div className={`status-indicator ${healthResult?.status === 'healthy' ? 'healthy' : 'unhealthy'}`}>
                {healthResult?.status === 'healthy' ? '✅ 正常' : '❌ 異常'}
              </div>
            </div>
            <div className="status-details">
              <p><strong>サーバー:</strong> {healthResult?.server || 'unknown'}</p>
              <p><strong>最終確認:</strong> {healthResult?.timestamp ? new Date(healthResult.timestamp).toLocaleString('ja-JP') : 'N/A'}</p>
            </div>
          </div>

          {/* Database Connection Status */}
          <div className="status-card">
            <div className="status-header">
              <h3>🗄️ データベース接続状態</h3>
              <div className={`status-indicator ${dbResult?.success ? 'healthy' : 'unhealthy'}`}>
                {dbResult?.success ? '✅ 接続成功' : '❌ 接続失敗'}
              </div>
            </div>
            <div className="status-details">
              {dbResult && (
                <>
                  <p><strong>メッセージ:</strong> {dbResult.message}</p>
                  <p><strong>DB ホスト:</strong> {dbResult.data?.db_config.host || dbResult.db_config?.host || 'N/A'}</p>
                  <p><strong>DB ポート:</strong> {dbResult.data?.db_config.port || dbResult.db_config?.port || 'N/A'}</p>
                  <p><strong>データベース:</strong> {dbResult.data?.db_config.database || dbResult.db_config?.database || 'N/A'}</p>
                  <p><strong>応答時間:</strong> {dbResult.data?.response_time_ms || dbResult.response_time_ms || 'N/A'}ms</p>
                  
                  {dbResult.success && dbResult.data && (
                    <>
                      <p><strong>MySQL バージョン:</strong> {dbResult.data.mysql_version}</p>
                      <p><strong>接続ID:</strong> {dbResult.data.connection_id}</p>
                      <p><strong>サーバー時刻:</strong> {new Date(dbResult.data.server_time).toLocaleString('ja-JP')}</p>
                    </>
                  )}
                  
                  {!dbResult.success && dbResult.error && (
                    <>
                      <p><strong>エラーコード:</strong> {dbResult.error.code}</p>
                      <p><strong>エラー詳細:</strong> {dbResult.error.message}</p>
                    </>
                  )}
                </>
              )}
            </div>
          </div>
        </div>

        <div className="actions">
          <button 
            onClick={testDbConnection} 
            disabled={isLoading}
            className="test-button"
          >
            {isLoading ? '🔄 テスト中...' : '🔍 接続テスト実行'}
          </button>
          
          {lastChecked && (
            <p className="last-checked">
              最終テスト実行: {lastChecked.toLocaleString('ja-JP')}
            </p>
          )}
        </div>

        <div className="info-section">
          <h3>📋 システム情報</h3>
          <div className="info-grid">
            <div className="info-item">
              <strong>アプリケーション:</strong> EC2間通信テスター
            </div>
            <div className="info-item">
              <strong>目的:</strong> WebサーバーEC2 ↔ DBサーバーEC2の接続確認
            </div>
            <div className="info-item">
              <strong>データベース:</strong> MySQL
            </div>
            <div className="info-item">
              <strong>自動更新:</strong> 30秒間隔
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default App;
