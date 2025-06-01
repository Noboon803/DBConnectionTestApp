# DBConnectionTestApp - EC2デプロイメントガイド

## 概要

このガイドでは、`db-server`の環境をEC2のDBサーバーにデプロイする手順を説明します。

## 前提条件

- AWS CLIがインストール・設定済み
- S3バケットが作成済み
- EC2のセキュリティグループが設定済み
- 適切なIAM権限

## デプロイ手順

### Step 1: デプロイメント用パッケージの作成

```bash
# プロジェクトルートで実行
cd DBConnectionTestApp

# S3バケット名を環境変数で設定
export S3_BUCKET="your-actual-deployment-bucket-name"

# 統合デプロイスクリプトを実行
./deployment/deploy-complete.sh
```

この処理により以下が実行されます：
- ✅ DBサーバー設定のパッケージング (`build/db-server-package/`)
- ✅ Webサーバーのビルドとパッケージング (`build/webserver-latest.tar.gz`)
- ✅ S3への自動アップロード
- ✅ デプロイ用スクリプトの準備 (`build/deployment-ready/`)

### Step 2: DBサーバーEC2の起動

1. **EC2コンソールでインスタンスを起動**
   - AMI: Amazon Linux 2
   - Instance Type: t3.micro以上
   - Security Group: MySQL/Aurora (Port 3306)

2. **セキュリティグループ設定**
   ```
   Type: MySQL/Aurora
   Protocol: TCP
   Port: 3306
   Source: WebサーバーのSecurity Group ID
   ```

3. **ユーザーデータの設定**
   
   `build/deployment-ready/ec2-dbserver-userdata.sh` の内容をEC2起動時のユーザーデータに貼り付け

4. **インスタンスの起動と確認**
   ```bash
   # SSH接続後の確認
   sudo tail -f /var/log/user-data.log
   sudo /opt/mysql/manage-db.sh status
   ```

### Step 3: WebサーバーEC2の起動

1. **ec2-webserver-userdata.sh を編集**
   ```bash
   # DBサーバーのプライベートIPを設定
   DB_HOST="DBサーバーのプライベートIP"
   DB_PASSWORD="対応するパスワード"
   ```

2. **EC2インスタンスを起動**
   - AMI: Amazon Linux 2
   - Instance Type: t3.micro以上
   - Security Group: HTTP (80), HTTPS (443), Custom TCP (3000)

3. **動作確認**
   ```bash
   # ブラウザで確認
   http://WebサーバーパブリックIP:3000
   
   # API確認
   curl http://WebサーバーパブリックIP:3000/api/health
   curl http://WebサーバーパブリックIP:3000/api/db-test
   ```

## 利用可能な管理コマンド

### DBサーバー管理
```bash
# SSH接続後
sudo /opt/mysql/manage-db.sh start      # データベース開始
sudo /opt/mysql/manage-db.sh stop       # データベース停止
sudo /opt/mysql/manage-db.sh restart    # データベース再起動
sudo /opt/mysql/manage-db.sh status     # ステータス確認
sudo /opt/mysql/manage-db.sh logs       # ログ表示
sudo /opt/mysql/manage-db.sh backup     # バックアップ作成
sudo /opt/mysql/manage-db.sh shell      # MySQLシェル
```

### Webサーバー管理
```bash
# SSH接続後
sudo pm2 list                          # プロセス一覧
sudo pm2 restart webserver             # アプリケーション再起動
sudo pm2 logs webserver                # ログ表示
sudo /opt/webserver/update.sh          # アプリケーション更新
```

## トラブルシューティング

### DBサーバーが起動しない
```bash
# デプロイログの確認
sudo tail -f /var/log/user-data.log

# MySQLログの確認
sudo /opt/mysql/manage-db.sh logs

# Dockerコンテナの状態確認
docker ps -a
```

### データベース接続エラー
1. セキュリティグループの設定確認
2. DBサーバーのプライベートIP確認
3. パスワード設定の確認
4. ネットワーク接続の確認

### Webサーバーが起動しない
```bash
# デプロイログの確認
sudo tail -f /var/log/cloud-init-output.log

# PM2ログの確認
sudo pm2 logs webserver

# 環境変数の確認
sudo cat /opt/webserver/.env
```

## セキュリティのベストプラクティス

1. **強固なパスワード設定**
   - MYSQL_ROOT_PASSWORD を複雑なものに変更
   - MYSQL_PASSWORD を複雑なものに変更

2. **ネットワークセキュリティ**
   - DBサーバーはWebサーバーからのみアクセス可能に設定
   - 不要なポートは閉じる

3. **定期メンテナンス**
   - 定期的なバックアップの実行
   - OSとソフトウェアの更新
   - ログの監視

## スケーリングと運用

### 水平スケーリング
- 複数のWebサーバーインスタンスでLoad Balancer使用
- DBサーバーのRead Replicaによる読み取り負荷分散

### 監視
- CloudWatch メトリクスの設定
- アプリケーションレベルのモニタリング

### バックアップ戦略
- 自動バックアップの設定
- S3への定期バックアップ

## コスト最適化

1. **適切なインスタンスサイズ**
   - t3.microで十分な場合が多い
   - 必要に応じてスケールアップ

2. **Reserved Instances**
   - 長期運用時のコスト削減

3. **モニタリング**
   - 使用量の定期的な確認
   - 不要なリソースの削除
