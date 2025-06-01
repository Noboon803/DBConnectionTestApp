# DBConnectionTestApp

EC2インスタンス間のデータベース接続をテストするためのWebアプリケーション

## 概要

このアプリケーションは、AWS EC2環境でWebサーバーからMySQLデータベースサーバーへの接続性をテストし、結果をWebインターフェースで確認できるツールです。

## アーキテクチャ

```
┌─────────────────┐     ┌─────────────────┐
│   WebServer     │────▶│   DB Server     │
│   (EC2)         │     │   (EC2)         │
│                 │     │                 │
│ - Node.js/React │     │ - MySQL 8.0     │
│ - Express API   │     │ - Port 3306     │
│ - Port 3000     │     │                 │
└─────────────────┘     └─────────────────┘
```

## プロジェクト構成

- **`webserver/`** - Webサーバーアプリケーション（Node.js + React）
- **`db-server/`** - ローカル開発用MySQLサーバー
- **`deployment/`** - 本番環境へのデプロイスクリプト

## ローカル環境での動作確認方法

### 前提条件

- Node.js 18以上
- Docker & Docker Compose
- npm または yarn

### 1. リポジトリのクローン

```bash
git clone <repository-url>
cd DBConnectionTestApp
```

### 2. テスト用データベースの起動

```bash
# db-serverディレクトリに移動
cd db-server

# Docker Composeでテスト用MySQLサーバーを起動
docker-compose up -d

# データベースの起動確認
docker-compose logs -f test-db
```

**起動確認のポイント:**
- `mysqld: ready for connections` のメッセージが表示されるまで待つ
- ポート3306でMySQLが起動していることを確認

### 3. Webサーバーのセットアップ

```bashcd 
# webserverディレクトリに移動
cd ../webserver

# バックエンドとフロントエンドの依存関係を一括インストール
npm run install:all

# フロントエンドをビルド
npm run build
```

### 4. データベース接続テスト

```bash
# コマンドラインからデータベース接続をテスト
npm run test:db
```

**期待される出力:**
```
✅ データベース接続成功!
サーバー時刻: 2025-06-02T12:00:00.000Z
接続ID: 15
MySQLバージョン: 8.0.42
応答時間: 22ms
```

### 5. Webサーバーの起動

```bash
# 開発モード（ホットリロード有効）
npm run dev

# または本番モード
npm start
```

### 6. 動作確認

1. **ブラウザアクセス**
   - http://localhost:3000 にアクセス

2. **APIエンドポイントのテスト**
   ```bash
   # ヘルスチェック
   curl http://localhost:3000/api/health
   
   # データベース接続テスト
   curl http://localhost:3000/api/db-test
   ```

3. **Webインターフェースでの確認**
   - データベース接続ボタンをクリック
   - リアルタイムで接続状況が更新されることを確認

### トラブルシューティング（ローカル環境）

#### データベース接続エラー
```bash
# データベースコンテナの状態確認
cd db-server
docker-compose ps

# ログの確認
docker-compose logs test-db

# コンテナの再起動
docker-compose restart test-db
```

#### ポート競合エラー
```bash
# ポート使用状況の確認
lsof -i :3000
lsof -i :3306

# 別のポートを使用する場合
# webserver/.env ファイルでPORTを変更
```

## 本番環境へのデプロイ方法

### 前提条件

- AWS CLIの設定完了
- 適切なIAMロールと権限
- S3バケットの作成
- EC2のセキュリティグループ設定

### 1. デプロイメント用アーティファクトの作成

```bash
# プロジェクトルートで実行（WebサーバーとDBサーバーの両方）
./deployment/deploy-complete.sh

# または個別に実行
./deployment/build-and-package.sh      # Webサーバー
./deployment/build-and-package-db.sh   # DBサーバー
```

**統合デプロイスクリプト (`deploy-complete.sh`) の実行内容:**
- DBサーバー設定のパッケージング
- Webサーバーのビルドとパッケージング  
- S3への自動アップロード
- デプロイ用スクリプトの準備
- `build/webserver-latest.tar.gz` の生成
- `build/db-server-package/` の作成

### 2. S3へのアップロード

```bash
# 統合スクリプトを使用する場合は自動でアップロードされます
./deployment/deploy-complete.sh

# または手動でアップロード
aws s3 cp build/webserver-latest.tar.gz s3://your-deployment-bucket/webserver/
aws s3 sync build/db-server-package/ s3://your-deployment-bucket/db-server/

# アップロード確認
aws s3 ls s3://your-deployment-bucket/webserver/
aws s3 ls s3://your-deployment-bucket/db-server/
```

### 3. EC2インスタンスの設定

#### 3.1 DBサーバーEC2の起動（改善版）

1. **DBサーバー設定の準備**
   ```bash
   # 統合デプロイスクリプトを実行（推奨）
   ./deployment/deploy-complete.sh
   
   # または個別にDBサーバー設定をパッケージング
   ./deployment/build-and-package-db.sh
   
   # S3にアップロード（手動の場合）
   aws s3 sync build/db-server-package/ s3://your-deployment-bucket/db-server/
   ```

2. **EC2インスタンス設定**
   - AMI選択: Amazon Linux 2
   - インスタンスタイプ: t3.micro以上
   - セキュリティグループ: MySQL/Aurora (Port 3306)

