# Production MySQL Database Server

このパッケージは、EC2インスタンスでMySQLデータベースサーバーを実行するための設定ファイルです。

## セットアップ手順

### 1. 環境変数の設定

```bash
# .env.templateをコピーして設定
cp .env.template .env

# .envファイルを編集してパスワードを設定
nano .env
```

### 2. データベースサーバーの起動

```bash
# 管理スクリプトで起動
./manage-db.sh start

# または直接docker-composeで起動
docker-compose up -d
```

### 3. 動作確認

```bash
# ステータス確認
./manage-db.sh status

# ログ確認
./manage-db.sh logs
```

## 管理コマンド

```bash
./manage-db.sh start    # データベース開始
./manage-db.sh stop     # データベース停止
./manage-db.sh restart  # データベース再起動
./manage-db.sh logs     # ログ表示
./manage-db.sh status   # ステータス確認
./manage-db.sh backup   # バックアップ作成
./manage-db.sh shell    # MySQLシェル
```

## セキュリティ注意事項

1. `.env`ファイルのパスワードは必ず変更してください
2. ファイアウォール設定でポート3306へのアクセスを制限してください
3. 定期的なバックアップを実行してください

## トラブルシューティング

### データベースが起動しない場合
```bash
# ログを確認
./manage-db.sh logs

# コンテナの状態確認
docker ps -a

# ディスク容量確認
df -h
```

### 接続エラーの場合
```bash
# ネットワーク確認
docker network ls

# ポート確認
netstat -tuln | grep 3306
```
