# Webサーバーのデプロイガイド
## デプロイ手順

### STEP1　: パッケージのビルド
実行後、`build/webserver-package/` ディレクトリに、S3へアップロードするパッケージファイルが作成されます。

```bash
# プロジェクトルートディレクトリで実行
cd {プロジェクトルートディレクトリパス}/DBConnectionTestApp

# Webサーバーパッケージをビルド（フロントエンド含む）
./deployment/build-and-package.sh
```
</br>

### STEP2 : S3へのパッケージファイルアップロード
STEP1で作成した、`build/weserver-package/` ディレクトリ下のすべてのファイルをS3にアップロードして下さい。
</br>

### STEP3 : EC2インスタンスの起動
EC2インスタンス(Webサーバー)を起動する
</br>

### STEP4 : アプリケーションの起動
```bash
# アプリケーションを起動
./start-production.sh
```
</br>

### STEP 5 : デプロイメントの確認
```bash
# PM2でのプロセス確認
pm2 status

# アプリケーションログ確認
pm2 logs webserver

# DB接続テスト
node test-db-connection.js

# ローカルでのテスト
curl http://localhost:3000
```
</br>

#### STEP 6 : Webアクセス確認
ブラウザで以下URLにアクセスする。
- `http://{WebサーバーのパブリックIP}:3000`
- `http://{WebサーバーのパブリックIP}:3000/test-db`