3. **セキュリティグループ設定**
   ```
   Type: MySQL/Aurora
   Protocol: TCP
   Port: 3306
   Source: WebサーバーのセキュリティグループID
   ```

4. **ユーザーデータの設定**
   
   `build/deployment-ready/ec2-dbserver-userdata.sh` または `deployment/ec2-dbserver-userdata.sh` を編集してS3バケット名を設定:
   ```bash
   S3_BUCKET="your-deployment-bucket"
   ```

5. **EC2インスタンス起動時にユーザーデータとして指定**

#### メリット
- ✅ db-serverと同じ設定を本番環境で利用
- ✅ init.sqlによる初期データの自動投入
- ✅ Docker Composeによる簡単な管理
- ✅ 設定の一元管理とバージョン管理
- ✅ ローカル環境と本番環境の設定差異を最小化
- ✅ 管理スクリプトによる運用の簡素化

#### DBサーバー管理コマンド
```bash
# SSH接続後、以下のコマンドでDBサーバーを管理
sudo /opt/mysql/manage-db.sh start     # 開始
sudo /opt/mysql/manage-db.sh stop      # 停止
sudo /opt/mysql/manage-db.sh restart   # 再起動
sudo /opt/mysql/manage-db.sh status    # ステータス確認
sudo /opt/mysql/manage-db.sh logs      # ログ表示
sudo /opt/mysql/manage-db.sh backup    # バックアップ作成
sudo /opt/mysql/manage-db.sh shell     # MySQLシェル
```

#### 3.2 WebサーバーEC2の起動

1. **AMI選択**: Amazon Linux 2
2. **インスタンスタイプ**: t3.micro以上
3. **セキュリティグループ**:
   ```
   Type: HTTP
   Protocol: TCP
   Port: 80
   Source: 0.0.0.0/0
   
   Type: HTTPS
   Protocol: TCP
   Port: 443
   Source: 0.0.0.0/0
   
   Type: Custom TCP
   Protocol: TCP
   Port: 3000
   Source: 0.0.0.0/0
   ```

4. **ユーザーデータの設定**:
   
   `deployment/ec2-webserver-userdata.sh` を編集して以下を設定:
   ```bash
   # S3設定
   S3_BUCKET="your-deployment-bucket"
   S3_OBJECT_KEY="webserver/webserver-latest.tar.gz"
   
   # データベース設定
   DB_HOST="DBサーバーのプライベートIP"
   DB_PASSWORD="yourTestPassword"
   ```

5. **EC2インスタンス起動時にユーザーデータとして指定**

### 4. デプロイメントの確認

#### 4.1 WebサーバーEC2での確認
```bash
# SSH接続後
sudo tail -f /var/log/cloud-init-output.log

# アプリケーションの状態確認
sudo pm2 list

# ログの確認
sudo pm2 logs webserver
```

#### 4.2 ブラウザでの確認
```
http://WebサーバーのパブリックIP:3000
```

#### 4.3 APIエンドポイントの確認
```bash
# ヘルスチェック
curl http://WebサーバーのパブリックIP:3000/api/health

# データベース接続テスト
curl http://WebサーバーのパブリックIP:3000/api/db-test
```

### 5. 本番環境の管理

#### アプリケーションの更新
```bash
# 新しいバージョンをS3にアップロード
aws s3 cp build/webserver-latest.tar.gz s3://your-deployment-bucket/webserver/

# EC2でアプリケーションを再デプロイ
sudo /opt/webserver/update.sh
```

#### 監視とログ
```bash
# PM2でのプロセス監視
sudo pm2 list
sudo pm2 monit

# アプリケーションログ
sudo pm2 logs webserver

# システムログ
sudo journalctl -u pm2-root

# リソース使用量
htop
df -h
```

### トラブルシューティング（本番環境）

#### EC2起動エラー
```bash
# ユーザーデータの実行ログ確認
sudo cat /var/log/cloud-init-output.log

# エラーがある場合は修正してインスタンスを再起動
```

#### データベース接続エラー
```bash
# セキュリティグループの確認
# DB_HOSTの設定確認
# MySQLサーバーの起動状態確認
sudo /opt/mysql/manage-db.sh status
sudo /opt/mysql/manage-db.sh logs

# Dockerコンテナの確認
docker ps
docker logs <mysql-container-id>
```

#### パフォーマンス問題
```bash
# CPU使用率確認
top

# メモリ使用量確認
free -h

# ディスク容量確認
df -h

# ネットワーク確認
netstat -tuln
```

## セキュリティ考慮事項

1. **セキュリティグループ**
   - 必要最小限のポートのみ開放
   - データベースアクセスはWebサーバーからのみ許可

2. **認証情報**
   - 強固なパスワードを使用
   - AWS Secrets Managerの利用を推奨

3. **ネットワーク**
   - プライベートサブネットでのDB配置を推奨
   - VPCエンドポイントの活用

4. **更新**
   - 定期的なシステム更新
   - 脆弱性対応の実施

## コスト最適化

1. **インスタンスタイプ**
   - t3.microで十分な性能
   - リザーブドインスタンスの検討

2. **ストレージ**
   - EBSボリュームサイズの最適化
   - 不要なスナップショットの削除

3. **ネットワーク**
   - 同一AZ内での配置でデータ転送料削減

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。