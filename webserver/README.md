# EC2 Database Connection Tester - Web Server

## 概要

このWebサーバーは、EC2間の通信を確認するためのシンプルなWebアプリケーションです。WebサーバーEC2からDBサーバーEC2への接続をテストし、結果をWebインターフェースで表示します。

## 機能

- **シンプルなWebインターフェース**: トップページでDB接続状況を確認
- **リアルタイム接続テスト**: ボタンクリックでDB接続をテスト
- **自動更新**: 30秒間隔で自動的に接続状況を更新
- **詳細な接続情報**: MySQL バージョン、応答時間、エラー詳細などを表示
- **レスポンシブデザイン**: モバイルデバイスにも対応

## 技術スタック

- **Backend**: Node.js + Express
- **Frontend**: React + TypeScript + Vite
- **Database**: MySQL
- **Process Manager**: PM2

## ローカル開発環境のセットアップ

### 1. 依存関係のインストール

```bash
# webserverディレクトリに移動
cd webserver

# バックエンドとフロントエンドの依存関係を一括インストール
npm run install:all
```

### 2. テストデータベースの起動

```bash
# プロジェクトルートに移動
cd ..

# テスト用MySQLサーバーを起動
cd test-db-server
docker-compose up -d

# データベースの起動確認
docker-compose logs -f test-db
```

### 3. 環境変数の設定

`.env`ファイルがローカル開発用の設定で作成済みです。

### 4. アプリケーションの起動

```bash
# webserverディレクトリに戻る
cd ../webserver

# フロントエンドをビルド
npm run build

# サーバーを起動
npm start

# または開発モード（ホットリロード）
npm run dev
```

### 5. アクセス確認

ブラウザで `http://localhost:80` にアクセスして動作を確認してください。

## データベース接続テスト

コマンドラインからデータベース接続をテストできます：

```bash
npm run test:db
```

## 本番環境へのデプロイ

### 1. アプリケーションのビルドとパッケージング

```bash
# プロジェクトルートで実行
./deployment/build-and-package.sh
```

これにより `build/webserver-latest.tar.gz` が作成されます。

### 2. S3へのアップロード

```bash
# S3バケットにアーティファクトをアップロード
aws s3 cp build/webserver-latest.tar.gz s3://your-deployment-bucket/webserver/
```

### 3. EC2インスタンスの起動

`deployment/ec2-webserver-userdata.sh` をユーザーデータとして使用してEC2インスタンスを起動します。

**注意**: 事前にスクリプト内の以下の値を実際の環境に合わせて変更してください：
- `S3_BUCKET`: デプロイメント用S3バケット名
- `S3_OBJECT_KEY`: S3オブジェクトキー
- `DB_HOST`: DBサーバーのプライベートIP
- `DB_PASSWORD`: データベースパスワード

## ファイル構成

```
webserver/
├── package.json              # パッケージ設定
├── server.js                 # Express サーバー
├── test-db-connection.js     # DB接続テストスクリプト
├── ecosystem.config.json     # PM2設定
├── .env                      # ローカル環境変数
├── .env.production          # 本番環境変数テンプレート
├── frontend/                # React フロントエンド
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/
│   │   ├── App.tsx
│   │   ├── App.css
│   │   └── ...
│   └── dist/                # ビルド成果物（自動生成）
└── logs/                    # ログファイル（自動生成）
```

## API エンドポイント

- `GET /api/health` - サーバーヘルスチェック
- `GET /api/db-test` - データベース接続テスト
- `GET /*` - React アプリケーション（SPA）

## 環境変数

| 変数名 | 説明 | デフォルト値 |
|--------|------|--------------|
| `DB_HOST` | データベースホスト | `localhost` |
| `DB_PORT` | データベースポート | `3306` |
| `DB_USER` | データベースユーザー | `testuser` |
| `DB_PASSWORD` | データベースパスワード | `testpassword` |
| `DB_NAME` | データベース名 | `testdb` |
| `PORT` | サーバーポート | `80` |
| `NODE_ENV` | 実行環境 | `development` |

## トラブルシューティング

### データベース接続エラー

1. データベースサーバーが起動しているか確認
2. 接続情報（ホスト、ポート、認証情報）が正しいか確認
3. ネットワーク接続（セキュリティグループ等）を確認

### ポート80でのアクセスエラー

- macOS/Linuxでは管理者権限が必要な場合があります：
  ```bash
  sudo npm start
  ```

### PM2関連のエラー

```bash
# PM2プロセスの確認
pm2 list

# ログの確認
pm2 logs webserver

# アプリケーションの再起動
pm2 restart webserver
```
